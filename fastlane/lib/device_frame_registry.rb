# frozen_string_literal: true

require 'json'

# DeviceFrameRegistry
#
# Manages device frame metadata and provides device detection from screenshot filenames.
# This module is part of the custom screenshot framing solution that replaces Fastlane Frameit
# with support for all device types including iPad Pro 13" M4 and Apple Watch.
#
# @example Detect device from filename
#   spec = DeviceFrameRegistry.detect_device('iPhone 16 Pro Max-01_Welcome.png')
#   # => { type: :iphone, frame: 'iphone_16_pro_max', screen_size: [1290, 2796] }
#
# @example Load frame metadata
#   metadata = DeviceFrameRegistry.frame_metadata('iphone_16_pro_max')
#   # => { device: "iPhone 16 Pro Max", screen_area: {...}, ... }
#
module DeviceFrameRegistry
  # App Store Connect required screenshot dimensions
  # These are the EXACT pixel dimensions Apple requires for each device category
  APP_STORE_DIMENSIONS = {
    iphone_6_7: { width: 1290, height: 2796, name: 'iPhone 6.7"' },
    ipad_13: { width: 2064, height: 2752, name: 'iPad 13"' },
    watch: { width: 396, height: 484, name: 'Apple Watch' }
  }.freeze

  # Custom exception raised when frame metadata cannot be found
  class FrameNotFoundError < StandardError; end

  # Device mapping patterns
  # Maps filename patterns (regex) to device specifications
  # Each specification includes:
  # - type: Device category (:iphone, :ipad, :watch)
  # - frame: Frame asset identifier (used to locate metadata and PNG files)
  # - screen_size: Expected screenshot dimensions [width, height] for validation
  DEVICE_MAPPINGS = {
    /iPhone 16 Pro Max/ => {
      type: :iphone,
      frame: 'iphone_16_pro_max',
      screen_size: [1290, 2796]
    },
    /iPad Pro 13-inch \(M4\)/ => {
      type: :ipad,
      frame: 'ipad_pro_13_m4',
      screen_size: [2064, 2752]
    },
    /Apple Watch Series 10 \(46mm\)/ => {
      type: :watch,
      frame: 'apple_watch_series_10_46mm',
      screen_size: [396, 484]
    }
  }.freeze

  # Detect device type from screenshot filename
  #
  # This method matches the filename against known device patterns and returns
  # the corresponding device specification. Returns nil if no match is found.
  #
  # @param filename [String] The screenshot filename (e.g., "iPhone 16 Pro Max-01_Welcome.png")
  # @return [Hash, nil] Device specification hash or nil if not recognized
  #   @option [Symbol] :type Device category (:iphone, :ipad, or :watch)
  #   @option [String] :frame Frame identifier for asset lookup
  #   @option [Array<Integer>] :screen_size Expected dimensions [width, height]
  #
  # @example
  #   DeviceFrameRegistry.detect_device('iPhone 16 Pro Max-01_Welcome.png')
  #   # => { type: :iphone, frame: 'iphone_16_pro_max', screen_size: [1290, 2796] }
  #
  def self.detect_device(filename)
    DEVICE_MAPPINGS.each do |pattern, config|
      return config.dup if filename.match?(pattern)
    end
    nil
  end

  # Load metadata for a specific device frame
  #
  # Reads the metadata.json file for the specified frame and returns it as a hash.
  # The metadata includes screen area coordinates, frame dimensions, and available variants.
  #
  # @param frame_name [String] Frame identifier (e.g., 'iphone_16_pro_max')
  # @return [Hash] Parsed metadata with symbolized keys
  #   @option [String] :device Human-readable device name
  #   @option [Hash] :screen_area Screen coordinates { x:, y:, width:, height: }
  #   @option [Hash] :frame_dimensions Frame size { width:, height: }
  #   @option [Hash] :variants Available frame variants { black:, white:, ... }
  #   @option [String] :default_variant Default variant to use
  #
  # @raise [FrameNotFoundError] if metadata file doesn't exist
  #
  # @example
  #   metadata = DeviceFrameRegistry.frame_metadata('iphone_16_pro_max')
  #   # => {
  #   #   device: "iPhone 16 Pro Max",
  #   #   screen_area: { x: 85, y: 155, width: 1290, height: 2796 },
  #   #   ...
  #   # }
  #
  def self.frame_metadata(frame_name)
    metadata_path = metadata_path_for(frame_name)

    unless File.exist?(metadata_path)
      raise FrameNotFoundError, "Metadata not found for frame: #{frame_name} (expected: #{metadata_path})"
    end

    JSON.parse(File.read(metadata_path), symbolize_names: true)
  rescue JSON::ParserError => e
    raise FrameNotFoundError, "Invalid JSON in metadata for #{frame_name}: #{e.message}"
  end

  # Get list of all available device frames
  #
  # Scans the device_frames directory and returns all devices that have metadata files.
  #
  # @return [Array<String>] List of device names
  #
  # @example
  #   DeviceFrameRegistry.available_frames
  #   # => ["iPhone 16 Pro Max", "iPad Pro 13-inch M4", "Apple Watch Series 10 46mm"]
  #
  def self.available_frames
    metadata_files = Dir.glob(File.expand_path('../device_frames/*/metadata.json', __dir__))
    metadata_files.map do |path|
      metadata = JSON.parse(File.read(path), symbolize_names: true)
      metadata[:device]
    end
  rescue JSON::ParserError, Errno::ENOENT
    []
  end

  # Find device by screenshot dimensions
  #
  # Searches through all device mappings to find a device that matches
  # the given screenshot dimensions.
  #
  # @param width [Integer] Screenshot width in pixels
  # @param height [Integer] Screenshot height in pixels
  # @return [Hash, nil] Device specification with enhanced fields or nil if not found
  #
  # @example
  #   spec = DeviceFrameRegistry.find_device_by_dimensions(1290, 2796)
  #   # => {
  #   #   type: :iphone,
  #   #   frame: 'iphone_16_pro_max',
  #   #   screen_size: [1290, 2796],
  #   #   name: 'iPhone 16 Pro Max',
  #   #   screenshot_width: 1290,
  #   #   screenshot_height: 2796,
  #   #   screenshot_x: 85,
  #   #   screenshot_y: 155,
  #   #   final_width: 1460,
  #   #   final_height: 3106,
  #   #   frame_name: 'iphone_16_pro_max'
  #   # }
  #
  def self.find_device_by_dimensions(width, height)
    DEVICE_MAPPINGS.each do |_pattern, config|
      if config[:screen_size] == [width, height]
        # Load metadata and enhance device spec
        metadata = frame_metadata(config[:frame])
        return enhance_device_spec(config.dup, metadata)
      end
    end
    nil
  end

  # Get App Store target dimensions for a device type
  #
  # @param device_type [Symbol] Device type (:iphone, :ipad, :watch)
  # @return [Hash, nil] App Store dimensions { width:, height:, name: } or nil
  #
  # @example
  #   DeviceFrameRegistry.app_store_dimensions(:iphone)
  #   # => { width: 1290, height: 2796, name: 'iPhone 6.7"' }
  #
  def self.app_store_dimensions(device_type)
    case device_type
    when :iphone
      APP_STORE_DIMENSIONS[:iphone_6_7]
    when :ipad
      APP_STORE_DIMENSIONS[:ipad_13]
    when :watch
      APP_STORE_DIMENSIONS[:watch]
    end
  end

  # Enhance device specification with metadata fields
  #
  # Transforms metadata structure into fields expected by FramingHelper.
  # Bridges the gap between metadata.json format and code expectations.
  #
  # @param device_spec [Hash] Base device specification from DEVICE_MAPPINGS
  # @param metadata [Hash] Metadata loaded from JSON file
  # @return [Hash] Enhanced device specification with all required fields
  #
  # @api private
  def self.enhance_device_spec(device_spec, metadata)
    app_store = app_store_dimensions(device_spec[:type])

    device_spec.merge({
      name: metadata[:device],
      screenshot_width: metadata[:screen_area][:width],
      screenshot_height: metadata[:screen_area][:height],
      screenshot_x: metadata[:screen_area][:x],
      screenshot_y: metadata[:screen_area][:y],
      final_width: metadata[:frame_dimensions][:width],
      final_height: metadata[:frame_dimensions][:height],
      frame_name: device_spec[:frame],
      # App Store target dimensions
      app_store_width: app_store ? app_store[:width] : nil,
      app_store_height: app_store ? app_store[:height] : nil
    })
  end
  private_class_method :enhance_device_spec

  # Resolve the path to a frame's metadata file
  #
  # @param frame_name [String] Frame identifier (e.g., 'iphone_16_pro_max')
  # @return [String] Absolute path to metadata.json
  #
  # @api private
  def self.metadata_path_for(frame_name)
    # Extract device type from frame name
    # Handle special case: 'apple_watch_*' -> 'watch'
    device_type = if frame_name.start_with?('apple_watch')
                    'watch'
                  else
                    frame_name.split('_').first
                  end

    File.expand_path("../device_frames/#{device_type}/metadata.json", __dir__)
  end
  private_class_method :metadata_path_for
end
