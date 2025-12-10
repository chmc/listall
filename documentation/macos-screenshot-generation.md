# macOS Screenshot Generation Guide

## Overview

This document describes how to generate App Store screenshots for the macOS version of ListAll using LOCAL test execution (not CI).

## Screenshot Requirements

### App Store Requirements
- **Minimum**: 3 screenshots per locale
- **Maximum**: 10 screenshots per locale
- **Aspect Ratio**: 16:10
- **Recommended Resolution**: 2880x1800 (Retina)
- **Format**: PNG

### Current Implementation
The macOS screenshot tests capture **4 screenshots** per locale:

1. **01_MainWindow** - Main window with sidebar showing lists and detail view with items
2. **02_ListDetailView** - List detail view with multiple items (completed and active)
3. **03_ItemEditSheet** - Item editing sheet/modal
4. **04_SettingsWindow** - Settings window with tabs

## Technical Implementation

### Test Files
- **MacScreenshotTests.swift** - Screenshot test scenarios
- **MacSnapshotHelper.swift** - Screenshot capture helper (adapted from Fastlane Snapshot for macOS)

### Screenshot Capture Method
Screenshots are captured using `XCUIScreen.main.screenshot()` which captures the entire main display at native Retina resolution (typically 2880x1800 on modern Macs).

### Output Location
Screenshots are saved to the Fastlane cache directory:
```
~/Library/Caches/tools.fastlane/screenshots/Mac-*.png
```

Example filenames:
- `Mac-01_MainWindow.png`
- `Mac-02_ListDetailView.png`
- `Mac-03_ItemEditSheet.png`
- `Mac-04_SettingsWindow.png`

### Locale Support
The MacSnapshotHelper reads locale information from Fastlane cache directory files:
- `language.txt` - Device language (e.g., "en", "fi")
- `locale.txt` - Device locale (e.g., "en-US", "fi")

These files are managed by Fastlane when running screenshot generation through Fastlane lanes.

## Running Screenshot Tests Locally

### Method 1: Direct xcodebuild (for testing)

Run all macOS screenshot tests:
```bash
xcodebuild test \
  -project ListAll/ListAll.xcodeproj \
  -scheme ListAllMac \
  -destination 'platform=macOS' \
  -only-testing:ListAllMacUITests/MacScreenshotTests
```

Run a specific test:
```bash
xcodebuild test \
  -project ListAll/ListAll.xcodeproj \
  -scheme ListAllMac \
  -destination 'platform=macOS' \
  -only-testing:ListAllMacUITests/MacScreenshotTests/testScreenshot01_MainWindow
```

### Method 2: Fastlane Lane (recommended, when implemented)

**Note**: Fastlane lane for macOS screenshots is not yet implemented. This is planned for Phase 10.

Expected usage (once implemented):
```bash
# Generate macOS screenshots for all locales
bundle exec fastlane mac_screenshots

# Generate macOS screenshots for specific locale
bundle exec fastlane mac_screenshots locale:en-US
```

## Post-Processing

After screenshot generation, screenshots need to be:

1. **Verified**: Check that all 4 screenshots were captured
2. **Organized**: Move from cache directory to repository structure
3. **Validated**: Verify resolution and file size

Expected final location:
```
fastlane/screenshots/mac/en-US/
  01_MainWindow.png
  02_ListDetailView.png
  03_ItemEditSheet.png
  04_SettingsWindow.png

fastlane/screenshots/mac/fi/
  01_MainWindow.png
  02_ListDetailView.png
  03_ItemEditSheet.png
  04_SettingsWindow.png
```

## Test Architecture

### Test Data
The tests use deterministic test data via launch arguments:
- `UITEST_MODE` - Enables UI test mode
- `UITEST_SCREENSHOT_MODE` - Enables screenshot-specific behavior
- `DISABLE_ANIMATIONS` - Disables animations for consistent screenshots

Test data is managed by `UITestDataService.swift` which creates:
- 3 pre-populated lists with multiple items
- Mix of completed and active items
- Realistic item text for screenshots

### App Launch Strategy
Tests use a retry mechanism to handle macOS app launch flakiness:
- **Max Retries**: 2 (total 3 attempts)
- **Launch Timeout**: 60 seconds per attempt
- **Total Budget**: 120s for launch, 180s for test execution (300s total)

### UI Synchronization
Tests wait for UI to be ready using:
- `waitForExistence(timeout:)` for specific elements
- Dynamic polling for any visible window/button/table
- Additional settle time after launch (2 seconds)

## Resolution and Display Notes

### Important: Aspect Ratio Requirement
App Store requires 16:10 aspect ratio for macOS screenshots. `XCUIScreen.main.screenshot()` captures the **entire display**, so the screenshot aspect ratio depends on your display's aspect ratio:

- **16:10 displays** (e.g., 2880x1800): ✅ Perfect for App Store
- **16:9 displays** (e.g., 3840x2160): ⚠️ Requires cropping to 16:10
- **21:9 ultrawide** (e.g., 3840x1600): ⚠️ Requires cropping to 16:10

### Retina Displays
On Retina displays, `XCUIScreen.main.screenshot()` captures at 2x resolution:
- Physical display: 1440x900 → Screenshot: 2880x1800 ✅ (16:10 ratio, perfect)
- Physical display: 1280x800 → Screenshot: 2560x1600 ✅ (16:10 ratio, perfect)
- Physical display: 1920x1080 → Screenshot: 3840x2160 ⚠️ (16:9 ratio, needs crop)
- Physical display: 1920x800 → Screenshot: 3840x1600 ⚠️ (21:9 ratio, needs crop)

This is ideal for App Store submission as Apple requires high-resolution screenshots.

### Non-Retina Displays
On non-Retina displays, screenshots will be captured at 1x resolution:
- Physical display: 1440x900 → Screenshot: 1440x900 ✅ (16:10 ratio)
- Physical display: 1920x1080 → Screenshot: 1920x1080 ⚠️ (16:9 ratio, needs crop)

**Recommendation**: Generate screenshots on a Retina Mac with 16:10 aspect ratio (e.g., MacBook Pro 16" with 3456x2234 display) for best quality.

### Window Size
The macOS app uses a default window size defined in `ListAllMacApp.swift`. Tests do not resize the window, relying on the app's default size for consistency.

**Note**: Since `XCUIScreen.main.screenshot()` captures the entire screen (not just the app window), the app window size doesn't affect the screenshot dimensions. The screenshot will always match your display resolution.

### Post-Processing: Cropping to 16:10
If your display is not 16:10, you'll need to crop screenshots to 16:10 aspect ratio after generation.

Recommended 16:10 target resolutions:
- **2880x1800** (ideal for Retina)
- **2560x1600**
- **1920x1200**
- **1440x900** (minimum recommended)

Example cropping with ImageMagick:
```bash
# Crop from center to 2880x1800
magick Mac-01_MainWindow.png -gravity center -crop 2880x1800+0+0 +repage Mac-01_MainWindow_cropped.png
```

## Troubleshooting

### Screenshots not saved
1. Check console output for error messages
2. Verify cache directory exists and is writable:
   ```bash
   ls -la ~/Library/Caches/tools.fastlane/screenshots/
   ```
3. Check for marker files:
   ```bash
   ls -la ~/Library/Caches/tools.fastlane/setupSnapshot_completed.txt
   ls -la ~/Library/Caches/tools.fastlane/snapshot_marker_*.txt
   ```

### App launch fails
1. Ensure no other instance of ListAllMac is running
2. Check System Settings → Privacy & Security for UI automation permissions
3. Try manual cleanup:
   ```bash
   killall ListAllMac
   killall ListAllMacUITests
   ```

### Screenshots have wrong resolution
1. Check actual display resolution:
   ```bash
   system_profiler SPDisplaysDataType | grep Resolution
   ```
2. Verify Retina mode is enabled in Display Settings
3. Check screenshot file size:
   ```bash
   sips -g pixelWidth -g pixelHeight path/to/screenshot.png
   ```
4. Calculate aspect ratio:
   ```bash
   python3 -c "w, h = 3840, 1600; print(f'{w}:{h} = {w/h:.2f}:1')"
   ```
5. If aspect ratio is not 1.6:1 (16:10), crop screenshots using ImageMagick

### Locale not detected
When running via xcodebuild directly (not Fastlane), locale files may not exist. This is expected. Fastlane creates these files when running screenshot generation lanes.

For manual testing, you can create locale files:
```bash
mkdir -p ~/Library/Caches/tools.fastlane
echo "en" > ~/Library/Caches/tools.fastlane/language.txt
echo "en-US" > ~/Library/Caches/tools.fastlane/locale.txt
```

## Next Steps

### Phase 10: Fastlane Integration
To complete macOS screenshot automation:

1. Create Fastlane lane `mac_screenshots` in Fastfile
2. Add locale iteration logic
3. Implement post-processing to organize screenshots
4. Add screenshot validation (resolution, file size)
5. Update `generate-screenshots-local.sh` to support macOS
6. Add macOS screenshots to CI pipeline (optional)

### Example Fastlane Lane (pseudo-code)
```ruby
lane :mac_screenshots do |options|
  locales = options[:locale] ? [options[:locale]] : %w[en-US fi]

  locales.each do |locale|
    # Setup locale files
    create_locale_files(locale)

    # Run screenshot tests
    run_tests(
      project: "ListAll/ListAll.xcodeproj",
      scheme: "ListAllMac",
      destination: "platform=macOS",
      only_testing: ["ListAllMacUITests/MacScreenshotTests"]
    )

    # Post-process: move and organize screenshots
    organize_mac_screenshots(locale)
  end

  # Validate screenshots
  validate_mac_screenshots
end
```

## References

- **MacScreenshotTests.swift**: `/Users/aleksi/source/ListAllApp/ListAll/ListAllMacUITests/MacScreenshotTests.swift`
- **MacSnapshotHelper.swift**: `/Users/aleksi/source/ListAllApp/ListAll/ListAllMacUITests/MacSnapshotHelper.swift`
- **App Store Screenshot Requirements**: https://help.apple.com/app-store-connect/#/devd274dd925
- **XCUITest Documentation**: https://developer.apple.com/documentation/xctest/xcuitest

## Version History

- **v1.0** (2025-12-10): Initial documentation for macOS screenshot tests
