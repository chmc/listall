---
title: macOS Screenshot Test Main Thread Deadlock Fix
date: 2025-12-31
severity: CRITICAL
category: macos
tags: [xcuitest, applescript, deadlock, mainactor, nsapplescript, runloop]
symptoms: [main run loop busy for 30s, run loop nesting count negative, XCTAssertGreaterThan failed for 800]
root_cause: NSAppleScript with DispatchSemaphore blocks main thread while AppleScript needs main thread callback - classic deadlock
solution: Use osascript CLI via Process instead of NSAppleScript; use >= instead of > for dimension assertions
files_affected:
  - ListAll/ListAllMacUITests/RealAppleScriptExecutor.swift
  - ListAll/ListAllMacUITests/MacScreenshotTests.swift
related:
  - macos-screenshot-visibility-fix.md
---

## Problem

macOS screenshot generation failing with 3 issues:
1. "Unable to perform work on main run loop, process main thread busy for 30.0s"
2. "Run loop nesting count is negative (-1)"
3. "XCTAssertGreaterThan failed: (800.0) is not greater than (800.0)"

Only 2-3 screenshots per locale generated instead of 4.

## Root Cause: Main Thread Deadlock

```swift
// BAD: Causes deadlock from @MainActor context
DispatchQueue.global(qos: .userInitiated).async {
    let appleScript = NSAppleScript(source: script)
    let result = appleScript?.executeAndReturnError(&errorDict)
    semaphore.signal()
}
semaphore.wait(timeout: deadline)  // BLOCKS MAIN THREAD
```

`NSAppleScript.executeAndReturnError()` needs to callback to main thread (especially for System Events). Since test class is `@MainActor`, main thread is blocked waiting on semaphore while AppleScript needs it.

## Solution

### Fix 1: Use osascript CLI

```swift
// GOOD: Separate process, no main thread callback issues
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
process.arguments = ["-e", script]

DispatchQueue.global(qos: .userInitiated).async {
    process.waitUntilExit()
    semaphore.signal()
}
```

### Fix 2: Use >= for Dimension Assertions

```swift
// BAD: Fails when width == 800 (valid size)
XCTAssertGreaterThan(imageSize.width, 800, ...)

// GOOD: Accepts boundary value
XCTAssertGreaterThanOrEqual(imageSize.width, 800, ...)
```

### Fix 3: Run Loop Drain Helper

```swift
private func drainRunLoop() {
    for _ in 0..<5 {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }
}
```

Call at end of `setUpWithError()` and `prepareWindowForScreenshot()`.

## Results

Before: en-US 2/4, fi 3/4, 3 failures
After: en-US 4/4, fi 4/4, 0 failures

## Key Learnings

1. **Never use NSAppleScript with DispatchSemaphore from @MainActor**
2. **osascript CLI is safer** - runs as separate process
3. **Run loop draining** prevents corruption in XCUITest
4. **Use >= not > for dimension assertions** when boundary is valid
