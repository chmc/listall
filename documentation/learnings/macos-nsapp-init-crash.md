# macOS NSApp Initialization Crash in SwiftUI App

## Problem

macOS UI tests were failing with "Application does not have a process ID" error. The app was crashing immediately on launch during UI tests.

## Root Cause

In `ListAllMacApp.init()`, we were calling:
```swift
NSApp.setActivationPolicy(.regular)
NSApplication.shared.activate(ignoringOtherApps: true)
```

However, in a SwiftUI `@main` app, the `init()` method runs **before** `NSApplication` is fully initialized. Calling `NSApp` methods at this point causes an assertion failure, crashing the app.

The crash log showed:
```
"symbol":"_assertionFailure(_:_:file:line:flags:)"
"symbol":"ListAllMacApp.init()"
```

## Solution

Remove any `NSApp` / `NSApplication.shared` calls from the SwiftUI app's `init()`. Instead, handle app activation in:

1. **`AppDelegate.applicationDidFinishLaunching()`** - This is the correct place for activation policy and app activation calls, as `NSApplication` is fully initialized at this point.

2. **For UI tests**, ensure `AppDelegate` handles:
   - `NSApp.setActivationPolicy(.regular)`
   - `NSApplication.shared.activate(ignoringOtherApps: true)`
   - Immediate window creation (no delays)

## Code Changes

**Before (crashing):**
```swift
// In ListAllMacApp.init()
if ProcessInfo.processInfo.arguments.contains("UITEST_MODE") {
    NSApp.setActivationPolicy(.regular)  // CRASH: NSApp not ready
    NSApplication.shared.activate(ignoringOtherApps: true)
}
```

**After (working):**
```swift
// In ListAllMacApp.init()
if ProcessInfo.processInfo.arguments.contains("UITEST_MODE") {
    print("UI test mode detected - activation will happen in AppDelegate")
}

// In AppDelegate.applicationDidFinishLaunching()
NSApp.setActivationPolicy(.regular)  // OK: NSApp is ready
NSApplication.shared.activate(ignoringOtherApps: true)
```

## Key Takeaway

In SwiftUI macOS apps using `@main`, the `init()` method runs before `NSApplication` is fully initialized. Any code that requires `NSApp` or `NSApplication.shared` must be deferred to `AppDelegate.applicationDidFinishLaunching()` or later.
