---
title: macOS Screenshot Visibility Fix - Background Apps Appearing
date: 2025-12-16
severity: CRITICAL
category: macos
tags: [screenshots, xcuitest, applescript, window-management, nsworkspace]
symptoms: [screenshots show other applications, desktop wallpaper visible, ListAll not visible, window behind other windows]
root_cause: XCUIScreen.main.screenshot() captures entire display; window not properly activated/frontmost
solution: Hide all other apps, use AppleScript to force window frontmost with AXRaise action
files_affected:
  - ListAll/ListAllMacUITests/MacScreenshotTests.swift
related:
  - fix-macos-screenshots.md
  - macos-screenshot-timing-analysis.md
---

## Problem

Screenshots captured by macOS UI tests showed other applications instead of ListAll.

## Root Causes

### 1. Early Return Without Frontmost Verification

```swift
// BAD: Exits without verifying window is FRONTMOST
if mainWindow.exists && mainWindow.isHittable {
    return  // Window may still be behind other windows!
}
```

### 2. No AXRaise Action

Setting `frontmost=true` doesn't guarantee window is visually on top.

### 3. Other Apps Not Hidden

`XCUIScreen.main.screenshot()` captures ALL visible windows.

## Solution

### hideAllOtherApps()

```swift
private func hideAllOtherApps() {
    let workspace = NSWorkspace.shared
    let runningApps = workspace.runningApplications.filter { app in
        guard app.bundleIdentifier != "io.github.chmc.ListAllMac" else { return false }
        guard app.bundleIdentifier != "com.apple.finder" else { return false }
        guard app.bundleIdentifier != "com.apple.dock" else { return false }
        guard app.activationPolicy == .regular else { return false }
        return true
    }
    for app in runningApps {
        app.hide()
    }
    sleep(1)
}
```

### forceWindowOnScreen() AppleScript

```applescript
tell application "System Events"
    set frontmost of process "ListAll" to true
    delay 0.5
    perform action "AXRaise" of window 1 of process "ListAll"
end tell
```

### Required Delays

- `forceWindowOnScreen()`: 2 seconds after AppleScript
- `prepareWindowForScreenshot()`: 3 seconds after activation
- AppleScript internal: 0.5s and 1s for window operations

## Permissions Required

- Accessibility permission for xcodebuild/Xcode
- AppleScript permission for Terminal
