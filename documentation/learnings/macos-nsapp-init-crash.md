---
title: macOS NSApp Initialization Crash in SwiftUI App
date: 2026-01-07
severity: CRITICAL
category: macos
tags: [crash, nsapp, swiftui, app-lifecycle, ui-tests, initialization]
symptoms:
  - UI tests fail with "Application does not have a process ID"
  - App crashes immediately on launch during UI tests
  - Assertion failure in ListAllMacApp.init()
root_cause: Calling NSApp/NSApplication.shared in SwiftUI @main init() before NSApplication is initialized
solution: Move NSApp calls to AppDelegate.applicationDidFinishLaunching() where NSApplication is ready
files_affected:
  - ListAllMac/ListAllMacApp.swift
  - ListAllMac/AppDelegate.swift
related: [macos-native-sheet-presentation.md, macos-uitest-authorization-fix.md, macos-test-isolation-permission-dialogs.md]
---

## Problem

macOS UI tests failing with crash. Crash log showed:
```
"symbol":"_assertionFailure(_:_:file:line:flags:)"
"symbol":"ListAllMacApp.init()"
```

## Root Cause

In SwiftUI `@main` apps, `init()` runs **before** `NSApplication` is fully initialized. Calling `NSApp` methods crashes the app.

**Crashing code:**
```swift
// In ListAllMacApp.init()
NSApp.setActivationPolicy(.regular)  // CRASH: NSApp not ready
NSApplication.shared.activate(ignoringOtherApps: true)
```

## Solution

Move NSApp calls to `AppDelegate.applicationDidFinishLaunching()`:

**Before (crashing):**
```swift
// ListAllMacApp.init()
if ProcessInfo.processInfo.arguments.contains("UITEST_MODE") {
    NSApp.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
}
```

**After (working):**
```swift
// ListAllMacApp.init()
if ProcessInfo.processInfo.arguments.contains("UITEST_MODE") {
    print("UI test mode - activation in AppDelegate")
}

// AppDelegate.applicationDidFinishLaunching()
NSApp.setActivationPolicy(.regular)  // OK: NSApp is ready
NSApplication.shared.activate(ignoringOtherApps: true)
```

## Key Rule

In SwiftUI macOS apps using `@main`, any code requiring `NSApp` or `NSApplication.shared` must be deferred to `AppDelegate.applicationDidFinishLaunching()` or later.
