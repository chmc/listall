# Watch Screenshot Helper

Ruby module for normalizing and validating watchOS screenshots to meet Apple App Store Connect requirements.

## Overview

This helper automatically:
- **Normalizes** raw watch screenshots (416x496 from Series 11 46mm) to App Store Connect required dimensions (396x484 for Series 7+ 45mm)
- **Validates** that screenshots match official Apple watch sizes
- **Provides detailed feedback** with clear error messages and visual indicators

## Apple Watch Screenshot Requirements

| Watch Model | Size | Dimensions |
|-------------|------|------------|
| Apple Watch Ultra (49mm) | `ultra` | 410x502 |
| **Apple Watch Series 7+ (45mm)** | **`series7plus`** | **396x484** ← Default |
| Apple Watch Series 4-6 (40mm) | `series4to6` | 368x448 |

## Usage

### Via Fastlane Lanes

**Generate and normalize screenshots automatically:**
```bash
bundle exec fastlane ios watch_screenshots
```

This lane:
1. Captures screenshots using Fastlane Snapshot (416x496)
2. Normalizes them to 396x484 (Series 7+ 45mm)
3. Copies to `screenshots/framed` for delivery

**Validate normalized screenshots:**
```bash
bundle exec fastlane ios verify_watch_screenshots
```

### Standalone Script

For manual processing:
```bash
ruby fastlane/lib/normalize_watch_screenshots.rb
```

This script:
1. Reads from `fastlane/screenshots/watch` (raw captures)
2. Normalizes to `fastlane/screenshots/watch_normalized`
3. Validates all screenshots

### Programmatic Usage

```ruby
require_relative 'fastlane/lib/watch_screenshot_helper'

# Normalize screenshots
WatchScreenshotHelper.normalize_screenshots(
  'fastlane/screenshots/watch',
  'fastlane/screenshots/watch_normalized',
  target_size: :series7plus  # or :ultra, :series4to6
)

# Validate screenshots
WatchScreenshotHelper.validate_screenshots(
  'fastlane/screenshots/watch_normalized',
  expected_count: 5,
  allowed_sizes: [:series7plus]
)
```

## File Structure

```
fastlane/
├── lib/
│   ├── watch_screenshot_helper.rb       # Core module
│   └── normalize_watch_screenshots.rb   # Standalone script
├── screenshots/
│   ├── watch/                           # Raw captures (416x496)
│   │   ├── en-US/
│   │   └── fi/
│   ├── watch_normalized/                # Normalized (396x484)
│   │   ├── en-US/
│   │   └── fi/
│   └── framed/                          # For delivery (includes watch)
│       ├── en-US/
│       └── fi/
```

## Implementation Details

### Normalization
- Uses ImageMagick `convert` command
- Resize strategy: `-resize WxH^ -gravity center -extent WxH`
- Maintains aspect ratio with center cropping
- Quality preserved at 100%

### Validation
- Checks exact dimensions against Apple's official sizes
- Validates filename patterns (supports Fastlane device prefix)
- Verifies file count per locale
- Provides warnings (naming) vs errors (dimensions)

### CI Integration
- Both lanes are CI-friendly
- Failures produce clear, actionable error messages
- Normalization warnings (ImageMagick v7 deprecation) are harmless

## Example Output

```
🔄 en-US/Apple Watch Series 11 (46mm)-01_Watch_Lists_Home.png: 416x496 → 396x484
✅ Normalized 10 watch screenshots to Apple Watch Series 7+ (45mm) (396x484)

✅ en-US/Apple Watch Series 11 (46mm)-01_Watch_Lists_Home.png: 396x484 (Apple Watch Series 7+ (45mm))
✅ All 10 screenshots are valid!
```

## Dependencies

- **ImageMagick** (v6 or v7): `brew install imagemagick`
- **Fastlane Snapshot**: Included in Fastlane
- **Ruby 3.0+**: For modern syntax

## Error Handling

The module raises `WatchScreenshotHelper::ValidationError` on:
- Missing or incorrect dimensions
- Files too small for watchOS (<300x400)
- Missing locale directories
- Unexpected file counts

Warnings (non-fatal):
- Non-standard filenames (wrong pattern)
- Large file sizes (>1MB)

## Testing

```ruby
# Test normalization
bundle exec fastlane ios watch_screenshots

# Test validation (should pass)
bundle exec fastlane ios verify_watch_screenshots

# Test with invalid dimensions (should fail)
# Create test files and run validation
```

## Notes

- Watch screenshots are typically **not framed** (industry standard)
- Normalized screenshots maintain original quality
- Supports EN and FI locales (configurable)
- Device prefix from Fastlane Snapshot is preserved
- ImageMagick v7 deprecation warnings are expected and harmless

## Related Documentation

- `documentation/todo.automate.md` - Task 4.2 implementation details
- `fastlane/Fastfile` - `watch_screenshots` and `verify_watch_screenshots` lanes
- Apple Documentation: [Screenshot specifications](https://help.apple.com/app-store-connect/)
