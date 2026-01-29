#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone script to normalize and validate watchOS screenshots
# Usage: ruby fastlane/lib/normalize_watch_screenshots.rb

require_relative 'watch_screenshot_helper'

# Configuration
INPUT_DIR = File.expand_path("../../screenshots/watch", __FILE__)
OUTPUT_DIR = File.expand_path("../../screenshots/watch_normalized", __FILE__)
TARGET_SIZE = :series10  # Apple Watch Series 10 (46mm) - 416x496

def main
  puts "=" * 70
  puts "watchOS Screenshot Normalization & Validation"
  puts "=" * 70
  puts ""
  
  # Check if ImageMagick is installed
  unless system("which convert > /dev/null 2>&1")
    puts "❌ Error: ImageMagick not found!"
    puts "   Install with: brew install imagemagick"
    exit 1
  end
  
  unless Dir.exist?(INPUT_DIR)
    puts "❌ Error: Input directory not found: #{INPUT_DIR}"
    puts "   Run 'bundle exec fastlane ios watch_screenshots' first"
    exit 1
  end
  
  # Step 1: Normalize screenshots
  puts "Step 1: Normalizing screenshots from #{INPUT_DIR}"
  puts "        to #{OUTPUT_DIR}"
  puts ""
  
  begin
    count = WatchScreenshotHelper.normalize_screenshots(
      INPUT_DIR,
      OUTPUT_DIR,
      target_size: TARGET_SIZE
    )
    puts ""
  rescue => e
    puts "❌ Normalization failed: #{e.message}"
    exit 1
  end
  
  # Step 2: Validate normalized screenshots
  puts "\n" + "=" * 70
  puts "Step 2: Validating normalized screenshots"
  puts "=" * 70
  puts ""
  
  begin
    WatchScreenshotHelper.validate_screenshots(
      OUTPUT_DIR,
      expected_count: 5,
      allowed_sizes: [TARGET_SIZE]
    )
  rescue WatchScreenshotHelper::ValidationError => e
    puts "❌ Validation failed"
    exit 1
  end
  
  puts "\n" + "=" * 70
  puts "✅ SUCCESS: All watch screenshots normalized and validated!"
  puts "=" * 70
  puts ""
  puts "Next steps:"
  puts "  1. Review normalized screenshots in: #{OUTPUT_DIR}"
  puts "  2. Run 'bundle exec fastlane ios watch_screenshots' to integrate"
  puts "  3. Run 'bundle exec fastlane ios release_dry_run' to verify delivery"
end

if __FILE__ == $0
  main
end
