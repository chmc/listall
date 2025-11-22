# frozen_string_literal: true

require 'shellwords'
require 'fileutils'

# Helper module for normalizing and validating iOS, iPadOS, and watchOS screenshots
# Ensures all screenshots meet Apple App Store Connect requirements
module ScreenshotHelper
  # Apple App Store Connect official screenshot sizes
  # Reference: https://help.apple.com/app-store-connect/
  # Updated 2024: iPad 13" now requires 2064x2752 (not the old 2048x2732 for 12.9")
  OFFICIAL_SIZES = {
    # iPhone sizes
    iphone_67: { width: 1290, height: 2796, name: "iPhone 6.7\" (14/15/16 Pro Max)", platform: :ios },
    iphone_65: { width: 1242, height: 2688, name: "iPhone 6.5\" (XS Max, 11 Pro Max)", platform: :ios },
    iphone_61: { width: 1179, height: 2556, name: "iPhone 6.1\" (14/15/16 Pro)", platform: :ios },
    iphone_58: { width: 1170, height: 2532, name: "iPhone 5.8\" (X, XS, 11 Pro)", platform: :ios },
    iphone_55: { width: 1242, height: 2208, name: "iPhone 5.5\" (6/7/8 Plus)", platform: :ios },

    # iPad sizes (2024 update: 13" is the new standard, 12.9" is legacy)
    ipad_13: { width: 2064, height: 2752, name: "iPad 13\" (M4 Pro/Air)", platform: :ios },
    ipad_129_3rd: { width: 2048, height: 2732, name: "iPad Pro 12.9\" (3rd gen+)", platform: :ios },
    ipad_129: { width: 2048, height: 2732, name: "iPad Pro 12.9\"", platform: :ios },
    ipad_11: { width: 1668, height: 2388, name: "iPad Pro 11\"", platform: :ios },

    # Apple Watch sizes
    watch_ultra: { width: 410, height: 502, name: "Apple Watch Ultra (49mm)", platform: :watchos },
    watch_series7plus: { width: 396, height: 484, name: "Apple Watch Series 7+ (45mm)", platform: :watchos },
    watch_series4to6: { width: 368, height: 448, name: "Apple Watch Series 4-6 (40mm)", platform: :watchos }
  }.freeze

  # Default target sizes for normalization
  DEFAULT_TARGETS = {
    ios: :iphone_67,      # iPhone 6.7" for main App Store slot
    ipados: :ipad_13,     # iPad 13" for iPad screenshots (2024 standard)
    watchos: :watch_series7plus  # Apple Watch Series 7+ 45mm
  }.freeze

  class ValidationError < StandardError; end

  # Detect device type from filename
  # @param filename [String] Screenshot filename
  # @return [Symbol, nil] Device type (:iphone, :ipad, :watch) or nil
  def self.detect_device_type(filename)
    case filename
    when /iPhone/i
      :iphone
    when /iPad/i
      :ipad
    when /Watch/i
      :watch
    else
      nil
    end
  end

  # Find the appropriate target size for a given device type
  # @param device_type [Symbol] :iphone, :ipad, or :watch
  # @return [Hash] Size specification
  def self.target_size_for_device(device_type)
    case device_type
    when :iphone
      OFFICIAL_SIZES[:iphone_67]
    when :ipad
      OFFICIAL_SIZES[:ipad_13]  # 2024: Use 13" (2064x2752) instead of 12.9" (2048x2732)
    when :watch
      OFFICIAL_SIZES[:watch_series7plus]
    else
      raise ArgumentError, "Unknown device type: #{device_type}"
    end
  end

  # Normalize screenshots to App Store Connect required dimensions
  # @param input_dir [String] Directory containing raw screenshots
  # @param output_dir [String] Directory for normalized screenshots
  # @param options [Hash] Normalization options
  # @option options [Boolean] :auto_detect Auto-detect device types (default: true)
  # @option options [Symbol] :force_target Force a specific target size key
  def self.normalize_screenshots(input_dir, output_dir, options = {})
    auto_detect = options.fetch(:auto_detect, true)
    force_target = options[:force_target]
    
    FileUtils.mkdir_p(output_dir)

    locales = %w[en-US fi]
    normalized_count = 0
    stats = { iphone: 0, ipad: 0, watch: 0, skipped: 0 }

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
        
        # Skip already framed screenshots
        next if basename.include?('_framed')
        
        dst_file = File.join(dst_dir, basename)

        # Detect device type
        device_type = auto_detect ? detect_device_type(basename) : nil
        
        unless device_type
          puts "⚠️  #{locale}/#{basename}: Could not detect device type, skipping"
          stats[:skipped] += 1
          next
        end

        # Get target size
        target = force_target ? OFFICIAL_SIZES[force_target] : target_size_for_device(device_type)
        
        unless target
          puts "⚠️  #{locale}/#{basename}: No target size available, skipping"
          stats[:skipped] += 1
          next
        end

        # Get current dimensions
        current_dims = `identify -format '%wx%h' #{Shellwords.escape(src_file)}`.strip
        current_width, current_height = current_dims.split('x').map(&:to_i)

        # Check if already normalized
        if current_width == target[:width] && current_height == target[:height]
          puts "✅ #{locale}/#{basename}: Already #{target[:width]}x#{target[:height]}, copying..."
          FileUtils.cp(src_file, dst_file)
          stats[device_type] += 1
          normalized_count += 1
          next
        end

        # Normalize using ImageMagick
        # Use resize with ^ to fill, then extent to exact dimensions
        cmd = [
          'convert',
          Shellwords.escape(src_file),
          '-resize', "#{target[:width]}x#{target[:height]}^",
          '-gravity', 'center',
          '-extent', "#{target[:width]}x#{target[:height]}",
          '-quality', '100',
          Shellwords.escape(dst_file)
        ].join(' ')

        puts "🔄 #{locale}/#{basename}: #{current_dims} → #{target[:width]}x#{target[:height]} (#{target[:name]})"
        system(cmd)

        unless $?.success?
          raise ValidationError, "Failed to normalize #{src_file}"
        end

        stats[device_type] += 1
        normalized_count += 1
      end
    end

    # Print summary
    puts "\n" + "=" * 70
    puts "Screenshot Normalization Summary"
    puts "=" * 70
    puts "iPhone: #{stats[:iphone]} screenshots normalized to #{OFFICIAL_SIZES[:iphone_67][:width]}x#{OFFICIAL_SIZES[:iphone_67][:height]}"
    puts "iPad: #{stats[:ipad]} screenshots normalized to #{OFFICIAL_SIZES[:ipad_13][:width]}x#{OFFICIAL_SIZES[:ipad_13][:height]}"
    puts "Watch: #{stats[:watch]} screenshots normalized to #{OFFICIAL_SIZES[:watch_series7plus][:width]}x#{OFFICIAL_SIZES[:watch_series7plus][:height]}"
    puts "Skipped: #{stats[:skipped]}" if stats[:skipped] > 0
    puts "Total: #{normalized_count} screenshots"
    puts "=" * 70

    normalized_count
  end

  # Validate screenshots match App Store Connect requirements
  # @param screenshots_dir [String] Directory containing screenshots
  # @param options [Hash] Validation options
  # @option options [Integer] :expected_count Expected screenshots per locale per device
  # @option options [Array<Symbol>] :allowed_sizes Allowed size keys from OFFICIAL_SIZES
  # @option options [Boolean] :strict Fail on warnings (default: false)
  def self.validate_screenshots(screenshots_dir, options = {})
    expected_count = options[:expected_count]
    allowed_sizes = options[:allowed_sizes] || OFFICIAL_SIZES.keys
    strict = options.fetch(:strict, false)
    
    locales = %w[en-US fi]
    errors = []
    warnings = []
    
    device_counts = { iphone: 0, ipad: 0, watch: 0 }
    total_valid = 0

    locales.each do |locale|
      locale_dir = File.join(screenshots_dir, locale)

      unless Dir.exist?(locale_dir)
        errors << "❌ #{locale}: Directory not found at #{locale_dir}"
        next
      end

      screenshots = Dir.glob(File.join(locale_dir, "*.png")).reject { |f| f.include?('_framed') }.sort

      if screenshots.empty?
        errors << "❌ #{locale}: No screenshots found"
        next
      end

      if expected_count && screenshots.count < expected_count
        warnings << "⚠️  #{locale}: Expected #{expected_count} screenshots, found #{screenshots.count}"
      end

      screenshots.each do |shot|
        basename = File.basename(shot)
        device_type = detect_device_type(basename)

        # Check dimensions
        begin
          dimensions = `identify -format '%wx%h' #{Shellwords.escape(shot)}`.strip
          width, height = dimensions.split('x').map(&:to_i)

          # Find matching size
          matching_size = OFFICIAL_SIZES.find do |key, size|
            allowed_sizes.include?(key) && size[:width] == width && size[:height] == height
          end

          if matching_size
            size_key, size_info = matching_size
            puts "✅ #{locale}/#{basename}: #{dimensions} (#{size_info[:name]})"
            device_counts[device_type] += 1 if device_type
            total_valid += 1
          else
            # Check if close to an official size
            closest = find_closest_size(width, height, allowed_sizes)
            if closest
              errors << "❌ #{locale}/#{basename}: #{dimensions} - Should be #{closest[:width]}x#{closest[:height]} (#{closest[:name]})"
            else
              errors << "❌ #{locale}/#{basename}: #{dimensions} - Not a valid App Store Connect size"
            end
          end

          # Sanity checks
          if width < 1000 && device_type != :watch
            errors << "❌ #{locale}/#{basename}: #{dimensions} - Dimensions too small for iOS/iPadOS"
          elsif width < 300 && device_type == :watch
            errors << "❌ #{locale}/#{basename}: #{dimensions} - Dimensions too small for watchOS"
          end

          # Check file size
          file_size_kb = File.size(shot) / 1024
          if file_size_kb > 2048
            warnings << "⚠️  #{locale}/#{basename}: Large file size (#{file_size_kb} KB)"
          end

        rescue => e
          errors << "❌ #{locale}/#{basename}: Failed to validate - #{e.message}"
        end
      end
    end

    # Print summary
    puts "\n" + "=" * 70
    puts "Screenshot Validation Summary"
    puts "=" * 70
    puts "Device breakdown:"
    puts "  iPhone: #{device_counts[:iphone]} screenshots"
    puts "  iPad: #{device_counts[:ipad]} screenshots"
    puts "  Watch: #{device_counts[:watch]} screenshots"
    puts "  Total valid: #{total_valid}"

    if warnings.any?
      puts "\nWarnings:"
      warnings.each { |w| puts w }
    end

    if errors.any?
      puts "\nErrors:"
      errors.each { |e| puts e }
      puts "\n❌ Validation FAILED: #{errors.count} error(s) found"
      raise ValidationError, "Screenshot validation failed"
    elsif strict && warnings.any?
      puts "\n❌ Validation FAILED: #{warnings.count} warning(s) in strict mode"
      raise ValidationError, "Screenshot validation failed (strict mode)"
    else
      puts "\n✅ All #{total_valid} screenshots are valid!"
      puts "\nAccepted sizes:"
      allowed_sizes.each do |key|
        size = OFFICIAL_SIZES[key]
        puts "  • #{size[:name]}: #{size[:width]}x#{size[:height]}"
      end
    end

    true
  end

  # Find the closest official size to given dimensions
  # @param width [Integer] Current width
  # @param height [Integer] Current height
  # @param allowed_keys [Array<Symbol>] Allowed size keys
  # @return [Hash, nil] Closest size or nil
  def self.find_closest_size(width, height, allowed_keys)
    min_distance = Float::INFINITY
    closest = nil

    allowed_keys.each do |key|
      size = OFFICIAL_SIZES[key]
      distance = Math.sqrt((width - size[:width])**2 + (height - size[:height])**2)

      if distance < min_distance && distance < 100  # Within 100 pixels
        min_distance = distance
        closest = size
      end
    end

    closest
  end
end
