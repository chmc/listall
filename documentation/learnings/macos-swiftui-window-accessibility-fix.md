---
title: macOS SwiftUI Window Accessibility for XCUITest
date: 2025-12-20
severity: MEDIUM
category: testing
tags: [xcuitest, accessibility, swiftui, windowgroup, nshostingview]
symptoms:
  - app.windows.count returns 0 in XCUITest
  - app.windows.firstMatch.waitForExistence() returns false
  - osascript count windows returns 0
  - Menu bar items ARE visible (proves app is running)
  - Window IS visible on screen (proves window exists)
  - UI elements (buttons, outlines) ARE accessible via app.buttons, app.outlines
root_cause: SwiftUI WindowGroup uses NSHostingView creating hidden accessibility layer not tracked by standard tools
solution: Use content-based verification instead of window queries; screenshots still work despite exists returning false
files_affected:
  - ListAll/ListAllMacUITests/MacScreenshotTests.swift
related: [macos-tahoe-window-creation-xcode.md]
---

## Why This Happens

SwiftUI's `WindowGroup` on macOS uses `NSHostingView` to bridge SwiftUI views into AppKit. This creates a hidden accessibility layer that XCUITest cannot query via `app.windows`.

From MacPaw Research: "An additional layer is added by NSHostingView, which is not reflected in the structure fetched for the window."

## Critical Discovery

**Even though `app.windows.firstMatch.exists` returns false, `app.windows.firstMatch.screenshot()` STILL WORKS.**

XCUIElement.screenshot() uses a different code path than `exists`, likely querying screen region directly via Core Graphics.

## Workarounds

### 1. Content-Based Verification (Recommended)

```swift
let sidebar = app.outlines["ListsSidebar"]
if sidebar.waitForExistence(timeout: 10) {
    print("Window verified - found sidebar content")
}
```

### 2. AppleScript Fallback

```swift
tell application "System Events"
    tell process "ListAll"
        set frontmost to true
        if (count of windows) > 0 then
            perform action "AXRaise" of window 1
        end if
    end tell
end tell
```

### 3. Screenshot Despite False Exists

```swift
let mainWindow = app.windows.firstMatch
// mainWindow.exists returns false, but...
let screenshot = mainWindow.screenshot()  // This still works!
```

## Why Individual Elements Work

SwiftUI registers individual UI elements in accessibility when they have explicit identifiers:

```swift
List { ... }
    .accessibilityIdentifier("ListsSidebar")  // Works
```

Only the WINDOW container itself is not queryable via `app.windows`.

## Solutions That Don't Work

- `.accessibilityIdentifier("MainWindow")` on WindowGroup - Compiler error, modifier not available
- NSViewRepresentable to set accessibility - Brittle, timing-dependent
- Migrate to AppKit NSWindow - Major refactoring, against SwiftUI best practices

## Conclusion

This is a known limitation of SwiftUI's accessibility integration on macOS, not a bug in your code. Use content-based verification.
