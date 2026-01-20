---
title: macOS Screenshot Best Practice Implementation Plan
date: 2025-12-16
severity: HIGH
category: macos
tags: [screenshots, xcuitest, swiftui, window-capture, app-store]
symptoms: [XCUIScreen captures entire display, background apps visible, race conditions, window not accessible]
root_cause: SwiftUI WindowGroup may not expose windows to accessibility hierarchy; XCUIScreen.main.screenshot() captures entire display not just app window
solution: Try window-only screenshot via XCUIElement.screenshot() first, fall back to full-screen with app hiding
files_affected:
  - ListAll/ListAllMacUITests/MacSnapshotHelper.swift
  - ListAll/ListAllMacUITests/MacScreenshotTests.swift
  - fastlane/Fastfile
related:
  - macos-screenshot-visibility-fix.md
  - macos-screenshot-generation.md
---

## Problem

macOS screenshot generation had multiple issues:
1. `XCUIScreen.main.screenshot()` captures entire screen (antipattern)
2. Multiple overlapping workarounds (shell script + UI test both hiding apps)
3. Race conditions between preparation and capture
4. No window state verification before screenshot

## Key Insight

**SwiftUI Window Accessibility Bug**: `app.windows.firstMatch.exists` may return `false` even when content elements ARE accessible.

## Solution

### Window Screenshot with Graceful Fallback

```swift
private func captureScreenshot(app: XCUIApplication, name: String) -> NSImage {
    let mainWindow = app.windows.firstMatch
    let windowAccessible = mainWindow.exists || mainWindow.isHittable

    if windowAccessible {
        return mainWindow.screenshot().image  // Preferred
    } else {
        return captureFullScreenWithAppHiding(app: app)  // Fallback
    }
}
```

### Critical Notes

- `XCUIElement.screenshot()` does NOT throw - it crashes if element doesn't exist
- Must use pre-checks (`exists`/`isHittable`), not try-catch
- Keep `hideAllOtherApps()` for fallback path
- Use ImageMagick for post-processing (sips distorts aspect ratios)

## Validation Test

```swift
func testWindowScreenshotCapability() {
    let mainWindow = app.windows.firstMatch
    print("window.exists = \(mainWindow.exists)")
    print("window.isHittable = \(mainWindow.isHittable)")
    // If both false: use full-screen only approach
}
```

## App Store Requirements

- Resolution: 2880x1800 (16:10 aspect ratio)
- Format: PNG or JPEG, RGB, no transparency
- Count: 1-10 per locale
