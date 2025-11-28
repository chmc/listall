# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require_relative 'device_frame_registry'

module FramingHelper
  # Custom exception classes for better error handling
  class FramingError < StandardError; end
  class ScreenshotNotFoundError < FramingError; end
  class DimensionMismatchError < FramingError; end
  class FrameAssetMissingError < FramingError; end
  class ImageMagickError < FramingError; end

  # Default options for framing operations
  DEFAULT_OPTIONS = {
    background_color: '#0E1117',
    quality: 95,
    gravity: 'center',
    skip_if_exists: false,
    verbose: false
  }.freeze

  # Frame a single screenshot with device frame
  #
  # @param screenshot_path [String] Path to the screenshot to frame
  # @param output_path [String] Path where framed screenshot will be saved
  # @param device_spec [Hash] Device specification from DeviceFrameRegistry
  # @param options [Hash] Additional options for framing
  # @return [Boolean] true if successful
  # @raise [ScreenshotNotFoundError] if screenshot file doesn't exist
  # @raise [DimensionMismatchError] if screenshot dimensions don't match device spec
  # @raise [FrameAssetMissingError] if frame asset file doesn't exist
  # @raise [ImageMagickError] if ImageMagick command fails
  def self.frame_screenshot(screenshot_path, output_path, device_spec, options = {})
    opts = DEFAULT_OPTIONS.merge(options)

    # Skip if output already exists and skip_if_exists is true
    if opts[:skip_if_exists] && File.exist?(output_path)
      puts "Skipping #{File.basename(output_path)} (already exists)" if opts[:verbose]
      return true
    end

    # Validate input screenshot
    validate_screenshot!(screenshot_path, device_spec)

    # Determine frame variant (light/dark)
    variant = opts[:variant] || :light

    # Validate and resolve frame asset
    frame_name = device_spec[:frame_name]
    validate_frame_asset!(frame_name, variant)
    frame_path = resolve_frame_asset(frame_name, variant)

    # Create output directory if it doesn't exist
    FileUtils.mkdir_p(File.dirname(output_path))

    # Execute ImageMagick composite command
    execute_composite(
      frame_path: frame_path,
      screenshot_path: screenshot_path,
      output_path: output_path,
      device_spec: device_spec,
      options: opts
    )

    # Verify output was created successfully
    verify_output!(output_path)

    puts "Framed: #{File.basename(screenshot_path)} -> #{File.basename(output_path)}" if opts[:verbose]
    true
  end

  # Frame all screenshots in a directory
  #
  # @param input_dir [String] Directory containing screenshots to frame
  # @param output_dir [String] Directory where framed screenshots will be saved
  # @param options [Hash] Additional options for framing
  # @return [Integer] Number of screenshots framed
  def self.frame_all_screenshots(input_dir, output_dir, options = {})
    opts = DEFAULT_OPTIONS.merge(options)

    unless Dir.exist?(input_dir)
      raise FramingError, "Input directory does not exist: #{input_dir}"
    end

    # Find all PNG files in input directory
    screenshots = Dir.glob(File.join(input_dir, '*.png')).sort

    if screenshots.empty?
      puts "No screenshots found in #{input_dir}" if opts[:verbose]
      return 0
    end

    framed_count = 0

    screenshots.each do |screenshot_path|
      begin
        # Get dimensions to determine device type
        width, height = get_dimensions(screenshot_path)

        # Find matching device spec
        device_spec = DeviceFrameRegistry.find_device_by_dimensions(width, height)

        unless device_spec
          puts "Warning: No device spec found for dimensions #{width}x#{height}, skipping #{File.basename(screenshot_path)}" if opts[:verbose]
          next
        end

        # Generate output path
        output_path = File.join(output_dir, File.basename(screenshot_path))

        # Frame the screenshot
        frame_screenshot(screenshot_path, output_path, device_spec, opts)
        framed_count += 1

      rescue FramingError => e
        puts "Error framing #{File.basename(screenshot_path)}: #{e.message}"
        raise if opts[:strict]
      end
    end

    puts "Framed #{framed_count} screenshot(s)" if opts[:verbose]
    framed_count
  end

  # Frame all screenshots across all locales
  #
  # @param input_root [String] Root directory containing locale subdirectories
  # @param output_root [String] Root directory where framed screenshots will be saved
  # @param options [Hash] Additional options for framing
  # @return [Hash] Summary of framing operation
  def self.frame_all_locales(input_root, output_root, options = {})
    opts = DEFAULT_OPTIONS.merge(options)

    unless Dir.exist?(input_root)
      raise FramingError, "Input root directory does not exist: #{input_root}"
    end

    # Find all locale directories (e.g., en-US, fi)
    locale_dirs = Dir.glob(File.join(input_root, '*')).select { |path| File.directory?(path) }

    if locale_dirs.empty?
      puts "No locale directories found in #{input_root}" if opts[:verbose]
      return { total_screenshots: 0, locales: 0 }
    end

    total_framed = 0
    locales_processed = 0

    locale_dirs.each do |locale_dir|
      locale = File.basename(locale_dir)
      puts "\nProcessing locale: #{locale}" if opts[:verbose]

      output_locale_dir = File.join(output_root, locale)

      begin
        count = frame_all_screenshots(locale_dir, output_locale_dir, opts)
        total_framed += count
        locales_processed += 1
      rescue FramingError => e
        puts "Error processing locale #{locale}: #{e.message}"
        raise if opts[:strict]
      end
    end

    summary = {
      total_screenshots: total_framed,
      locales: locales_processed
    }

    if opts[:verbose]
      puts "\n=== Framing Summary ==="
      puts "Total screenshots framed: #{summary[:total_screenshots]}"
      puts "Locales processed: #{summary[:locales]}"
    end

    summary
  end

  # Private helper methods

  # Validate that screenshot exists and has correct dimensions
  #
  # @param path [String] Path to screenshot file
  # @param device_spec [Hash] Device specification
  # @raise [ScreenshotNotFoundError] if file doesn't exist
  # @raise [DimensionMismatchError] if dimensions don't match
  def self.validate_screenshot!(path, device_spec)
    unless File.exist?(path)
      raise ScreenshotNotFoundError, "Screenshot not found: #{path}"
    end

    width, height = get_dimensions(path)
    expected_width = device_spec[:screenshot_width]
    expected_height = device_spec[:screenshot_height]

    if width != expected_width || height != expected_height
      raise DimensionMismatchError,
            "Screenshot dimensions #{width}x#{height} do not match expected " \
            "#{expected_width}x#{expected_height} for device #{device_spec[:name]}"
    end
  end
  private_class_method :validate_screenshot!

  # Validate that frame asset exists
  #
  # @param frame_name [String] Name of the frame asset
  # @param variant [Symbol] Frame variant (:light or :dark)
  # @raise [FrameAssetMissingError] if frame asset doesn't exist
  def self.validate_frame_asset!(frame_name, variant)
    frame_path = resolve_frame_asset(frame_name, variant)

    unless File.exist?(frame_path)
      raise FrameAssetMissingError,
            "Frame asset not found: #{frame_path}\n" \
            "Please ensure frame assets are installed in fastlane/frames/"
    end
  end
  private_class_method :validate_frame_asset!

  # Resolve the full path to a frame asset
  #
  # @param frame_name [String] Name of the frame asset (e.g., 'iphone_16_pro_max')
  # @param variant [Symbol] Frame variant (:light or :dark)
  # @return [String] Full path to frame asset
  def self.resolve_frame_asset(frame_name, variant)
    # Frame assets are stored in fastlane/device_frames/{device_type}/
    # Extract device type from frame name (e.g., 'iphone' from 'iphone_16_pro_max')
    device_type = if frame_name.start_with?('apple_watch')
                    'watch'
                  else
                    frame_name.split('_').first
                  end

    # Map variant to filename suffix
    # Metadata uses 'black' as default, we need to map :light -> black
    variant_suffix = case variant
                     when :dark
                       '_dark'
                     when :light, :black
                       '_black'
                     else
                       "_#{variant}"
                     end

    File.join(File.dirname(__dir__), 'device_frames', device_type, "#{frame_name}#{variant_suffix}.png")
  end
  private_class_method :resolve_frame_asset

  # Get image dimensions using ImageMagick identify
  #
  # @param path [String] Path to image file
  # @return [Array<Integer>] Width and height as [width, height]
  # @raise [ImageMagickError] if identify command fails
  def self.get_dimensions(path)
    escaped_path = Shellwords.escape(path)
    output = `magick identify -format '%w %h' #{escaped_path} 2>&1`

    unless $?.success?
      raise ImageMagickError, "Failed to get dimensions for #{path}: #{output}"
    end

    width, height = output.strip.split.map(&:to_i)

    if width.nil? || height.nil? || width <= 0 || height <= 0
      raise ImageMagickError, "Invalid dimensions for #{path}: #{output}"
    end

    [width, height]
  end
  private_class_method :get_dimensions

  # Execute ImageMagick composite command
  #
  # @param frame_path [String] Path to frame asset
  # @param screenshot_path [String] Path to screenshot
  # @param output_path [String] Path for output
  # @param device_spec [Hash] Device specification
  # @param options [Hash] Additional options
  # @raise [ImageMagickError] if composite command fails
  def self.execute_composite(frame_path:, screenshot_path:, output_path:, device_spec:, options:)
    cmd = build_imagemagick_command(
      frame_path: frame_path,
      screenshot_path: screenshot_path,
      output_path: output_path,
      device_spec: device_spec,
      options: options
    )

    # Execute command
    output = `#{cmd} 2>&1`

    unless $?.success?
      raise ImageMagickError,
            "ImageMagick composite failed:\nCommand: #{cmd}\nOutput: #{output}"
    end
  end
  private_class_method :execute_composite

  # Build ImageMagick composite command
  #
  # @param frame_path [String] Path to frame asset
  # @param screenshot_path [String] Path to screenshot
  # @param output_path [String] Path for output
  # @param device_spec [Hash] Device specification
  # @param options [Hash] Additional options
  # @return [String] Complete ImageMagick command
  def self.build_imagemagick_command(frame_path:, screenshot_path:, output_path:, device_spec:, options:)
    # Escape all file paths
    escaped_frame = Shellwords.escape(frame_path)
    escaped_screenshot = Shellwords.escape(screenshot_path)
    escaped_output = Shellwords.escape(output_path)

    # Get positioning from device spec
    x_offset = device_spec[:screenshot_x]
    y_offset = device_spec[:screenshot_y]
    final_width = device_spec[:final_width]
    final_height = device_spec[:final_height]

    # Build command
    # Pattern: magick <frame> <screenshot> -geometry +X+Y -composite -background <color> -gravity <gravity> -extent WxH -quality <quality> <output>
    cmd_parts = [
      'magick',
      escaped_frame,
      escaped_screenshot,
      "-geometry +#{x_offset}+#{y_offset}",
      '-composite',
      "-background '#{options[:background_color]}'",
      "-gravity #{options[:gravity]}",
      "-extent #{final_width}x#{final_height}",
      "-quality #{options[:quality]}",
      escaped_output
    ]

    cmd_parts.join(' ')
  end
  private_class_method :build_imagemagick_command

  # Verify that output file was created successfully
  #
  # @param path [String] Path to output file
  # @raise [ImageMagickError] if output file doesn't exist or is invalid
  def self.verify_output!(path)
    unless File.exist?(path)
      raise ImageMagickError, "Output file was not created: #{path}"
    end

    unless File.size(path) > 0
      raise ImageMagickError, "Output file is empty: #{path}"
    end

    # Verify it's a valid image by checking dimensions
    begin
      get_dimensions(path)
    rescue ImageMagickError => e
      raise ImageMagickError, "Output file is not a valid image: #{path} (#{e.message})"
    end
  end
  private_class_method :verify_output!
end
