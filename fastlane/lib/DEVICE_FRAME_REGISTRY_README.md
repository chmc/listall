# DeviceFrameRegistry Implementation

**Status:** ✅ COMPLETE - Phase 1 (TDD Foundation)
**Branch:** feature/framed-screenshots
**Date:** 2025-11-28

## What Was Implemented

This implementation provides the foundational module for the custom screenshot framing solution, replacing Fastlane Frameit with full support for all Apple device types.

### Files Created

1. **`/Users/aleksi/source/ListAllApp/fastlane/lib/device_frame_registry.rb`**
   - Core registry module with device detection and metadata loading
   - DEVICE_MAPPINGS constant for pattern-based device detection
   - Methods: `detect_device()`, `frame_metadata()`, `available_frames()`
   - Custom exception: `FrameNotFoundError`
   - Full RDoc documentation

2. **Device Frame Directory Structure**
   ```
   fastlane/device_frames/
   ├── README.md                                 # Documentation
   ├── iphone/
   │   ├── metadata.json                         # iPhone 16 Pro Max specs
   │   └── iphone_16_pro_max_black.png          # Placeholder (0 bytes)
   ├── ipad/
   │   ├── metadata.json                         # iPad Pro 13" M4 specs
   │   └── ipad_pro_13_m4_black.png             # Placeholder (0 bytes)
   └── watch/
       ├── metadata.json                         # Apple Watch S10 specs
       └── apple_watch_series_10_46mm_black.png # Placeholder (0 bytes)
   ```

3. **`/Users/aleksi/source/ListAllApp/fastlane/lib/test_device_frame_registry.rb`**
   - Standalone verification script (no RSpec dependency)
   - Tests all major functionality
   - Can be run with: `ruby -I lib lib/test_device_frame_registry.rb`

4. **Updated `.gitignore`**
   - Added exclusion for device frame PNG files
   - Metadata JSON files are tracked in git
   - Frame assets must be acquired separately

## Verification Results

All tests passing:

```
=== DeviceFrameRegistry Verification ===

Test 1: Device Detection
--------------------------------------------------
✓ iPhone 16 Pro Max-01_Welcome.png
✓ iPad Pro 13-inch (M4)-02_MainScreen.png
✓ Apple Watch Series 10 (46mm)-01_Watch.png
✗ Unknown Device-03_Test.png (expected - returns nil)

Test 2: Metadata Loading
--------------------------------------------------
✓ iphone_16_pro_max
✓ ipad_pro_13_m4
✓ apple_watch_series_10_46mm

Test 3: Error Handling
--------------------------------------------------
✓ FrameNotFoundError raised correctly

Test 4: Available Frames
--------------------------------------------------
✓ Found 3 available frame(s)
```

## Device Specifications

### iPhone 16 Pro Max
- **Screen Size**: 1290 x 2796 pixels
- **Frame Size**: 1460 x 3106 pixels
- **Screen Offset**: (85, 155)
- **Variants**: black, white, natural_titanium
- **Corner Radius**: 55px

### iPad Pro 13-inch M4
- **Screen Size**: 2064 x 2752 pixels
- **Frame Size**: 2254 x 2942 pixels
- **Screen Offset**: (95, 95)
- **Variants**: black, silver
- **Corner Radius**: 25px

### Apple Watch Series 10 46mm
- **Screen Size**: 396 x 484 pixels
- **Frame Size**: 500 x 640 pixels
- **Screen Offset**: (52, 78)
- **Variants**: black, silver, natural_titanium
- **Corner Radius**: 45px

## Module Usage Examples

### Detect Device from Filename

```ruby
require_relative 'lib/device_frame_registry'

# Detect device type
spec = DeviceFrameRegistry.detect_device('iPhone 16 Pro Max-01_Welcome.png')
# => { type: :iphone, frame: 'iphone_16_pro_max', screen_size: [1290, 2796] }

# Unknown device returns nil
spec = DeviceFrameRegistry.detect_device('Unknown-Test.png')
# => nil
```

### Load Frame Metadata

```ruby
# Load metadata for a frame
metadata = DeviceFrameRegistry.frame_metadata('iphone_16_pro_max')

# Access metadata fields
puts metadata[:device]                    # "iPhone 16 Pro Max"
puts metadata[:screen_area][:width]       # 1290
puts metadata[:screen_area][:height]      # 2796
puts metadata[:screen_area][:x]           # 85
puts metadata[:screen_area][:y]           # 155
puts metadata[:frame_dimensions][:width]  # 1460
puts metadata[:frame_dimensions][:height] # 3106
puts metadata[:default_variant]           # "black"
puts metadata[:variants][:black]          # "iphone_16_pro_max_black.png"
```

### List Available Frames

```ruby
frames = DeviceFrameRegistry.available_frames
# => ["iPhone 16 Pro Max", "iPad Pro 13-inch M4", "Apple Watch Series 10 46mm"]
```

### Error Handling

```ruby
begin
  DeviceFrameRegistry.frame_metadata('nonexistent')
rescue DeviceFrameRegistry::FrameNotFoundError => e
  puts "Frame not found: #{e.message}"
end
```

## Implementation Details

### Pattern Matching

The module uses regex patterns to detect device types from filenames. This matches the naming convention used by Fastlane Snapshot:

- `iPhone 16 Pro Max-01_Welcome.png` → iPhone
- `iPad Pro 13-inch (M4)-02_Main.png` → iPad
- `Apple Watch Series 10 (46mm)-01_Watch.png` → Watch

### Metadata Path Resolution

The module includes special handling for Apple Watch:
- Frame name: `apple_watch_series_10_46mm`
- Resolves to directory: `device_frames/watch/`
- This is handled by the private `metadata_path_for()` method

### Ruby Best Practices

- ✅ `frozen_string_literal: true` for performance
- ✅ Comprehensive RDoc documentation
- ✅ Defensive error handling
- ✅ Private methods appropriately marked
- ✅ Symbolized hash keys for consistency
- ✅ Immutable constants (FREEZE)

## Next Steps (Phase 2)

Following the TDD plan from `documentation/todo.framed_screenshots.md`:

1. **Add RSpec to Gemfile** (optional for CI)
   ```ruby
   group :test do
     gem 'rspec', '~> 3.12'
   end
   ```

2. **Acquire Device Frame Assets**
   - Download from [Apple Design Resources](https://developer.apple.com/design/resources/)
   - Replace placeholder PNG files in `device_frames/*/`
   - Verify dimensions match metadata specifications

3. **Implement FramingHelper Module**
   - `frame_screenshot()` - Single screenshot framing
   - `frame_all_screenshots()` - Batch processing
   - `frame_all_locales()` - Multi-language support
   - ImageMagick composite operations

4. **Add Fastlane Lane**
   - `frame_screenshots_custom` lane in Fastfile
   - Integration with existing screenshot pipeline

## Testing

### Manual Testing

```bash
# Run standalone verification
cd fastlane
ruby -I lib lib/test_device_frame_registry.rb
```

### RSpec Testing (when available)

```bash
# Install RSpec
bundle add rspec --group test

# Run tests
cd fastlane
bundle exec rspec spec/device_frame_registry_spec.rb --format documentation
```

Note: RSpec tests in `spec/device_frame_registry_spec.rb` are currently skipped (TDD Red phase). Remove `skip` statements to enable after adding RSpec to Gemfile.

## Dependencies

- **Ruby**: 3.2+ (already available)
- **JSON**: Standard library
- **FileUtils**: Standard library
- **No external gems required** for this module

## License & Attribution

Device frame assets are subject to:
- Apple Design Resources License Agreement
- Apple Marketing Guidelines
- Must be acquired separately from Apple

## See Also

- Main implementation plan: `/Users/aleksi/source/ListAllApp/documentation/todo.framed_screenshots.md`
- Device frames README: `/Users/aleksi/source/ListAllApp/fastlane/device_frames/README.md`
- Next module: `/Users/aleksi/source/ListAllApp/fastlane/lib/framing_helper.rb` (to be implemented)
