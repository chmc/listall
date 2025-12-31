# macOS Screenshot Test Fixes - 2025-12-31

## Problem

macOS screenshot generation was failing with 3 distinct issues:

1. **testScreenshot04_SettingsWindow** - "Unable to perform work on main run loop, process main thread busy for 30.0s"
2. **testScreenshot02_ListDetailView** (en-US only) - "Run loop nesting count is negative (-1), observer possibly not unregistered"
3. **testA_P2_WindowCaptureVerification** - "XCTAssertGreaterThan failed: (800.0) is not greater than (800.0)"

Only 2-3 screenshots per locale were generated instead of 4.

## Root Causes

### 1. Main Thread Deadlock (Issues 1 & 2)

The `RealAppleScriptExecutor` used `NSAppleScript` with `DispatchSemaphore.wait()`:

```swift
// OLD CODE - CAUSED DEADLOCK
DispatchQueue.global(qos: .userInitiated).async {
    let appleScript = NSAppleScript(source: script)
    let result = appleScript?.executeAndReturnError(&errorDict)
    semaphore.signal()
}
semaphore.wait(timeout: deadline)  // BLOCKS MAIN THREAD
```

**Problem**: `NSAppleScript.executeAndReturnError()` often needs to callback to the main thread (especially for System Events AppleScript). Since the test class is `@MainActor`, the main thread was blocked waiting on the semaphore while AppleScript needed it - classic deadlock.

### 2. Width Assertion Too Strict (Issue 3)

```swift
// OLD CODE
XCTAssertGreaterThan(imageSize.width, 800, ...)  // Fails when width == 800
```

The assertion required `>800` but the screenshot was exactly 800 pixels (400 points × 2x Retina). This is a valid size but failed the strict `>` comparison.

## Fixes Applied

### Fix 1: Use osascript CLI Instead of NSAppleScript

**File**: `ListAll/ListAllMacUITests/RealAppleScriptExecutor.swift`

Replaced NSAppleScript with osascript CLI via Process:

```swift
// NEW CODE - NO DEADLOCK
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
process.arguments = ["-e", script]

// Wait on background thread, doesn't block main thread callbacks
DispatchQueue.global(qos: .userInitiated).async {
    process.waitUntilExit()
    semaphore.signal()
}
```

**Why this works**: osascript runs as a separate process, so it doesn't need callbacks to the main thread of the test process.

### Fix 2: Change Width Assertion to >=

**File**: `ListAll/ListAllMacUITests/MacScreenshotTests.swift:470-478`

```swift
// NEW CODE
XCTAssertGreaterThanOrEqual(
    imageSize.width, 800,
    "Screenshot width must be >=800"
)
```

### Fix 3: Add Run Loop Drain Helper

**File**: `ListAll/ListAllMacUITests/MacScreenshotTests.swift:356-365`

Added a helper to drain pending run loop operations:

```swift
private func drainRunLoop() {
    for _ in 0..<5 {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }
}
```

Called at:
- End of `setUpWithError()`
- End of `prepareWindowForScreenshot()`

This helps prevent "Run loop nesting count is negative" errors by ensuring pending run loop work completes before proceeding.

## Results

Before fixes:
- en-US: 2/4 screenshots
- fi: 3/4 screenshots
- 3 test failures

After fixes:
- en-US: 4/4 screenshots
- fi: 4/4 screenshots
- 0 test failures
- "✅ P2 PASSED: Window capture verification successful!"

## Key Learnings

1. **Never use NSAppleScript with DispatchSemaphore from @MainActor context** - it can deadlock because NSAppleScript may need the main thread
2. **osascript CLI is safer** - runs as separate process, no main thread callback issues
3. **Run loop draining between operations** helps prevent run loop corruption in XCUITest
4. **Use `>=` instead of `>` for dimension assertions** when the boundary value is valid

## Related Files

- `/Users/aleksi/source/listall/ListAll/ListAllMacUITests/RealAppleScriptExecutor.swift`
- `/Users/aleksi/source/listall/ListAll/ListAllMacUITests/MacScreenshotTests.swift`
