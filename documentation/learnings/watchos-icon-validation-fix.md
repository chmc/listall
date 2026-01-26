---
title: watchOS App Store Icon Validation Error Fix
date: 2026-01-26
type: bug-fix
tags:
  - watchos
  - app-store
  - validation
  - icons
  - asset-catalog
  - CFBundleIconName
status: research-complete
severity: blocker
platforms:
  - watchOS
---

# watchOS App Store Icon Validation Error Fix

## Problem Statement

App Store Connect validation fails for watchOS app with two errors:

1. "Missing Icons. No icons found for watch application 'ListAll.app/Watch/ListAllWatch Watch App.app'. Make sure that its Info.plist file includes entries for CFBundleIconFiles."
2. "Missing Info.plist value. A value for the Info.plist key 'CFBundleIconName' is missing in the bundle 'io.github.chmc.ListAll.watchkitapp'."

## Root Cause

The watchOS app has **all required icon image files** physically present in `Assets.xcassets/AppIcon.appiconset/`, but the `Contents.json` file only references ONE icon (1024x1024), causing Xcode to ignore all other icon files during compilation.

### Current (Broken) Contents.json

```json
{
  "images": [
    {
      "filename": "1024x1024@1x.png",
      "idiom": "watch",
      "scale": "2x",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

### Available Icon Files (Unused)

- 1024x1024@1x.png (1.5M)
- 108x108@2x.png (49K)
- 98x98@2x.png (41K)
- 86x86@2x.png (32K)
- 50x50@2x.png (12K)
- 44x44@2x.png (9.4K)
- 40x40@2x.png (8.0K)
- 29x29@3x.png (9.3K)
- 29x29@2x.png (4.7K)
- 27.5x27.5@2x.png (4.3K)
- 24x24@2x.png (3.5K)

## Modern watchOS Icon Requirements (2024-2025)

### Asset Catalog Approach (Required for iOS 11+ SDK)

1. **Icons must be in asset catalog** (`.xcassets`)
2. **CFBundleIconName** Info.plist key must be set (NOT CFBundleIconFiles - that's legacy)
3. **Contents.json** must properly reference all icon files

### Build Settings Verification

Our build settings are **correct**:

```bash
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon ✓
INFOPLIST_KEY_CFBundleIconName = AppIcon ✓
SUPPORTED_PLATFORMS = watchos watchsimulator ✓
WATCHOS_DEPLOYMENT_TARGET = 9.0 ✓
```

## Solution Options

### Option 1: Single-Size Icon (Recommended for Xcode 14+)

**Requirements**: Xcode 14+ and watchOS 4+ deployment target (we have Xcode 26.1, watchOS 9.0 ✓)

**Steps**:
1. Open Xcode
2. Navigate to `ListAllWatch Watch App/Assets.xcassets/AppIcon.appiconset`
3. Select AppIcon asset
4. In Attributes Inspector, enable **"Single Size"**
5. Keep only the 1024x1024 icon
6. Xcode automatically generates all sizes at build time

**Benefits**:
- Simpler maintenance
- Automatic size generation
- Modern approach (Xcode 14+)
- Reduces asset catalog size

**Contents.json (Single-Size)**:
```json
{
  "images": [
    {
      "filename": "1024x1024@1x.png",
      "idiom": "watch-marketing",
      "scale": "1x",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

**Note**: The idiom should be "watch-marketing" (not "watch") for the 1024x1024 icon.

### Option 2: Complete Multi-Size Contents.json

If explicit control over all icon sizes is needed, reference all existing icon files:

```json
{
  "images": [
    {
      "filename": "24x24@2x.png",
      "idiom": "watch",
      "role": "notificationCenter",
      "scale": "2x",
      "size": "24x24",
      "subtype": "38mm"
    },
    {
      "filename": "27.5x27.5@2x.png",
      "idiom": "watch",
      "role": "notificationCenter",
      "scale": "2x",
      "size": "27.5x27.5",
      "subtype": "42mm"
    },
    {
      "filename": "29x29@2x.png",
      "idiom": "watch",
      "role": "companionSettings",
      "scale": "2x",
      "size": "29x29"
    },
    {
      "filename": "29x29@3x.png",
      "idiom": "watch",
      "role": "companionSettings",
      "scale": "3x",
      "size": "29x29"
    },
    {
      "filename": "40x40@2x.png",
      "idiom": "watch",
      "role": "appLauncher",
      "scale": "2x",
      "size": "40x40",
      "subtype": "38mm"
    },
    {
      "filename": "44x44@2x.png",
      "idiom": "watch",
      "role": "appLauncher",
      "scale": "2x",
      "size": "44x44",
      "subtype": "40mm"
    },
    {
      "filename": "50x50@2x.png",
      "idiom": "watch",
      "role": "appLauncher",
      "scale": "2x",
      "size": "50x50",
      "subtype": "44mm"
    },
    {
      "filename": "86x86@2x.png",
      "idiom": "watch",
      "role": "quickLook",
      "scale": "2x",
      "size": "86x86",
      "subtype": "38mm"
    },
    {
      "filename": "98x98@2x.png",
      "idiom": "watch",
      "role": "quickLook",
      "scale": "2x",
      "size": "98x98",
      "subtype": "42mm"
    },
    {
      "filename": "108x108@2x.png",
      "idiom": "watch",
      "role": "quickLook",
      "scale": "2x",
      "size": "108x108",
      "subtype": "44mm"
    },
    {
      "filename": "1024x1024@1x.png",
      "idiom": "watch-marketing",
      "scale": "1x",
      "size": "1024x1024"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

**Icon Roles**:
- `notificationCenter`: Notification icons
- `companionSettings`: iPhone companion app settings
- `appLauncher`: Main app icon on Watch home screen
- `quickLook`: Quick look/long-look notification icons

**Watch Subtypes**:
- `38mm`: Apple Watch Series 1-3 (smaller)
- `40mm`: Apple Watch Series 4-6, SE
- `42mm`: Apple Watch Series 1-3 (larger)
- `44mm`: Apple Watch Series 4-6, SE (larger)
- `45mm`, `49mm`: Newer models

## Key Findings from Research

### CFBundleIconFiles vs CFBundleIconName

- **CFBundleIconFiles**: Legacy approach (pre-iOS 11), array of icon filenames
- **CFBundleIconName**: Modern approach (iOS 11+), references asset catalog name
- **Rule**: Use `CFBundleIconName` with asset catalogs, NOT `CFBundleIconFiles`

### Common Validation Error Causes

1. **Incomplete Contents.json**: Icon files exist but aren't referenced (our issue)
2. **Wrong platform settings**: Watch target supports iOS (should be watchOS only)
3. **Missing 1024x1024 icon**: App Store requires `watch-marketing` 1024x1024 icon
4. **Alpha channel in icons**: PNG icons must have no alpha channel

### Related Flutter/Xamarin Issue

A similar issue was reported in Flutter watchOS apps where the Watch target had "Supported Platforms" misconfigured to include iOS. When set to watchOS only, the validation errors were resolved.

**Verification**: Our `SUPPORTED_PLATFORMS = watchos watchsimulator` is correct ✓

## Implementation Steps (Recommended: Option 1)

1. **Open Xcode project**: `ListAll/ListAll.xcodeproj`
2. **Navigate to asset catalog**: `ListAllWatch Watch App → Assets.xcassets → AppIcon`
3. **Select AppIcon** in the left sidebar
4. **Open Attributes Inspector** (⌥⌘4 or View → Inspectors → Attributes)
5. **Check "Single Size"** checkbox
6. **Verify 1024x1024 icon** is present and named correctly
7. **Clean build folder** (⇧⌘K)
8. **Archive** (Product → Archive)
9. **Validate** before upload to App Store Connect

## Verification

After fixing, verify the built app contains correct icon configuration:

```bash
# Build for archive
xcodebuild archive \
  -project ListAll/ListAll.xcodeproj \
  -scheme ListAllWatch \
  -archivePath build/ListAllWatch.xcarchive

# Check compiled app's Info.plist
plutil -p build/ListAllWatch.xcarchive/.../ListAllWatch\ Watch\ App.app/Info.plist | grep -A 3 CFBundleIcon

# Expected output:
# "CFBundleIcons" => {
#   "CFBundlePrimaryIcon" => {
#     "CFBundleIconName" => "AppIcon"
#   }
# }
```

## Related Documentation

- [App icons | Apple HIG](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [Asset Catalog Format Reference](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html)
- [Xcode 14 Single Size App Icon](https://useyourloaf.com/blog/xcode-14-single-size-app-icon/)
- [watchOS Icon Requirements](https://developer.apple.com/design/human-interface-guidelines/watchos/visual/app-icon/)

## Sources

- [Apple Developer Forums: Missing Info.plist value - CFBundleIconName](https://developer.apple.com/forums/thread/681513)
- [Flutter watchOS Icon Issue #167892](https://github.com/flutter/flutter/issues/167892)
- [Asset Catalog Format Reference](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html)
- [watchOS-2-Sampler Contents.json Example](https://github.com/shu223/watchOS-2-Sampler/blob/master/watchOS2Sampler%20WatchKit%20App/Assets.xcassets/AppIcon.appiconset/Contents.json)
- [Xcode 14 Single Size App Icon](https://useyourloaf.com/blog/xcode-14-single-size-app-icon/)

## Skills Applied

- `swiftui-patterns`: Not directly applicable (icon configuration issue)
- `coredata-sync`: Not applicable (build/validation issue)

This issue is an **Xcode project configuration problem**, not a SwiftUI pattern or Core Data sync issue. The fix is to properly configure the asset catalog's Contents.json file.
