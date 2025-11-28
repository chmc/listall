# frozen_string_literal: true

require 'rspec'
require 'fileutils'
require 'json'
require 'shellwords'

# Set up test environment
RSpec.configure do |config|
  # Use expect syntax (not should)
  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  # Disable monkey patching (use recommended style)
  config.disable_monkey_patching!

  # Output formatting
  config.color = true
  config.tty = true
  config.formatter = :documentation

  # Fail fast on first failure (optional - comment out for full run)
  # config.fail_fast = true

  # Random order to catch test dependencies
  config.order = :random
  Kernel.srand config.seed

  # Global before/after hooks
  config.before(:suite) do
    puts "\n=== RSpec Test Suite for Screenshot Framing ==="
    puts "ImageMagick: #{`which magick`.strip}"
    puts "Ruby: #{RUBY_VERSION}"
    puts "=" * 60
  end

  config.after(:suite) do
    puts "\n" + "=" * 60
    puts "Test suite completed"
  end
end

# Helper method to check if ImageMagick is available
def imagemagick_available?
  system('which magick > /dev/null 2>&1')
end

# Skip tests requiring ImageMagick if not available
RSpec.configure do |config|
  config.before(:each) do |example|
    if example.metadata[:requires_imagemagick] && !imagemagick_available?
      skip "ImageMagick not installed (required for this test)"
    end
  end
end
