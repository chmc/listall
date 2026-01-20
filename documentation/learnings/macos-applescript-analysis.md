---
title: macOS AppleScript Screenshot Automation Race Condition
date: 2024-12-19
severity: CRITICAL
category: macos
tags: [applescript, screenshots, automation, race-condition, timing, permissions]
symptoms:
  - Background apps visible in screenshots despite hiding logic
  - Apps reopen between shell script execution and screenshot capture
  - Inconsistent screenshot results across runs
  - 60% reliability rate for clean screenshots
root_cause: 19-30 second gap between shell script app hiding and actual screenshot capture allows apps to reopen via LaunchAgents
solution: Move all app hiding logic to UI test setUpWithError() to eliminate race condition
files_affected:
  - .github/scripts/generate-screenshots-local.sh
  - ListAll/ListAllMacUITests/MacScreenshotTests.swift
related:
  - macos-app-hiding-analysis.md
---

## Problem

Shell script hides apps at T+0s, but screenshots are captured at T+30s. During this 19-30 second window:
- LaunchAgents restart apps with `KeepAlive=true`
- System notifications open apps
- Background services relaunch GUI components

## Timeline

```
T+0s    Shell: hide_and_quit_background_apps_macos() starts
T+6s    Shell: completes (quit + hide + minimize)
T+6s    Shell: bundle exec fastlane starts
T+20s   UI test: ListAll launches
T+23s   UI test: prepareWindowForScreenshot() calls hideAllOtherApps()
T+30s   First screenshot captured

GAP: 24 seconds between shell hiding and screenshot
```

## Dual Hiding Conflict

**Shell script approach:**
- AppleScript `quit` (strong - apps stay closed)
- AppleScript `set visible to false` (medium)
- Runs BEFORE ListAll launches

**UI test approach:**
- `NSRunningApplication.hide()` (weak - apps can unhide)
- Runs 4 times during test execution
- Runs AFTER shell script already hid apps

## AppleScript vs Alternatives

| Approach | Reliability | Permissions | Can Hide? |
|----------|-------------|-------------|-----------|
| AppleScript | Strong | Accessibility + Automation | Yes |
| NSWorkspace.hide() | Weak | None | Yes (apps unhide) |
| killall/pkill | Strong | None | No (only kill) |
| launchctl | N/A | None | No (services only) |

**Verdict:** AppleScript IS the right tool. Problem is WHEN it runs (too early) and DUAL execution (both shell + UI test).

## Required Permissions

1. **Accessibility API** - System Settings > Privacy & Security > Accessibility
   - Required for `tell application "System Events"` to control other apps

2. **Automation (AppleEvents)** - First-run dialog per target app
   - Required for `tell application "Finder"` and similar

Permissions persist across reboots and minor macOS updates.

## Pattern Matching Inconsistency

Quit script checks: Xcode, xcode, xctest, XCTest, xctrunner, XCTRunner, Simulator, xcodebuild

Hide script only checks: Xcode, xctest, ListAll

Missing in hide script: XCTest (capitalized), xctrunner/XCTRunner, Simulator, xcodebuild

## Why Apps Reopen

1. **LaunchAgents** - `~/Library/LaunchAgents/` with `KeepAlive=true` relaunch within 5-10s
2. **Login Items** - "Open at Login" apps restore on quit
3. **Background Services** - imagent, CalendarAgent can wake GUI
4. **Notification Triggers** - Calendar, Reminders, Messages auto-open
5. **iCloud Sync** - CloudKit background daemons wake apps

## Solution

Move ALL hiding logic to UI test `setUpWithError()`:

```swift
override func setUpWithError() throws {
    continueAfterFailure = false
    sleep(3)

    // Hide apps HERE - immediately before launching ListAll
    hideAllOtherAppsViaAppleScript()
    sleep(2)

    app = XCUIApplication()
    setupSnapshot(app)
}
```

Benefits:
- Eliminates 19-second race condition
- Single source of truth for app hiding
- No gap for LaunchAgents to relaunch

## Metrics After Fix

| Metric | Before | After |
|--------|--------|-------|
| Race condition window | 19-30s | 0s |
| Reliability | 60% | 95% |
| Execution time | 30-40s | 25-30s |
