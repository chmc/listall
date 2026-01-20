---
title: macOS Screenshot Generation Guide
date: 2025-12-10
severity: MEDIUM
category: macos
tags: [screenshots, xcuitest, fastlane, app-store, localization]
symptoms: [need screenshot generation process, display aspect ratio issues]
root_cause: Documentation of screenshot generation workflow for App Store
solution: Use XCUITest with post-processing to normalize to 2880x1800
files_affected:
  - ListAll/ListAllMacUITests/MacScreenshotTests.swift
  - ListAll/ListAllMacUITests/MacSnapshotHelper.swift
related:
  - macos-screenshot-helper-implementation.md
  - macos-batch-screenshot-processing.md
---

## Screenshot Requirements

| Requirement | Value |
|-------------|-------|
| Minimum | 3 per locale |
| Maximum | 10 per locale |
| Aspect Ratio | 16:10 |
| Resolution | 2880x1800 (Retina) |
| Format | PNG |

## Screenshots Captured (4 per locale)

1. **01_MainWindow** - Sidebar with lists, detail view with items
2. **02_ListDetailView** - List detail with completed/active items
3. **03_ItemEditSheet** - Item editing modal
4. **04_SettingsWindow** - Settings with tabs

## Running Tests

```bash
# All screenshot tests
xcodebuild test \
  -project ListAll/ListAll.xcodeproj \
  -scheme ListAllMac \
  -destination 'platform=macOS' \
  -only-testing:ListAllMacUITests/MacScreenshotTests
```

## Display Aspect Ratios

| Display | Aspect | Status |
|---------|--------|--------|
| 2880x1800 | 16:10 | Perfect |
| 3840x2160 | 16:9 | Needs crop |
| 3840x1600 | 21:9 | Needs crop |

## Launch Arguments

- `UITEST_MODE` - Enables UI test mode
- `UITEST_SCREENSHOT_MODE` - Screenshot-specific behavior
- `DISABLE_ANIMATIONS` - Consistent screenshots

## Locale Support

MacSnapshotHelper reads from Fastlane cache:
- `~/Library/Caches/tools.fastlane/language.txt`
- `~/Library/Caches/tools.fastlane/locale.txt`

## Post-Processing

Crop to 16:10 with ImageMagick:
```bash
magick Mac-01_MainWindow.png -gravity center -crop 2880x1800+0+0 +repage output.png
```
