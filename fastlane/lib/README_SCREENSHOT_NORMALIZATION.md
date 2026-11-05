# Screenshot Normalization & Validation

Comprehensive system for normalizing and validating iOS, iPadOS, and watchOS screenshots to meet Apple App Store Connect requirements.

## Overview

This system automatically:
- **Normalizes** screenshots from any simulator size to official App Store Connect dimensions
- **Validates** that screenshots match Apple's exact requirements
- **Auto-detects** device types (iPhone, iPad, Watch) from filenames
- **Provides CI/CD integration** with clear pass/fail signals

## Apple App Store Connect Requirements

### iPhone Screenshots
| Size | Dimensions | Devices |
|------|------------|---------|
| 6.7" | 1290x2796 | iPhone 14/15/16 Pro Max ← **Default** |
| 6.5" | 1242x2688 | iPhone XS Max, 11 Pro Max |
| 6.1" | 1179x2556 | iPhone 14/15/16 Pro |
| 5.8" | 1170x2532 | iPhone X, XS, 11 Pro |
| 5.5" | 1242x2208 | iPhone 6/7/8 Plus |

### iPad Screenshots
| Size | Dimensions | Devices |
|------|------------|---------|
| 13" | 2064x2752 | iPad 13" (M4 Pro/Air) ← **Default (2024)** |
| 12.9" | 2048x2732 | iPad Pro 12.9" (3rd gen+, legacy) |
| 11" | 1668x2388 | iPad Pro 11" |

### Apple Watch Screenshots
| Size | Dimensions | Watch Model |
|------|------------|-------------|
| 49mm | 410x502 | Apple Watch Ultra |
| **45mm** | **396x484** | **Apple Watch Series 7+** ← **Default** |
| 40mm | 368x448 | Apple Watch Series 4-6 |

## Quick Start

### Normalize All Screenshots
```bash
# Normalize iPhone, iPad, and Watch screenshots to App Store requirements
bundle exec fastlane ios normalize_all_screenshots
```

This reads from:
- `fastlane/screenshots/` (iPhone + iPad)
- `fastlane/screenshots/watch/` (Watch)

And outputs to:
- `fastlane/screenshots_normalized/` (iPhone + iPad)
- `fastlane/screenshots/watch_normalized/` (Watch)

### Validate All Screenshots
```bash
# Validate all normalized screenshots against App Store requirements
bundle exec fastlane ios validate_all_screenshots
```

✅ **Passes**: All screenshots match App Store dimensions  
❌ **Fails**: Any screenshot has wrong dimensions (CI fails)

## Directory Structure

```
fastlane/
├── lib/
│   ├── screenshot_helper.rb           # Unified helper (iPhone/iPad/Watch)
│   └── watch_screenshot_helper.rb     # Watch-specific (legacy, still used)
├── screenshots/                        # Raw captures (iPhone/iPad)
│   ├── en-US/
│   │   ├── iPhone 17 Pro Max-*.png   # 1320x2868 (raw)
│   │   └── iPad Pro 13-inch-*.png    # 2064x2752 (raw)
│   ├── fi/
│   └── watch/                          # Raw watch captures
│       ├── en-US/                     # 416x496 (raw)
│       └── fi/
├── screenshots_normalized/             # Normalized (iPhone/iPad)
│   ├── en-US/
│   │   ├── iPhone 17 Pro Max-*.png   # 1290x2796 ← App Store ready
│   │   └── iPad Pro 13-inch-*.png    # 2064x2752 ← App Store ready
│   └── fi/
└── screenshots/watch_normalized/       # Normalized (Watch)
    ├── en-US/                         # 396x484 ← App Store ready
    └── fi/
```

## Implementation Details

### Normalization Strategy

**ImageMagick Command**:
```bash
convert input.png \
  -resize WxH^ \
  -gravity center \
  -extent WxH \
  -quality 100 \
  output.png
```

- **Resize**: `-resize WxH^` fills the target dimensions (maintains aspect ratio)
- **Crop**: `-gravity center -extent WxH` centers and crops to exact size
- **Quality**: `-quality 100` preserves maximum quality

### Device Type Auto-Detection

The system detects device types from filenames:
- Contains `iPhone` → iPhone screenshots
- Contains `iPad` → iPad screenshots  
- Contains `Watch` → Watch screenshots

### Validation Logic

1. **Exact dimension match**: Width and height must match official App Store sizes exactly
2. **File naming**: Flexible pattern support (preserves Fastlane Snapshot prefixes)
3. **Size sanity checks**: Minimum dimensions enforced per platform
4. **File size warnings**: Flags files >2MB (non-fatal)

## Fastlane Lanes

### `normalize_all_screenshots`
Normalizes all screenshots (iPhone, iPad, Watch) to App Store dimensions.

**What it does**:
1. Scans `fastlane/screenshots/` for iPhone/iPad
2. Scans `fastlane/screenshots/watch/` for Watch
3. Auto-detects device types from filenames
4. Normalizes to appropriate target dimensions
5. Outputs to `screenshots_normalized/` directories

**Example output**:
```
🔄 en-US/iPhone 17 Pro Max-01-WelcomeScreen.png: 1320x2868 → 1290x2796
✅ en-US/iPad Pro 13-inch (M5)-01-WelcomeScreen.png: Already 2064x2752, copying...
🔄 en-US/Apple Watch Series 11-01_Watch_Lists_Home.png: 416x496 → 396x484

======================================================================
Screenshot Normalization Summary
======================================================================
iPhone: 10 screenshots normalized to 1290x2796
iPad: 10 screenshots normalized to 2064x2752 (13" standard)
Watch: 10 screenshots normalized to 396x484
Total: 30 screenshots
```

### `validate_all_screenshots`
Validates all normalized screenshots against App Store requirements.

**What it does**:
1. Checks `fastlane/screenshots_normalized/` for iPhone/iPad
2. Checks `fastlane/screenshots/watch_normalized/` for Watch
3. Validates exact dimensions against official sizes
4. Provides detailed breakdown by device type
5. **Fails CI** if any screenshot is invalid

**Example output**:
```
✅ en-US/iPhone 17 Pro Max-01-WelcomeScreen.png: 1290x2796 (iPhone 6.7")
✅ en-US/iPad Pro 13-inch (M5)-01-WelcomeScreen.png: 2064x2752 (iPad 13")
✅ en-US/Apple Watch Series 11-01_Watch_Lists_Home.png: 396x484 (Apple Watch Series 7+ 45mm)

======================================================================
Screenshot Validation Summary
======================================================================
Device breakdown:
  iPhone: 10 screenshots
  iPad: 10 screenshots
  Watch: 10 screenshots
  Total valid: 30

✅ ALL screenshots validated successfully!
```

## CI/CD Integration

### In GitHub Actions

```yaml
- name: Normalize Screenshots
  run: bundle exec fastlane ios normalize_all_screenshots

- name: Validate Screenshots
  run: bundle exec fastlane ios validate_all_screenshots
  # ↑ This step will FAIL if any screenshot is invalid
```

### Exit Codes

- **0**: All screenshots valid ✅
- **Non-zero**: Validation failed ❌ (CI build fails)

## Advanced Usage

### Programmatic Access

```ruby
require_relative 'fastlane/lib/screenshot_helper'

# Normalize with auto-detection
ScreenshotHelper.normalize_screenshots(
  'path/to/raw',
  'path/to/normalized',
  auto_detect: true
)

# Validate with specific sizes
ScreenshotHelper.validate_screenshots(
  'path/to/normalized',
  expected_count: 10,
  allowed_sizes: [:iphone_67, :ipad_13],
  strict: false  # true = warnings also fail
)
```

### Force Specific Target Size

```ruby
# Force all screenshots to iPhone 6.7" size
ScreenshotHelper.normalize_screenshots(
  input_dir,
  output_dir,
  force_target: :iphone_67
)
```

## Current Screenshot Inventory

| Platform | Locale | Count | Raw Size | Normalized Size | Status |
|----------|--------|-------|----------|-----------------|--------|
| iPhone | en-US | 5 | 1320x2868 | 1290x2796 | ✅ Valid |
| iPhone | fi | 5 | 1320x2868 | 1290x2796 | ✅ Valid |
| iPad | en-US | 5 | 2064x2752 | 2064x2752 | ✅ Valid (native 13") |
| iPad | fi | 5 | 2064x2752 | 2064x2752 | ✅ Valid (native 13") |
| Watch | en-US | 5 | 416x496 | 396x484 | ✅ Valid |
| Watch | fi | 5 | 416x496 | 396x484 | ✅ Valid |
| **Total** | | **30** | | | ✅ **All Valid** |

## Error Handling

### Common Errors

**"Not a valid App Store Connect size"**
- Screenshot dimensions don't match any official size
- Solution: Run `normalize_all_screenshots` first

**"Dimensions too small for iOS/iPadOS"**
- Screenshot width < 1000px for iPhone/iPad
- Indicates corrupted or test image

**"Failed to normalize"**
- ImageMagick convert command failed
- Check ImageMagick installation: `brew install imagemagick`

### Warnings (Non-Fatal)

**"Non-standard naming"**
- Filename doesn't match expected pattern
- Doesn't affect functionality

**"Large file size"**
- Screenshot >2MB
- Consider optimizing PNG compression

## Testing

```bash
# Test normalization
bundle exec fastlane ios normalize_all_screenshots

# Test validation (should pass)
bundle exec fastlane ios validate_all_screenshots

# Test with intentionally bad screenshots
# (Create test file with wrong dimensions)
convert -size 500x500 xc:blue /tmp/test_invalid.png
cp /tmp/test_invalid.png fastlane/screenshots_normalized/en-US/
bundle exec fastlane ios validate_all_screenshots
# ↑ Should FAIL with clear error message
```

## Dependencies

- **ImageMagick** (v6 or v7): `brew install imagemagick`
- **Fastlane**: Included in Gemfile
- **Ruby 3.0+**: For modern syntax

## Related Documentation

- `documentation/todo.automate.md` - Task 4.2 implementation details
- `fastlane/lib/README_WATCH_SCREENSHOTS.md` - Watch-specific documentation
- `fastlane/Fastfile` - Lane definitions
- Apple: [Screenshot specifications](https://help.apple.com/app-store-connect/)

## Migration Notes

### From Old Workflow

**Before** (manual normalization in screenshots_framed lane):
```ruby
# Old: Manual size conversion inline
if size == [1320, 2868]
  target_w, target_h = [1290, 2796]
end
sh "magick convert ..."
```

**After** (unified helper):
```ruby
# New: Automated with validation
ScreenshotHelper.normalize_screenshots(...)
ScreenshotHelper.validate_screenshots(...)
```

### Benefits

✅ **Centralized logic**: One helper for all platforms  
✅ **Auto-detection**: No manual device type specification  
✅ **Validation**: Catch issues before App Store upload  
✅ **CI-ready**: Clear pass/fail signals  
✅ **Maintainable**: Apple adds new sizes? Update once in helper

## Future Enhancements

- [ ] Support for dark mode variants (different output directories)
- [ ] Batch processing with progress bars for large screenshot sets
- [ ] Screenshot comparison (before/after normalization)
- [ ] Automatic upload integration with `deliver`
- [ ] Support for additional platforms (tvOS, macOS)

---

**Last Updated**: November 22, 2025
**Version**: 1.1 (Updated to iPad 13" 2064x2752 standard)
**Status**: Production Ready ✅
