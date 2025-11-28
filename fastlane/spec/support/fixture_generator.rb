# frozen_string_literal: true

require 'shellwords'
require 'fileutils'

module FixtureGenerator
  # Create a test screenshot with specific dimensions and color
  # Uses ImageMagick to generate a PNG file
  def create_test_screenshot(path, width, height, color = '#FFFFFF')
    FileUtils.mkdir_p(File.dirname(path))

    cmd = "magick -size #{width}x#{height} xc:#{color} #{Shellwords.escape(path)}"
    success = system(cmd + ' > /dev/null 2>&1')

    raise "Failed to create test screenshot: #{path}" unless success
    raise "Test screenshot not created: #{path}" unless File.exist?(path)
  end

  # Create a test device frame with transparent background
  # Uses ImageMagick to generate a PNG with device shape
  def create_test_frame(path, width, height, screen_area = nil)
    FileUtils.mkdir_p(File.dirname(path))

    # Default screen area to centered 80% of frame
    screen_area ||= {
      x: (width * 0.1).to_i,
      y: (height * 0.1).to_i,
      width: (width * 0.8).to_i,
      height: (height * 0.8).to_i
    }

    # Create a frame with rounded rectangle and transparent center
    # This simulates a device bezel
    cmd = <<~CMD.gsub("\n", ' ')
      magick -size #{width}x#{height} xc:none
      -fill '#333333'
      -draw 'roundrectangle 0,0,#{width},#{height},50,50'
      -fill none
      -draw 'roundrectangle #{screen_area[:x]},#{screen_area[:y]},#{screen_area[:x] + screen_area[:width]},#{screen_area[:y] + screen_area[:height]},40,40'
      #{Shellwords.escape(path)}
    CMD

    success = system(cmd + ' > /dev/null 2>&1')

    raise "Failed to create test frame: #{path}" unless success
    raise "Test frame not created: #{path}" unless File.exist?(path)
  end

  # Create a test metadata.json file for a device frame
  def create_test_metadata(path, device_name, screen_area, frame_dimensions)
    FileUtils.mkdir_p(File.dirname(path))

    metadata = {
      device: device_name,
      screen_area: screen_area,
      frame_dimensions: frame_dimensions,
      variants: {
        black: "#{device_name.downcase.gsub(' ', '_')}_black.png"
      },
      default_variant: 'black',
      corner_radius: 55
    }

    File.write(path, JSON.pretty_generate(metadata))
  end

  # Get dimensions of an image file using ImageMagick
  def get_image_dimensions(path)
    return nil unless File.exist?(path)

    output = `identify -format '%wx%h' #{Shellwords.escape(path)} 2>/dev/null`.strip
    return nil if output.empty?

    width, height = output.split('x').map(&:to_i)
    { width: width, height: height }
  end

  # Get pixel color at specific coordinates
  def get_pixel_color(path, x, y)
    return nil unless File.exist?(path)

    output = `magick #{Shellwords.escape(path)} -format '%[pixel:p{#{x},#{y}}]' info: 2>/dev/null`.strip
    output.empty? ? nil : output
  end

  # Verify an image is a valid PNG
  def valid_png?(path)
    return false unless File.exist?(path)

    system("identify #{Shellwords.escape(path)} > /dev/null 2>&1")
  end

  # Create a corrupted file for error testing
  def create_corrupted_file(path, content = 'not a valid image')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  # Clean up test files and directories
  def cleanup_test_files(*paths)
    paths.each do |path|
      if File.directory?(path)
        FileUtils.rm_rf(path)
      elsif File.exist?(path)
        File.delete(path)
      end
    end
  end
end
