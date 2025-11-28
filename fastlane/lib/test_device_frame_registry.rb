#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick verification script for DeviceFrameRegistry module
# Run with: ruby -I lib lib/test_device_frame_registry.rb

require_relative 'device_frame_registry'

puts "=== DeviceFrameRegistry Verification ==="
puts

# Test 1: Device Detection
puts "Test 1: Device Detection"
puts "-" * 50

test_files = [
  'iPhone 16 Pro Max-01_Welcome.png',
  'iPad Pro 13-inch (M4)-02_MainScreen.png',
  'Apple Watch Series 10 (46mm)-01_Watch.png',
  'Unknown Device-03_Test.png'
]

test_files.each do |filename|
  result = DeviceFrameRegistry.detect_device(filename)
  if result
    puts "✓ #{filename}"
    puts "  Type: #{result[:type]}, Frame: #{result[:frame]}, Size: #{result[:screen_size].join('x')}"
  else
    puts "✗ #{filename}"
    puts "  Not recognized (expected for unknown devices)"
  end
  puts
end

# Test 2: Metadata Loading
puts "Test 2: Metadata Loading"
puts "-" * 50

['iphone_16_pro_max', 'ipad_pro_13_m4', 'apple_watch_series_10_46mm'].each do |frame_name|
  begin
    metadata = DeviceFrameRegistry.frame_metadata(frame_name)
    puts "✓ #{frame_name}"
    puts "  Device: #{metadata[:device]}"
    puts "  Screen Area: #{metadata[:screen_area][:width]}x#{metadata[:screen_area][:height]} at (#{metadata[:screen_area][:x]}, #{metadata[:screen_area][:y]})"
    puts "  Frame Size: #{metadata[:frame_dimensions][:width]}x#{metadata[:frame_dimensions][:height]}"
    puts "  Default Variant: #{metadata[:default_variant]}"
    puts "  Available Variants: #{metadata[:variants].keys.join(', ')}"
  rescue DeviceFrameRegistry::FrameNotFoundError => e
    puts "✗ #{frame_name}"
    puts "  Error: #{e.message}"
  end
  puts
end

# Test 3: Error Handling
puts "Test 3: Error Handling"
puts "-" * 50

begin
  DeviceFrameRegistry.frame_metadata('nonexistent_device')
  puts "✗ Should have raised FrameNotFoundError"
rescue DeviceFrameRegistry::FrameNotFoundError => e
  puts "✓ FrameNotFoundError raised correctly"
  puts "  Message: #{e.message}"
end
puts

# Test 4: Available Frames
puts "Test 4: Available Frames"
puts "-" * 50

frames = DeviceFrameRegistry.available_frames
if frames.any?
  puts "✓ Found #{frames.count} available frame(s):"
  frames.each { |f| puts "  - #{f}" }
else
  puts "✗ No frames found"
end
puts

puts "=== Verification Complete ==="
