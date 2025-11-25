# frozen_string_literal: true

require 'shellwords'
require 'fileutils'

# Helper module for normalizing and validating watchOS screenshots
module WatchScreenshotHelper
  # Apple App Store Connect official watchOS screenshot sizes
  OFFICIAL_WATCH_SIZES = {
    ultra: { width: 410, height: 502, name: "Apple Watch Ultra (49mm)" },
    series7plus: { width: 396, height: 484, name: "Apple Watch Series 7+ (45mm)" },
    series4to6: { width: 368, height: 448, name: "Apple Watch Series 4-6 (40mm)" }
  }.freeze

  # Default target size for normalization (45mm is most common)
  DEFAULT_TARGET = :series7plus

  class ValidationError < StandardError; end

  # Normalize watch screenshots to App Store Connect required dimensions
  # @param input_dir [String] Directory containing raw watch screenshots
  # @param output_dir [String] Directory for normalized screenshots
  # @param target_size [Symbol] Target size from OFFICIAL_WATCH_SIZES
  def self.normalize_screenshots(input_dir, output_dir, target_size: DEFAULT_TARGET)
    unless OFFICIAL_WATCH_SIZES.key?(target_size)
      raise ArgumentError, "Invalid target_size: #{target_size}. Must be one of #{OFFICIAL_WATCH_SIZES.keys.join(', ')}"
    end

    target = OFFICIAL_WATCH_SIZES[target_size]
    FileUtils.mkdir_p(output_dir)

    locales = %w[en-US fi]
    normalized_count = 0

    locales.each do |locale|
      src_dir = File.join(input_dir, locale)
      dst_dir = File.join(output_dir, locale)

      unless Dir.exist?(src_dir)
        puts "⚠️  Skipping #{locale}: Directory not found at #{src_dir}"
        next
      end

      FileUtils.mkdir_p(dst_dir)

      Dir.glob(File.join(src_dir, "*.png")).sort.each do |src_file|
        basename = File.basename(src_file)
        dst_file = File.join(dst_dir, basename)

        # Get current dimensions with proper error handling
        current_dims = `identify -format '%wx%h' #{Shellwords.escape(src_file)} 2>&1`.strip

        # Validate identify output
        unless current_dims =~ /^\d+x\d+$/
          raise ValidationError, "Failed to read dimensions from #{src_file}: identify returned '#{current_dims}'"
        end

        current_width, current_height = current_dims.split('x').map(&:to_i)

        # Sanity check dimensions
        if current_width <= 0 || current_height <= 0
          raise ValidationError, "Invalid dimensions for #{src_file}: #{current_width}x#{current_height}"
        end

        # Check if already normalized
        if current_width == target[:width] && current_height == target[:height]
          puts "✅ #{locale}/#{basename}: Already #{target[:width]}x#{target[:height]}, copying..."
          FileUtils.cp(src_file, dst_file)
          normalized_count += 1
          next
        end

        # Normalize using ImageMagick
        # Use -resize with ! to force exact dimensions (ignore aspect ratio)
        # watchOS screenshots should maintain aspect ratio, so we'll resize to fit and pad if needed
        cmd = [
          'convert',
          Shellwords.escape(src_file),
          '-resize', "#{target[:width]}x#{target[:height]}^",
          '-gravity', 'center',
          '-extent', "#{target[:width]}x#{target[:height]}",
          '-quality', '100',
          Shellwords.escape(dst_file)
        ].join(' ')

        puts "🔄 #{locale}/#{basename}: #{current_dims} → #{target[:width]}x#{target[:height]}"
        system(cmd)

        unless $?.success?
          raise ValidationError, "Failed to normalize #{src_file}"
        end

        normalized_count += 1
      end
    end

    puts "\n✅ Normalized #{normalized_count} watch screenshots to #{target[:name]} (#{target[:width]}x#{target[:height]})"
    normalized_count
  end

  # Validate watch screenshots match App Store Connect requirements
  # @param screenshots_dir [String] Directory containing watch screenshots
  # @param expected_count [Integer] Expected number of screenshots per locale
  # @param allowed_sizes [Array<Symbol>] Allowed sizes from OFFICIAL_WATCH_SIZES
  def self.validate_screenshots(screenshots_dir, expected_count: 5, allowed_sizes: OFFICIAL_WATCH_SIZES.keys)
    locales = %w[en-US fi]
    errors = []
    warnings = []
    total_valid = 0

    locales.each do |locale|
      locale_dir = File.join(screenshots_dir, locale)

      unless Dir.exist?(locale_dir)
        errors << "❌ #{locale}: Directory not found at #{locale_dir}"
        next
      end

      screenshots = Dir.glob(File.join(locale_dir, "*.png")).sort

      if screenshots.empty?
        errors << "❌ #{locale}: No screenshots found"
        next
      end

      if screenshots.count < expected_count
        warnings << "⚠️  #{locale}: Expected #{expected_count} screenshots, found #{screenshots.count}"
      end

      screenshots.each do |shot|
        basename = File.basename(shot)

        # Verify file naming pattern (allow Fastlane's device prefix or direct ##_Watch_ pattern)
        unless basename =~ /\d{2}_Watch_/ || basename =~ /Apple Watch.*-\d{2}_Watch_/
          warnings << "⚠️  #{locale}/#{basename}: Non-standard naming (expected '##_Watch_*.png' or 'Device-##_Watch_*.png')"
        end

        # Check dimensions
        begin
          dimensions = `identify -format '%wx%h' #{Shellwords.escape(shot)} 2>&1`.strip

          # Validate identify output
          unless dimensions =~ /^\d+x\d+$/
            errors << "❌ #{locale}/#{basename}: Failed to read dimensions - identify returned '#{dimensions}'"
            next
          end

          width, height = dimensions.split('x').map(&:to_i)

          # Sanity check dimensions
          if width <= 0 || height <= 0
            errors << "❌ #{locale}/#{basename}: Invalid dimensions: #{width}x#{height}"
            next
          end

          # Check if dimensions match any official size
          matching_size = OFFICIAL_WATCH_SIZES.find do |key, size|
            allowed_sizes.include?(key) && size[:width] == width && size[:height] == height
          end

          if matching_size
            puts "✅ #{locale}/#{basename}: #{dimensions} (#{matching_size[1][:name]})"
            total_valid += 1
          else
            # Check if it's close to an official size (within 10% tolerance)
            closest = find_closest_size(width, height, allowed_sizes)
            if closest
              errors << "❌ #{locale}/#{basename}: #{dimensions} - Should be #{closest[:width]}x#{closest[:height]} (#{closest[:name]})"
            else
              errors << "❌ #{locale}/#{basename}: #{dimensions} - Not a valid App Store Connect watch size"
            end
          end

          # Basic sanity checks
          if width < 300 || height < 400
            errors << "❌ #{locale}/#{basename}: #{dimensions} - Dimensions too small for watchOS"
          end

          # Check file size (should be reasonable for PNG)
          file_size_kb = File.size(shot) / 1024
          if file_size_kb > 1024
            warnings << "⚠️  #{locale}/#{basename}: Large file size (#{file_size_kb} KB)"
          end

        rescue => e
          errors << "❌ #{locale}/#{basename}: Failed to validate - #{e.message}"
        end
      end
    end

    # Print summary
    puts "\n" + "=" * 60
    puts "Watch Screenshot Validation Summary"
    puts "=" * 60

    if warnings.any?
      puts "\nWarnings:"
      warnings.each { |w| puts w }
    end

    if errors.any?
      puts "\nErrors:"
      errors.each { |e| puts e }
      puts "\n❌ Validation FAILED: #{errors.count} error(s) found"
      raise ValidationError, "Watch screenshot validation failed"
    else
      puts "\n✅ All #{total_valid} screenshots are valid!"
      puts "\nAccepted sizes:"
      allowed_sizes.each do |key|
        size = OFFICIAL_WATCH_SIZES[key]
        puts "  • #{size[:name]}: #{size[:width]}x#{size[:height]}"
      end
    end

    true
  end

  # Find the closest official watch size to given dimensions
  # @param width [Integer] Current width
  # @param height [Integer] Current height
  # @param allowed_keys [Array<Symbol>] Allowed size keys
  # @return [Hash, nil] Closest size or nil
  def self.find_closest_size(width, height, allowed_keys)
    min_distance = Float::INFINITY
    closest = nil

    allowed_keys.each do |key|
      size = OFFICIAL_WATCH_SIZES[key]
      distance = Math.sqrt((width - size[:width])**2 + (height - size[:height])**2)

      if distance < min_distance && distance < 50  # Within 50 pixels
        min_distance = distance
        closest = size
      end
    end

    closest
  end
end
