# Custom Screenshot Framing Solution - Implementation Plan

**Generated:** 2025-11-28
**Branch:** feature/framed-screenshots
**Status:** Planning Phase

---

## Executive Summary

This plan outlines the implementation of a custom screenshot framing solution for the ListAll app. The solution replaces Fastlane Frameit with a custom implementation that:

1. Supports **all device types**: iPhone 16 Pro Max, iPad Pro 13" M4, Apple Watch Series 10
2. Uses **official Apple device frames** from Apple Design Resources
3. Follows **Test-Driven Development (TDD)** methodology
4. Integrates seamlessly with existing Fastlane pipeline

### Why Custom Implementation?

| Issue | Frameit Limitation | Custom Solution |
|-------|-------------------|-----------------|
| iPad 13" M4 | Not supported (2064x2752) | Full support |
| Apple Watch | Never supported | Full support |
| Device frames | Facebook frameset (outdated) | Apple official frames |
| iPhone 16 | Uses iPhone 14 as proxy | Exact device match |

---

## Table of Contents

1. [Apple Requirements Research](#1-apple-requirements-research)
2. [Architecture Design](#2-architecture-design)
3. [TDD Implementation Plan](#3-tdd-implementation-plan)
4. [Asset Requirements](#4-asset-requirements)
5. [Script Implementation](#5-script-implementation)
6. [Validation & Testing](#6-validation--testing)
7. [Integration Points](#7-integration-points)
8. [Rollout Plan](#8-rollout-plan)

---

## 1. Apple Requirements Research

### 1.1 Official Screenshot Specifications

**Source:** [Apple App Store Connect Documentation](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)

| Platform | Display | Exact Dimensions | Current Status |
|----------|---------|------------------|----------------|
| iPhone | 6.7" | 1290 x 2796 | Framed (Frameit) |
| iPad | 13" | 2064 x 2752 | NOT framed |
| Apple Watch | 45mm | 396 x 484 | NOT framed |

### 1.2 Device Frame Guidelines

**Allowed:**
- Device frames showing app on appropriate Apple hardware
- Using Apple-provided product bezels
- Text overlays demonstrating input mechanisms

**Prohibited:**
- Images of people holding devices
- Wrong device frame for screenshot size
- Stretched or non-representative screenshots

### 1.3 Official Frame Sources

**Primary:** [Apple Design Resources](https://developer.apple.com/design/resources/)

Available formats:
- Photoshop (.psd)
- PNG (transparent backgrounds)
- Sketch Library

**Available Devices (January 2025):**
- iPhone 17, 16, 15 series
- iPad Pro M4 (13"), iPad Air M2, iPad mini
- Apple Watch Ultra 3, Series 11
- MacBook, iMac, Apple TV

### 1.4 Licensing

- License: Non-exclusive, royalty-free, worldwide
- Requirement: Apple Developer Program membership
- Usage: App Store marketing materials only
- Agreement: Marketing Artwork License Agreement required

---

## 2. Architecture Design

### 2.1 Directory Structure

```
fastlane/
├── screenshots/                    # Raw simulator captures
│   ├── en-US/
│   ├── fi/
│   └── watch/
│       ├── en-US/
│       └── fi/
│
├── screenshots_normalized/         # App Store ready (NEW)
│   ├── en-US/
│   │   ├── iPhone 16 Pro Max-01_Welcome.png
│   │   └── iPad Pro 13-inch (M4)-01_Welcome.png
│   └── fi/
│
├── screenshots/watch_normalized/   # Watch App Store ready
│   ├── en-US/
│   └── fi/
│
├── screenshots_framed/             # Marketing screenshots (NEW)
│   ├── iphone/
│   │   ├── en-US/
│   │   └── fi/
│   ├── ipad/
│   │   ├── en-US/
│   │   └── fi/
│   └── watch/
│       ├── en-US/
│       └── fi/
│
├── device_frames/                  # Device frame assets (NEW)
│   ├── iphone/
│   │   ├── iphone_16_pro_max_black.png
│   │   └── metadata.json
│   ├── ipad/
│   │   ├── ipad_pro_13_black.png
│   │   └── metadata.json
│   └── watch/
│       ├── apple_watch_series_10_black.png
│       └── metadata.json
│
├── lib/
│   ├── screenshot_helper.rb        # Existing
│   ├── framing_helper.rb           # NEW
│   └── device_frame_registry.rb    # NEW
│
├── Framefile.json                  # Existing (titles/subtitles)
└── Fastfile                        # Extended
```

### 2.2 Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Raw Capture    │────▶│  Normalization   │────▶│  App Store      │
│  (Simulators)   │     │  (Exact dims)    │     │  Connect        │
└─────────────────┘     └────────┬─────────┘     └─────────────────┘
                                 │
                                 ▼
                        ┌──────────────────┐     ┌─────────────────┐
                        │  Custom Framing  │────▶│  Marketing      │
                        │  (Device bezels) │     │  (Website/Ads)  │
                        └──────────────────┘     └─────────────────┘
```

### 2.3 Frame Metadata Format

```json
{
  "device": "iPhone 16 Pro Max",
  "screen_area": {
    "x": 85,
    "y": 155,
    "width": 1290,
    "height": 2796
  },
  "frame_dimensions": {
    "width": 1460,
    "height": 3106
  },
  "variants": {
    "black": "iphone_16_pro_max_black.png",
    "white": "iphone_16_pro_max_white.png"
  },
  "default_variant": "black",
  "corner_radius": 55
}
```

---

## 3. TDD Implementation Plan

### 3.1 TDD Methodology Overview

Following **Red-Green-Refactor** cycle:

1. **RED:** Write a failing test first
2. **GREEN:** Write minimal code to pass the test
3. **REFACTOR:** Improve code while keeping tests green

### 3.2 Test Infrastructure Setup

**File:** `fastlane/spec/framing_helper_spec.rb`

```ruby
# frozen_string_literal: true

require 'rspec'
require 'fileutils'
require 'json'
require_relative '../lib/framing_helper'
require_relative '../lib/device_frame_registry'

RSpec.describe FramingHelper do
  let(:fixtures_dir) { File.expand_path('fixtures', __dir__) }
  let(:temp_dir) { File.expand_path('tmp', __dir__) }

  before(:each) do
    FileUtils.mkdir_p(temp_dir)
  end

  after(:each) do
    FileUtils.rm_rf(temp_dir)
  end

  # Tests defined below in TDD order
end
```

### 3.3 TDD Implementation Cycles

#### Cycle 1: Device Frame Registry

**RED - Write failing test first:**

```ruby
# spec/device_frame_registry_spec.rb

RSpec.describe DeviceFrameRegistry do
  describe '.detect_device' do
    it 'detects iPhone from filename' do
      result = DeviceFrameRegistry.detect_device('iPhone 16 Pro Max-01_Welcome.png')
      expect(result[:type]).to eq(:iphone)
      expect(result[:frame]).to eq('iphone_16_pro_max')
    end

    it 'detects iPad from filename' do
      result = DeviceFrameRegistry.detect_device('iPad Pro 13-inch (M4)-01_Welcome.png')
      expect(result[:type]).to eq(:ipad)
      expect(result[:frame]).to eq('ipad_pro_13')
    end

    it 'detects Apple Watch from filename' do
      result = DeviceFrameRegistry.detect_device('Apple Watch Series 10 (46mm)-01_Watch.png')
      expect(result[:type]).to eq(:watch)
      expect(result[:frame]).to eq('apple_watch_series_10_46mm')
    end

    it 'returns nil for unknown device' do
      result = DeviceFrameRegistry.detect_device('Unknown-01_Test.png')
      expect(result).to be_nil
    end
  end

  describe '.frame_metadata' do
    it 'loads metadata for known frame' do
      metadata = DeviceFrameRegistry.frame_metadata('iphone_16_pro_max')
      expect(metadata[:device]).to eq('iPhone 16 Pro Max')
      expect(metadata[:screen_area][:width]).to eq(1290)
    end

    it 'raises error for missing frame' do
      expect {
        DeviceFrameRegistry.frame_metadata('nonexistent')
      }.to raise_error(DeviceFrameRegistry::FrameNotFoundError)
    end
  end
end
```

**GREEN - Implement to pass:**

```ruby
# lib/device_frame_registry.rb

module DeviceFrameRegistry
  class FrameNotFoundError < StandardError; end

  DEVICE_MAPPINGS = {
    /iPhone 16 Pro Max/ => { type: :iphone, frame: 'iphone_16_pro_max', screen_size: [1290, 2796] },
    /iPhone 17 Pro Max/ => { type: :iphone, frame: 'iphone_16_pro_max', screen_size: [1320, 2868] },
    /iPad Pro 13-inch/ => { type: :ipad, frame: 'ipad_pro_13', screen_size: [2064, 2752] },
    /Apple Watch Series 10 \(46mm\)/ => { type: :watch, frame: 'apple_watch_series_10_46mm', screen_size: [396, 484] }
  }.freeze

  def self.detect_device(filename)
    DEVICE_MAPPINGS.each do |pattern, config|
      return config.dup if filename.match?(pattern)
    end
    nil
  end

  def self.frame_metadata(frame_name)
    # Implementation
  end
end
```

**REFACTOR:** Extract constants, add documentation

---

#### Cycle 2: Single Screenshot Framing

**RED - Write failing test:**

```ruby
# spec/framing_helper_spec.rb

RSpec.describe FramingHelper do
  describe '.frame_screenshot' do
    let(:screenshot_path) { File.join(fixtures_dir, 'iphone_sample.png') }
    let(:output_path) { File.join(temp_dir, 'output_framed.png') }
    let(:device_spec) do
      {
        type: :iphone,
        frame: 'iphone_16_pro_max',
        screen_size: [1290, 2796]
      }
    end

    it 'creates framed output file' do
      FramingHelper.frame_screenshot(screenshot_path, output_path, device_spec)
      expect(File.exist?(output_path)).to be true
    end

    it 'framed image is larger than input' do
      FramingHelper.frame_screenshot(screenshot_path, output_path, device_spec)

      input_dims = get_image_dimensions(screenshot_path)
      output_dims = get_image_dimensions(output_path)

      expect(output_dims[:width]).to be > input_dims[:width]
      expect(output_dims[:height]).to be > input_dims[:height]
    end

    it 'applies correct background color' do
      FramingHelper.frame_screenshot(screenshot_path, output_path, device_spec, background: '#0E1117')

      # Check corner pixel is background color
      corner_color = get_pixel_color(output_path, 0, 0)
      expect(corner_color).to eq('#0E1117')
    end

    it 'raises error for missing screenshot' do
      expect {
        FramingHelper.frame_screenshot('nonexistent.png', output_path, device_spec)
      }.to raise_error(FramingHelper::ScreenshotNotFoundError)
    end

    it 'raises error for invalid dimensions' do
      wrong_size_path = File.join(fixtures_dir, 'wrong_size.png')
      expect {
        FramingHelper.frame_screenshot(wrong_size_path, output_path, device_spec)
      }.to raise_error(FramingHelper::DimensionMismatchError)
    end
  end

  # Helper methods
  def get_image_dimensions(path)
    output = `identify -format '%wx%h' #{Shellwords.escape(path)}`
    width, height = output.split('x').map(&:to_i)
    { width: width, height: height }
  end

  def get_pixel_color(path, x, y)
    `convert #{Shellwords.escape(path)} -format '%[pixel:p{#{x},#{y}}]' info:`
  end
end
```

**GREEN - Implement:**

```ruby
# lib/framing_helper.rb

require 'shellwords'
require 'fileutils'
require_relative 'device_frame_registry'

module FramingHelper
  class FramingError < StandardError; end
  class ScreenshotNotFoundError < FramingError; end
  class DimensionMismatchError < FramingError; end
  class FrameAssetMissingError < FramingError; end

  def self.frame_screenshot(screenshot_path, output_path, device_spec, options = {})
    validate_screenshot!(screenshot_path, device_spec)

    background = options[:background] || '#0E1117'
    metadata = DeviceFrameRegistry.frame_metadata(device_spec[:frame])
    frame_asset = resolve_frame_asset(device_spec[:frame], options[:variant])

    execute_composite(screenshot_path, output_path, metadata, frame_asset, background)
  end

  private

  def self.validate_screenshot!(path, device_spec)
    raise ScreenshotNotFoundError, "Screenshot not found: #{path}" unless File.exist?(path)

    dims = get_dimensions(path)
    expected = device_spec[:screen_size]

    unless dims == expected
      raise DimensionMismatchError, "Expected #{expected.join('x')}, got #{dims.join('x')}"
    end
  end

  def self.execute_composite(screenshot, output, metadata, frame_asset, background)
    # ImageMagick composite command
  end
end
```

---

#### Cycle 3: Batch Framing

**RED - Write failing test:**

```ruby
RSpec.describe FramingHelper do
  describe '.frame_all_screenshots' do
    let(:input_dir) { File.join(fixtures_dir, 'screenshots_normalized', 'en-US') }
    let(:output_dir) { File.join(temp_dir, 'framed', 'en-US') }

    before do
      # Create test screenshots
      FileUtils.mkdir_p(input_dir)
      create_test_screenshot(File.join(input_dir, 'iPhone 16 Pro Max-01_Welcome.png'), 1290, 2796)
      create_test_screenshot(File.join(input_dir, 'iPhone 16 Pro Max-02_MainScreen.png'), 1290, 2796)
    end

    it 'frames all screenshots in directory' do
      results = FramingHelper.frame_all_screenshots(input_dir, output_dir)

      expect(results[:processed]).to eq(2)
      expect(results[:errors]).to be_empty
      expect(Dir.glob(File.join(output_dir, '*_framed.png')).count).to eq(2)
    end

    it 'skips already framed screenshots' do
      # First pass
      FramingHelper.frame_all_screenshots(input_dir, output_dir)
      first_mtime = File.mtime(Dir.glob(File.join(output_dir, '*.png')).first)

      # Second pass (should skip)
      sleep(0.1)
      results = FramingHelper.frame_all_screenshots(input_dir, output_dir, skip_existing: true)
      second_mtime = File.mtime(Dir.glob(File.join(output_dir, '*.png')).first)

      expect(results[:skipped]).to eq(2)
      expect(first_mtime).to eq(second_mtime)
    end

    it 'handles errors gracefully and continues' do
      # Add a corrupted file
      File.write(File.join(input_dir, 'corrupted.png'), 'not a png')

      results = FramingHelper.frame_all_screenshots(input_dir, output_dir)

      expect(results[:processed]).to eq(2)
      expect(results[:errors].count).to eq(1)
    end

    it 'processes multiple locales' do
      # Create fi locale
      fi_input = File.join(fixtures_dir, 'screenshots_normalized', 'fi')
      FileUtils.mkdir_p(fi_input)
      create_test_screenshot(File.join(fi_input, 'iPhone 16 Pro Max-01_Welcome.png'), 1290, 2796)

      results = FramingHelper.frame_all_locales(
        File.join(fixtures_dir, 'screenshots_normalized'),
        File.join(temp_dir, 'framed'),
        locales: ['en-US', 'fi']
      )

      expect(results['en-US'][:processed]).to eq(2)
      expect(results['fi'][:processed]).to eq(1)
    end
  end
end
```

---

#### Cycle 4: Title Overlay

**RED - Write failing test:**

```ruby
RSpec.describe FramingHelper do
  describe '.add_text_overlay' do
    let(:framed_path) { File.join(fixtures_dir, 'framed_sample.png') }
    let(:output_path) { File.join(temp_dir, 'with_title.png') }

    it 'adds title text to image' do
      FramingHelper.add_text_overlay(
        framed_path,
        output_path,
        title: 'Organize Anything Instantly',
        subtitle: 'Start with smart list templates',
        locale: 'en-US'
      )

      # Verify image height increased (text area added)
      original_height = get_image_dimensions(framed_path)[:height]
      new_height = get_image_dimensions(output_path)[:height]

      expect(new_height).to be > original_height
    end

    it 'uses localized text from Framefile.json' do
      framefile = JSON.parse(File.read('fastlane/Framefile.json'))

      FramingHelper.add_text_overlay(
        framed_path,
        output_path,
        screenshot_name: '01_Welcome',
        locale: 'fi',
        framefile: framefile
      )

      # OCR verification (optional, requires tesseract)
      if system('which tesseract > /dev/null 2>&1')
        text = `tesseract #{output_path} - 2>/dev/null`
        expect(text).to include('Listat') # Finnish word
      end
    end

    it 'uses correct font' do
      font_path = 'fastlane/fonts/SF-Pro-Display-Semibold.ttf'
      expect(File.exist?(font_path)).to be true

      FramingHelper.add_text_overlay(
        framed_path,
        output_path,
        title: 'Test',
        font: font_path
      )

      expect(File.exist?(output_path)).to be true
    end
  end
end
```

---

#### Cycle 5: Fastlane Lane Integration

**RED - Write failing test:**

```ruby
# spec/fastlane_integration_spec.rb

RSpec.describe 'Fastlane Integration' do
  describe 'frame_screenshots lane' do
    it 'frames all device types' do
      # Simulate lane execution
      result = Fastlane::FastFile.new.parse("
        lane :test_framing do
          frame_screenshots(
            input_dir: 'spec/fixtures/screenshots_normalized',
            output_dir: 'spec/tmp/framed',
            devices: [:iphone, :ipad, :watch]
          )
        end
      ").runner.execute(:test_framing)

      expect(result[:success]).to be true
      expect(result[:iphone_count]).to eq(4)
      expect(result[:ipad_count]).to eq(4)
      expect(result[:watch_count]).to eq(10)
    end
  end
end
```

---

### 3.4 Test Fixtures Required

Create test fixtures in `fastlane/spec/fixtures/`:

```
spec/fixtures/
├── screenshots_normalized/
│   ├── en-US/
│   │   ├── iPhone 16 Pro Max-01_Welcome.png (1290x2796)
│   │   ├── iPhone 16 Pro Max-02_MainScreen.png (1290x2796)
│   │   ├── iPad Pro 13-inch (M4)-01_Welcome.png (2064x2752)
│   │   └── iPad Pro 13-inch (M4)-02_MainScreen.png (2064x2752)
│   └── fi/
│       └── ... (same structure)
├── watch_normalized/
│   ├── en-US/
│   │   └── Apple Watch Series 10 (46mm)-01_Watch.png (396x484)
│   └── fi/
├── device_frames/
│   ├── iphone_16_pro_max_black.png
│   ├── ipad_pro_13_black.png
│   └── watch_series_10_black.png
└── framed_sample.png (pre-framed for overlay tests)
```

**Fixture Generation Script:**

```ruby
# spec/support/fixture_generator.rb

def create_test_screenshot(path, width, height, color = '#FFFFFF')
  FileUtils.mkdir_p(File.dirname(path))
  system("magick -size #{width}x#{height} xc:#{color} #{Shellwords.escape(path)}")
end

def create_test_frame(path, width, height)
  FileUtils.mkdir_p(File.dirname(path))
  # Create transparent PNG with device shape
  system("magick -size #{width}x#{height} xc:none -fill '#333333' -draw 'roundrectangle 0,0,#{width},#{height},50,50' #{Shellwords.escape(path)}")
end
```

---

### 3.5 TDD Execution Order

| Phase | Test File | Implementation File | Priority |
|-------|-----------|---------------------|----------|
| 1 | `device_frame_registry_spec.rb` | `device_frame_registry.rb` | HIGH |
| 2 | `framing_helper_spec.rb` (single) | `framing_helper.rb` (core) | HIGH |
| 3 | `framing_helper_spec.rb` (batch) | `framing_helper.rb` (batch) | HIGH |
| 4 | `framing_helper_spec.rb` (overlay) | `framing_helper.rb` (text) | MEDIUM |
| 5 | `fastlane_integration_spec.rb` | `Fastfile` lanes | MEDIUM |
| 6 | `validation_spec.rb` | Validation scripts | LOW |

### 3.6 Running Tests

```bash
# Run all framing tests
cd fastlane && bundle exec rspec spec/framing_helper_spec.rb spec/device_frame_registry_spec.rb

# Run with coverage
cd fastlane && bundle exec rspec --format documentation --color

# Run single test
cd fastlane && bundle exec rspec spec/framing_helper_spec.rb:42

# Watch mode (requires guard)
cd fastlane && bundle exec guard
```

---

## 4. Asset Requirements

### 4.1 Device Frames Inventory

| Device | Raw Size | Frame Size | Frame Asset |
|--------|----------|------------|-------------|
| iPhone 16 Pro Max | 1290x2796 | ~1460x3106 | `iphone_16_pro_max_black.png` |
| iPad Pro 13" M4 | 2064x2752 | ~2200x3000 | `ipad_pro_13_black.png` |
| Apple Watch S10 46mm | 396x484 | ~500x600 | `watch_series_10_black.png` |

### 4.2 Frame Sources

**Option A: Apple Design Resources (RECOMMENDED)**
- URL: https://developer.apple.com/design/resources/
- License: Free with Apple Developer Program
- Formats: PSD, PNG, Sketch
- Quality: Official, highest quality

**Option B: MockUPhone (MVP)**
- URL: https://mockuphone.com/
- License: Free for commercial use
- Quality: Good, quick to obtain

**Option C: Custom Creation**
- Tool: Figma/Sketch
- Effort: High
- Flexibility: Maximum

### 4.3 Frame Asset Acquisition Steps

1. Download from Apple Design Resources
2. Open in Photoshop/Figma
3. Export device layer as PNG with transparency
4. Measure screen area coordinates
5. Create metadata.json with measurements
6. Store in `fastlane/device_frames/`

### 4.4 Storage Strategy

```bash
# Add to .gitattributes
fastlane/device_frames/*.png filter=lfs diff=lfs merge=lfs -text

# Or store externally and download at build time
curl -o fastlane/device_frames/iphone.png $FRAME_CDN_URL
```

---

## 5. Script Implementation

### 5.1 Core Module: framing_helper.rb

**Location:** `/Users/aleksi/source/ListAllApp/fastlane/lib/framing_helper.rb`

```ruby
# frozen_string_literal: true

require 'shellwords'
require 'fileutils'
require 'json'
require_relative 'device_frame_registry'

module FramingHelper
  class FramingError < StandardError; end
  class ScreenshotNotFoundError < FramingError; end
  class DimensionMismatchError < FramingError; end
  class FrameAssetMissingError < FramingError; end
  class ImageMagickError < FramingError; end

  DEFAULT_OPTIONS = {
    background: '#0E1117',
    padding: 40,
    variant: :black,
    add_titles: true,
    skip_existing: false
  }.freeze

  # Frame a single screenshot
  def self.frame_screenshot(screenshot_path, output_path, device_spec, options = {})
    options = DEFAULT_OPTIONS.merge(options)

    validate_screenshot!(screenshot_path, device_spec)
    validate_frame_asset!(device_spec[:frame], options[:variant])

    metadata = DeviceFrameRegistry.frame_metadata(device_spec[:frame])
    frame_asset = resolve_frame_asset(device_spec[:frame], options[:variant])

    FileUtils.mkdir_p(File.dirname(output_path))
    execute_composite(screenshot_path, output_path, metadata, frame_asset, options)

    verify_output!(output_path)
  end

  # Frame all screenshots in a directory
  def self.frame_all_screenshots(input_dir, output_dir, options = {})
    options = DEFAULT_OPTIONS.merge(options)
    results = { processed: 0, skipped: 0, errors: [] }

    Dir.glob(File.join(input_dir, '*.png')).each do |screenshot|
      next if File.basename(screenshot).include?('_framed')

      begin
        output_name = File.basename(screenshot, '.png') + '_framed.png'
        output_path = File.join(output_dir, output_name)

        if options[:skip_existing] && File.exist?(output_path)
          results[:skipped] += 1
          next
        end

        device_spec = DeviceFrameRegistry.detect_device(File.basename(screenshot))
        next unless device_spec

        frame_screenshot(screenshot, output_path, device_spec, options)
        results[:processed] += 1
      rescue FramingError => e
        results[:errors] << { file: screenshot, error: e.message }
      end
    end

    results
  end

  # Frame all locales
  def self.frame_all_locales(input_root, output_root, options = {})
    locales = options[:locales] || ['en-US', 'fi']
    results = {}

    locales.each do |locale|
      input_dir = File.join(input_root, locale)
      output_dir = File.join(output_root, locale)

      results[locale] = frame_all_screenshots(input_dir, output_dir, options)
    end

    results
  end

  private

  def self.validate_screenshot!(path, device_spec)
    raise ScreenshotNotFoundError, "Screenshot not found: #{path}" unless File.exist?(path)

    dims = get_dimensions(path)
    expected = device_spec[:screen_size]

    unless dims == expected
      raise DimensionMismatchError,
            "Screenshot #{path} has wrong dimensions. Expected #{expected.join('x')}, got #{dims.join('x')}"
    end
  end

  def self.validate_frame_asset!(frame_name, variant)
    asset_path = resolve_frame_asset(frame_name, variant)
    raise FrameAssetMissingError, "Frame asset not found: #{asset_path}" unless File.exist?(asset_path)
  end

  def self.resolve_frame_asset(frame_name, variant)
    File.expand_path("../device_frames/#{frame_name}_#{variant}.png", __dir__)
  end

  def self.get_dimensions(path)
    output = `identify -format '%wx%h' #{Shellwords.escape(path)} 2>/dev/null`.strip
    output.split('x').map(&:to_i)
  end

  def self.execute_composite(screenshot, output, metadata, frame_asset, options)
    screen_x = metadata[:screen_area][:x]
    screen_y = metadata[:screen_area][:y]

    cmd = build_imagemagick_command(screenshot, output, frame_asset, screen_x, screen_y, options)

    success = system(cmd)
    raise ImageMagickError, "ImageMagick composite failed for #{screenshot}" unless success
  end

  def self.build_imagemagick_command(screenshot, output, frame_asset, x, y, options)
    <<~CMD.gsub("\n", ' ')
      magick #{Shellwords.escape(frame_asset)}
      #{Shellwords.escape(screenshot)}
      -geometry +#{x}+#{y}
      -composite
      -background '#{options[:background]}'
      -gravity center
      -extent #{options[:canvas_width] || 1600}x#{options[:canvas_height] || 3200}
      -quality 95
      #{Shellwords.escape(output)}
    CMD
  end

  def self.verify_output!(path)
    raise FramingError, "Output file not created: #{path}" unless File.exist?(path)

    size = File.size(path)
    raise FramingError, "Output file too small (#{size} bytes): #{path}" if size < 1000
  end
end
```

### 5.2 Device Frame Registry

**Location:** `/Users/aleksi/source/ListAllApp/fastlane/lib/device_frame_registry.rb`

```ruby
# frozen_string_literal: true

require 'json'

module DeviceFrameRegistry
  class FrameNotFoundError < StandardError; end

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

  def self.detect_device(filename)
    DEVICE_MAPPINGS.each do |pattern, config|
      return config.dup if filename.match?(pattern)
    end
    nil
  end

  def self.frame_metadata(frame_name)
    metadata_path = metadata_path_for(frame_name)

    raise FrameNotFoundError, "Metadata not found for frame: #{frame_name}" unless File.exist?(metadata_path)

    JSON.parse(File.read(metadata_path), symbolize_names: true)
  end

  def self.metadata_path_for(frame_name)
    device_type = frame_name.split('_').first # iphone, ipad, watch
    File.expand_path("../device_frames/#{device_type}/metadata.json", __dir__)
  end

  def self.available_frames
    Dir.glob(File.expand_path('../device_frames/*/metadata.json', __dir__)).map do |path|
      JSON.parse(File.read(path), symbolize_names: true)[:device]
    end
  end
end
```

### 5.3 Fastlane Lane

**Add to:** `/Users/aleksi/source/ListAllApp/fastlane/Fastfile`

```ruby
desc "Frame all normalized screenshots with custom device frames (TDD implementation)"
lane :frame_screenshots_custom do |options|
  require_relative 'lib/framing_helper'

  UI.header("Framing Screenshots with Custom Device Frames")

  # Validate dependencies
  unless system('which magick > /dev/null 2>&1')
    UI.user_error!("ImageMagick not found. Install with: brew install imagemagick")
  end

  # Configuration
  input_root = File.expand_path('screenshots_compat', __dir__)
  watch_input = File.expand_path('screenshots/watch_normalized', __dir__)
  output_root = File.expand_path('screenshots_framed', __dir__)

  locales = options[:locales] || ['en-US', 'fi']
  devices = options[:devices] || [:iphone, :ipad, :watch]

  # Clean output directory
  FileUtils.rm_rf(output_root) unless options[:incremental]

  total_results = { processed: 0, skipped: 0, errors: [] }

  # Frame iPhone/iPad screenshots
  if (devices & [:iphone, :ipad]).any?
    UI.message("Framing iPhone/iPad screenshots...")

    results = FramingHelper.frame_all_locales(
      input_root,
      File.join(output_root, 'ios'),
      locales: locales,
      add_titles: options.fetch(:add_titles, true),
      skip_existing: options.fetch(:skip_existing, false)
    )

    results.each do |locale, r|
      total_results[:processed] += r[:processed]
      total_results[:skipped] += r[:skipped]
      total_results[:errors] += r[:errors]
      UI.message("  #{locale}: #{r[:processed]} framed, #{r[:skipped]} skipped")
    end
  end

  # Frame Watch screenshots
  if devices.include?(:watch)
    UI.message("Framing Apple Watch screenshots...")

    results = FramingHelper.frame_all_locales(
      watch_input,
      File.join(output_root, 'watch'),
      locales: locales,
      add_titles: options.fetch(:add_titles, true),
      skip_existing: options.fetch(:skip_existing, false)
    )

    results.each do |locale, r|
      total_results[:processed] += r[:processed]
      total_results[:skipped] += r[:skipped]
      total_results[:errors] += r[:errors]
      UI.message("  Watch #{locale}: #{r[:processed]} framed")
    end
  end

  # Report results
  if total_results[:errors].any?
    UI.important("Completed with #{total_results[:errors].count} error(s):")
    total_results[:errors].each { |e| UI.error("  #{e[:file]}: #{e[:error]}") }
  end

  UI.success("Framed #{total_results[:processed]} screenshots (#{total_results[:skipped]} skipped)")

  total_results
end

desc "Run framing tests"
lane :test_framing do
  sh("cd #{__dir__} && bundle exec rspec spec/framing_helper_spec.rb spec/device_frame_registry_spec.rb --format documentation")
end
```

---

## 6. Validation & Testing

### 6.1 Automated Validation Suite

**File:** `/Users/aleksi/source/ListAllApp/.github/scripts/validate-framed-screenshots.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FRAMED_DIR="${PROJECT_ROOT}/fastlane/screenshots_framed"

ERRORS=0

echo "=== Framed Screenshot Validation ==="

# 1. Check completeness
echo "Checking screenshot completeness..."
for locale in en-US fi; do
    IPHONE_COUNT=$(find "${FRAMED_DIR}/ios/${locale}" -name "iPhone*_framed.png" 2>/dev/null | wc -l | xargs)
    IPAD_COUNT=$(find "${FRAMED_DIR}/ios/${locale}" -name "iPad*_framed.png" 2>/dev/null | wc -l | xargs)
    WATCH_COUNT=$(find "${FRAMED_DIR}/watch/${locale}" -name "*_framed.png" 2>/dev/null | wc -l | xargs)

    echo "  ${locale}: iPhone=${IPHONE_COUNT}, iPad=${IPAD_COUNT}, Watch=${WATCH_COUNT}"

    [[ "${IPHONE_COUNT}" -lt 2 ]] && echo "    ERROR: Expected 2 iPhone screenshots" && ((ERRORS++))
    [[ "${IPAD_COUNT}" -lt 2 ]] && echo "    ERROR: Expected 2 iPad screenshots" && ((ERRORS++))
    [[ "${WATCH_COUNT}" -lt 5 ]] && echo "    ERROR: Expected 5 Watch screenshots" && ((ERRORS++))
done

# 2. Validate dimensions
echo "Validating dimensions..."
for framed in "${FRAMED_DIR}"/*/*/*.png; do
    [[ -f "${framed}" ]] || continue

    DIMS=$(identify -format '%wx%h' "${framed}")
    WIDTH=$(echo "${DIMS}" | cut -d'x' -f1)
    HEIGHT=$(echo "${DIMS}" | cut -d'x' -f2)

    # Framed images should be larger than raw
    if [[ "${WIDTH}" -lt 1000 ]] || [[ "${HEIGHT}" -lt 1000 ]]; then
        echo "  ERROR: ${framed} too small (${DIMS})"
        ((ERRORS++))
    fi
done

# 3. Check file sizes
echo "Checking file sizes..."
for framed in "${FRAMED_DIR}"/*/*/*.png; do
    [[ -f "${framed}" ]] || continue

    SIZE_KB=$(du -k "${framed}" | cut -f1)
    if [[ "${SIZE_KB}" -gt 2000 ]]; then
        echo "  WARNING: ${framed} is ${SIZE_KB}KB (consider compression)"
    fi
done

# 4. Verify image integrity
echo "Verifying image integrity..."
for framed in "${FRAMED_DIR}"/*/*/*.png; do
    [[ -f "${framed}" ]] || continue

    if ! identify -regard-warnings "${framed}" &>/dev/null; then
        echo "  ERROR: Corrupted image: ${framed}"
        ((ERRORS++))
    fi
done

# Summary
echo ""
if [[ "${ERRORS}" -eq 0 ]]; then
    echo "All ${ERRORS} validations passed"
    exit 0
else
    echo "FAILED: ${ERRORS} error(s) found"
    exit 1
fi
```

### 6.2 CI/CD Integration

**Add to:** `.github/workflows/screenshots.yml`

```yaml
  validate-framed:
    name: Validate Framed Screenshots
    needs: [generate-framed]
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Download framed artifacts
        uses: actions/download-artifact@v4
        with:
          name: screenshots-framed
          path: fastlane/screenshots_framed/

      - name: Run validation
        run: bash .github/scripts/validate-framed-screenshots.sh

      - name: Run RSpec tests
        run: |
          cd fastlane
          bundle exec rspec spec/framing_helper_spec.rb --format documentation
```

### 6.3 Quality Acceptance Criteria

| Criterion | Requirement | Validation |
|-----------|-------------|------------|
| Completeness | 18 framed screenshots (8 iOS + 10 Watch) × 2 locales | Count check |
| Dimensions | Framed > Raw (bezel adds pixels) | Dimension comparison |
| File Size | < 2MB per file | du -k check |
| Integrity | Valid PNG structure | identify check |
| Color Space | sRGB | identify -verbose |
| Content | Screenshot visible within frame | Visual inspection |

---

## 7. Integration Points

### 7.1 Existing Fastlane Lanes

| Lane | Purpose | Integration |
|------|---------|-------------|
| `screenshots_iphone` | Capture iPhone screenshots | Input source |
| `screenshots_ipad` | Capture iPad screenshots | Input source |
| `watch_screenshots` | Capture Watch screenshots | Input source |
| `normalize_all_screenshots` | Resize to ASC dimensions | Pre-requisite |
| `screenshots_framed` | **NEW:** Custom framing | This implementation |
| `prepare_screenshots_for_delivery` | Upload to ASC | Consumer |

### 7.2 Integration with Existing Pipeline

```ruby
# Complete screenshot workflow
lane :screenshots_complete do |options|
  # 1. Capture
  screenshots_iphone
  screenshots_ipad
  watch_screenshots

  # 2. Normalize (for App Store)
  normalize_all_screenshots

  # 3. Validate raw
  validate_all_screenshots

  # 4. Frame (for marketing) - NEW
  unless options[:skip_framing]
    frame_screenshots_custom(
      add_titles: options.fetch(:add_titles, true)
    )
  end

  # 5. Validate framed
  unless options[:skip_framing]
    sh("bash .github/scripts/validate-framed-screenshots.sh")
  end
end
```

### 7.3 Local Development Script

**Update:** `.github/scripts/generate-screenshots-local.sh`

```bash
# Add framing mode
MODE="${1:-all}"  # all, iphone, ipad, watch, framed

case "${MODE}" in
  framed)
    echo "Generating framed screenshots only..."
    bundle exec fastlane ios frame_screenshots_custom
    ;;
  all)
    echo "Running complete pipeline with framing..."
    bundle exec fastlane ios screenshots_complete
    ;;
  *)
    echo "Running ${MODE} screenshots..."
    bundle exec fastlane ios screenshots_${MODE}
    ;;
esac
```

---

## 8. Rollout Plan

### Phase 1: Foundation (Week 1)

- [ ] Create test infrastructure (`spec/` directory)
- [ ] Write failing tests for DeviceFrameRegistry
- [ ] Implement DeviceFrameRegistry (pass tests)
- [ ] Acquire minimal device frame assets (iPhone black only)
- [ ] Write failing tests for single screenshot framing
- [ ] Implement basic framing (pass tests)

**Deliverables:**
- `fastlane/lib/device_frame_registry.rb`
- `fastlane/lib/framing_helper.rb` (basic)
- `fastlane/spec/device_frame_registry_spec.rb`
- `fastlane/spec/framing_helper_spec.rb`
- `fastlane/device_frames/iphone/`

### Phase 2: Batch Processing (Week 2)

- [ ] Write failing tests for batch framing
- [ ] Implement batch framing (pass tests)
- [ ] Write failing tests for locale handling
- [ ] Implement locale support (pass tests)
- [ ] Add iPad and Watch frame assets

**Deliverables:**
- Extended `framing_helper.rb` with batch methods
- `fastlane/device_frames/ipad/`
- `fastlane/device_frames/watch/`

### Phase 3: Integration (Week 3)

- [ ] Write failing tests for Fastlane integration
- [ ] Add `frame_screenshots_custom` lane
- [ ] Write failing tests for title overlay
- [ ] Implement title overlay (pass tests)
- [ ] Update local generation script

**Deliverables:**
- Updated `Fastfile` with new lane
- Title/subtitle rendering
- Updated `.github/scripts/generate-screenshots-local.sh`

### Phase 4: Validation & Polish (Week 4)

- [ ] Create validation script
- [ ] Add CI/CD workflow job
- [ ] Run full integration test
- [ ] Visual QA review
- [ ] Documentation

**Deliverables:**
- `.github/scripts/validate-framed-screenshots.sh`
- Updated workflows
- This documentation finalized

---

## Appendix A: File Paths Reference

### New Files to Create

| File | Purpose |
|------|---------|
| `fastlane/lib/framing_helper.rb` | Core framing logic |
| `fastlane/lib/device_frame_registry.rb` | Device detection/metadata |
| `fastlane/spec/framing_helper_spec.rb` | TDD tests |
| `fastlane/spec/device_frame_registry_spec.rb` | TDD tests |
| `fastlane/device_frames/iphone/metadata.json` | iPhone frame specs |
| `fastlane/device_frames/iphone/iphone_16_pro_max_black.png` | iPhone frame asset |
| `fastlane/device_frames/ipad/metadata.json` | iPad frame specs |
| `fastlane/device_frames/ipad/ipad_pro_13_m4_black.png` | iPad frame asset |
| `fastlane/device_frames/watch/metadata.json` | Watch frame specs |
| `fastlane/device_frames/watch/apple_watch_series_10_black.png` | Watch frame asset |
| `.github/scripts/validate-framed-screenshots.sh` | Validation script |

### Existing Files to Modify

| File | Change |
|------|--------|
| `fastlane/Fastfile` | Add `frame_screenshots_custom` lane |
| `.github/scripts/generate-screenshots-local.sh` | Add `framed` mode |
| `.gitignore` | Add `fastlane/screenshots_framed/` |

---

## Appendix B: Dependencies

### Required

- **ImageMagick 7.x:** `brew install imagemagick`
- **Ruby 3.2+:** Already installed for Fastlane
- **RSpec:** `gem install rspec` (for TDD)

### Optional

- **Git LFS:** For storing large frame assets
- **Tesseract:** For OCR validation of titles

### Verification Commands

```bash
# Check ImageMagick
magick --version

# Check Ruby
ruby --version

# Check RSpec
bundle exec rspec --version
```

---

## Appendix C: Quick Reference Commands

```bash
# Run TDD tests
cd fastlane && bundle exec rspec spec/

# Frame all screenshots
bundle exec fastlane ios frame_screenshots_custom

# Frame with specific options
bundle exec fastlane ios frame_screenshots_custom add_titles:false skip_existing:true

# Validate framed screenshots
bash .github/scripts/validate-framed-screenshots.sh

# Complete pipeline
bundle exec fastlane ios screenshots_complete

# Local framing only
.github/scripts/generate-screenshots-local.sh framed
```

---

**Document Version:** 1.0
**Last Updated:** 2025-11-28
**Author:** Claude Code (6-agent swarm)
