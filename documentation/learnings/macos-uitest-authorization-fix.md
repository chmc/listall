---
title: macOS UI Test Authorization Lost Between Locale Runs
date: 2025-12-11
severity: CRITICAL
category: testing
tags: [xcuitest, macos, authorization, accessibility, multi-locale, screenshots]
symptoms:
  - "Not authorized for performing UI testing actions"
  - "Lost connection to the application"
  - First locale succeeds, subsequent locales fail
  - Permission dialog asking to control Finder via AppleScript
root_cause: Recreating XCUIApplication instances causes macOS to revoke authorization; using bundleIdentifier initializer triggers re-authorization
solution: Use single XCUIApplication instance with default initializer, add stabilization delays between test runs
files_affected:
  - ListAllMacUITests/MacScreenshotTests.swift
related:
  - macos-uitest-code-signing-sandbox.md
  - macos-xcuitest-list-selection.md
---

## macOS vs iOS Authorization Model

| Aspect | iOS Simulator | macOS |
|--------|---------------|-------|
| Sandbox | Fully sandboxed | Accesses real system APIs |
| Permissions | Granted automatically | Requires explicit user consent |
| Multiple launches | No issues | Authorization can be lost |

## Fixes Applied

### 1. Use Default XCUIApplication Initializer

```swift
// WRONG - triggers re-authorization
app = XCUIApplication(bundleIdentifier: "io.github.chmc.ListAllMac")

// CORRECT - maintains authorization
app = XCUIApplication()
```

### 2. Never Recreate App Instance in Retries

```swift
// WRONG - loses authorization
if attempt > 1 {
    app = XCUIApplication(bundleIdentifier: "...")
}

// CORRECT - keep original instance
if attempt > 1 {
    sleep(5)
    // DO NOT recreate app instance
}
```

### 3. Add Stabilization Delay

```swift
override func setUpWithError() throws {
    sleep(3)  // Let system stabilize between test runs
    app = XCUIApplication()
}
```

### 4. Minimize AppleScript Usage

Try `app.activate()` first, only fall back to AppleScript if needed.

## Required Manual Setup (One-Time)

1. System Settings > Privacy & Security > Accessibility
   - Enable: `io.github.chmc.ListAllMacUITests.xctrunner`
   - Enable: `xcodebuild` (if running via CLI)

2. If needed, System Settings > Privacy & Security > Automation
   - Grant permissions for VS Code/Terminal to control System Events
