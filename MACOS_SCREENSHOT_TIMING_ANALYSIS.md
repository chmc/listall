# macOS Screenshot Background App Issues - Root Cause Analysis

## Executive Summary

After thorough analysis of the shell script's `hide_and_quit_background_apps_macos()` function and the macOS UI test code, I've identified **4 critical issues** that explain why background apps are appearing in screenshots:

### Critical Issues Found

1. **RACE CONDITION**: AppleScript runs BEFORE Fastlane/UI tests, creating a time gap where apps can reopen
2. **INCORRECT TIMING**: The UI test has its OWN `hideAllOtherApps()` function that runs DURING tests, but it's LESS effective than AppleScript
3. **DUAL HIDING LOGIC**: Two separate hiding mechanisms (shell script + UI test) are fighting each other
4. **WINDOW-ONLY CAPTURE**: Screenshot captures window-only, so background apps SHOULDN'T appear anyway - this suggests window positioning issues

---

## Detailed Analysis

### 1. Shell Script: `hide_and_quit_background_apps_macos()` (Lines 359-463)

**Location**: `.github/scripts/generate-screenshots-local.sh`

**When it runs**: BEFORE `bundle exec fastlane ios screenshots_macos` at line 523

**What it does**:
```bash
generate_macos_screenshots() {
    # Line 523: Desktop cleanup happens FIRST
    hide_and_quit_background_apps_macos

    # Line 527: Then Fastlane launches (5-30 seconds later)
    bundle exec fastlane ios screenshots_macos
}
```

**Timeline Problem**:
```
T+0s:   Shell script calls hide_and_quit_background_apps_macos()
T+3s:   Wait 3 seconds for apps to quit (line 421)
T+5s:   Wait 2 seconds for hide animations (line 446)
T+6s:   Shell script completes

T+6s:   Fastlane starts initializing
T+10s:  xcodebuild starts
T+20s:  UI test runner launches ListAll app
T+25s:  First screenshot captured

⚠️  GAP OF 19+ SECONDS where apps can reopen!
```

**AppleScript Pattern Matching (Lines 372-418)**:

✅ **CORRECT**: The AppleScript uses proper pattern matching:
```applescript
-- Skip ListAll app (the app being tested - must not be quit!)
if appName contains "ListAll" then
    set shouldSkip to true
end if
```

This correctly identifies:
- "ListAll" (the main app)
- "ListAllMac" (if running with that name)
- "ListAll.app" (with .app suffix)

✅ **CORRECT**: Pattern matching for system apps:
```applescript
if appName contains "Xcode" or appName contains "xcode" then
    set shouldSkip to true
end if

if appName contains "xctest" or appName contains "XCTest" or
   appName contains "xctrunner" or appName contains "XCTRunner" then
    set shouldSkip to true
end if
```

This correctly skips all Xcode-related processes.

**BUT**: The hide script in lines 427-443 has a potential issue:

❌ **INCONSISTENT PATTERN MATCHING**:
```applescript
# Line 435 uses "contains" for some checks
if appName does not contain "Xcode" and
   appName does not contain "xctest" and
   appName does not contain "ListAll" then
```

But this doesn't check for:
- XCTest (capital X)
- xctrunner/XCTRunner
- Simulator

So some test-related apps might get hidden incorrectly.

---

### 2. UI Test: `hideAllOtherApps()` (Lines 258-289 in MacScreenshotTests.swift)

**When it runs**: DURING test execution, called by `prepareWindowForScreenshot()` at line 225

**Timeline**:
```
T+20s:  Test launches ListAll app
T+23s:  app.launch() completes, app is running
T+24s:  prepareWindowForScreenshot() called
T+24s:    → hideAllOtherApps() called (line 225)
T+24s:    → forceWindowOnScreen() called (line 229)
T+27s:  Screenshot captured
```

**What it does** (Lines 258-289):
```swift
private func hideAllOtherApps() {
    let workspace = NSWorkspace.shared
    let listAllBundleId = "io.github.chmc.ListAllMac"

    let runningApps = workspace.runningApplications.filter { app in
        guard app.bundleIdentifier != listAllBundleId else { return false }
        guard app.bundleIdentifier != "com.apple.finder" else { return false }
        guard app.bundleIdentifier != "com.apple.dock" else { return false }
        guard app.activationPolicy == .regular else { return false }
        return true
    }

    for app in runningApps {
        app.hide()  // ← This is WEAK compared to quit
    }
}
```

**Problems**:
1. **`.hide()` is WEAK**: Apps can unhide themselves
2. **No timing guarantee**: Apps may unhide before screenshot
3. **Redundant with shell script**: Both try to hide the same apps

---

### 3. Screenshot Capture: Window-Only Mode (Line 319 in MacSnapshotHelper.swift)

**CRITICAL FINDING**: The screenshot code captures **ONLY the app window**, not the full screen:

```swift
// Line 319: MacSnapshotHelper.swift
let windowScreenshot = mainWindow.screenshot()
NSLog("📸 Captured app WINDOW screenshot (not full screen)")
```

**This means**:
- Background apps should NOT appear in the screenshot at all
- The screenshot is of `mainWindow` only, not `XCUIScreen.main.screenshot()`
- If background apps ARE appearing, it means:
  - The window is NOT in foreground when captured, OR
  - Another app's window is overlapping ListAll's window, OR
  - ListAll window is partially off-screen

---

### 4. Window Positioning: `forceWindowOnScreen()` (Lines 131-215 in MacScreenshotTests.swift)

**Purpose**: Use AppleScript to force ListAll window to be frontmost and on-screen

**Timeline within prepareWindowForScreenshot()**:
```
T+24.0s: hideAllOtherApps() starts (line 225)
T+24.1s: hideAllOtherApps() completes (1 second sleep at line 286)
T+25.1s: forceWindowOnScreen() starts (line 229)
T+25.2s: AppleScript sets frontmost = true (line 143)
T+25.7s: AppleScript delay 0.5 (line 146)
T+26.7s: AppleScript delay 1 (line 192)
T+27.7s: sleep(2) for window to reposition (line 214)
T+29.7s: forceWindowOnScreen() completes
```

**BUT**: Between lines 229-241, there are THREE activation calls:
```swift
// Line 229: forceWindowOnScreen() - uses AppleScript
forceWindowOnScreen()

// Line 232: NSWorkspace activation
listAllApp.activate(options: [.activateIgnoringOtherApps])

// Line 240: XCUIApplication activation
app.activate()

// Line 243: Then sleep(3) to let everything settle
sleep(3)
```

**Problem**: Multiple activation calls can cause thrashing:
- AppleScript activates app
- Then NSWorkspace activates app AGAIN
- Then XCUIApplication activates app AGAIN
- Apps may be fighting for focus during this 3-second window

---

## Root Causes Identified

### Primary Root Cause: Race Condition

**The shell script runs TOO EARLY**:
```
Shell script hides apps  →  [19+ second gap]  →  Screenshot captured
```

During this gap:
- macOS System Preferences may auto-open for permission requests
- Apps closed by the script may auto-relaunch (e.g., Slack, Discord, etc.)
- Background services may spawn new windows
- System dialogs may appear

### Secondary Root Cause: Weak Hiding in UI Test

**NSRunningApplication.hide() is not reliable**:
- Apps can unhide themselves programmatically
- System dialogs aren't affected by `.hide()`
- Focus changes can cause apps to unhide

**Evidence**: The shell script uses `tell process appName to quit` (line 413) which is STRONGER than `.hide()`, but it runs too early.

### Tertiary Root Cause: Multiple Activation Thrashing

**Three separate activation calls** (lines 229, 236, 240) within 3 seconds can cause:
- Window manager confusion
- Other apps briefly stealing focus
- Screenshot captured during window transition

### Window Capture Should Prevent This

**BUT**: Since screenshot uses `mainWindow.screenshot()` (line 319), background apps SHOULD NOT appear.

**If they ARE appearing**, it means:
1. **ListAll window is NOT frontmost at capture time** (most likely)
2. **Another window is overlapping ListAll** (possible)
3. **Window is partially off-screen** (unlikely, handled by line 165)

---

## Recommended Solutions

### Solution 1: Move hiding logic INTO UI test (BEST)

**Remove shell script hiding entirely**. Instead, make UI test handle hiding:

```swift
override func setUpWithError() throws {
    // FIRST: Hide all other apps BEFORE launching ListAll
    hideAllOtherApps()
    sleep(2)

    // THEN: Setup and launch
    continueAfterFailure = false
    app = XCUIApplication()
    setupSnapshot(app)
}
```

**Why this works**:
- Hiding happens IMMEDIATELY before test starts
- No 19-second gap for apps to reopen
- Single source of truth for app hiding

### Solution 2: Make shell script hiding STRONGER and LATER

**Change shell script to use `osascript` to quit apps AND run IMMEDIATELY before xcodebuild**:

```bash
generate_macos_screenshots() {
    # DON'T hide apps here - too early
    # hide_and_quit_background_apps_macos  # ← REMOVE THIS

    # Run xcodebuild, but inject hiding into test launch
    bundle exec fastlane ios screenshots_macos
}
```

**Then modify Fastfile to hide apps for EACH locale** immediately before test:

```ruby
# In Fastfile, before each xcodebuild call:
system("osascript -e 'tell app \"Safari\" to quit'")  # example
system("osascript -e 'tell app \"Slack\" to quit'")
# ... etc
```

### Solution 3: Reduce activation thrashing

**Change prepareWindowForScreenshot() to use ONLY AppleScript** (most reliable):

```swift
private func prepareWindowForScreenshot() {
    print("🖥️ Preparing window for screenshot...")

    // ONLY use AppleScript - it's the most reliable
    forceWindowOnScreen()

    // Remove NSWorkspace and XCUIApplication activation
    // (they cause thrashing)

    // LONGER delay to ensure window is stable
    sleep(5)

    print("✅ Window prepared for screenshot")
}
```

### Solution 4: Add verification BEFORE screenshot

**In snapshot() function (MacSnapshotHelper.swift), verify window is frontmost**:

```swift
open class func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
    // ... existing code ...

    // VERIFY: Window is actually frontmost before capturing
    guard let app = self.app else { return }
    let mainWindow = app.windows.firstMatch

    // Check if window is hittable (frontmost)
    if !mainWindow.isHittable {
        NSLog("⚠️ WARNING: Window is NOT hittable before screenshot '\(name)'")
        NSLog("⚠️ Attempting to re-activate...")

        // Try one more time to activate
        app.activate()
        sleep(2)

        if !mainWindow.isHittable {
            NSLog("❌ ERROR: Window still not frontmost for '\(name)'")
        }
    }

    // Capture window
    let windowScreenshot = mainWindow.screenshot()
    // ... rest of code ...
}
```

---

## Pattern Matching Issues Found

### ❌ Issue in hide script (lines 427-443)

The second AppleScript block checks for apps to hide, but uses inconsistent patterns:

```applescript
# Line 435-436
if appName does not contain "Xcode" and
   appName does not contain "xctest" and
   appName does not contain "ListAll" then
```

**Missing checks**:
- `XCTest` (capitalized) - not checked
- `xctrunner`/`XCTRunner` - not checked
- `Simulator` - not checked
- `xcodebuild` - not checked

**Recommendation**: Use same comprehensive pattern matching as the quit script (lines 376-408):

```applescript
-- Skip test runners (pattern matching for various test runner names)
if appName contains "xctest" or appName contains "XCTest" or
   appName contains "xctrunner" or appName contains "XCTRunner" then
    set shouldSkip to true
end if

-- Skip xcodebuild
if appName contains "xcodebuild" then
    set shouldSkip to true
end if

-- Skip Simulator
if appName contains "Simulator" then
    set shouldSkip to true
end if
```

---

## Testing Recommendations

### Test 1: Verify timing of app hiding

Add debug logging to track WHEN apps are hidden vs WHEN screenshot is captured:

```bash
# In shell script
hide_and_quit_background_apps_macos() {
    echo "[$(date +%H:%M:%S)] STARTING app hiding"
    # ... existing code ...
    echo "[$(date +%H:%M:%S)] COMPLETED app hiding"
}

generate_macos_screenshots() {
    hide_and_quit_background_apps_macos
    echo "[$(date +%H:%M:%S)] STARTING fastlane"
    bundle exec fastlane ios screenshots_macos
}
```

### Test 2: Verify window state at screenshot time

Modify `MacSnapshotHelper.swift` to log window state:

```swift
open class func snapshot(_ name: String, timeWaitingForIdle timeout: TimeInterval = 20) {
    // ... existing code ...

    // LOG window state
    let mainWindow = app.windows.firstMatch
    NSLog("📊 [SNAPSHOT \(name)] Window state:")
    NSLog("  - exists: \(mainWindow.exists)")
    NSLog("  - isHittable: \(mainWindow.isHittable)")
    NSLog("  - frame: \(mainWindow.frame)")
    NSLog("  - app.state: \(app.state.rawValue)")

    // Capture
    let windowScreenshot = mainWindow.screenshot()
    // ...
}
```

### Test 3: List all visible apps at screenshot time

Add to `MacScreenshotTests.swift`:

```swift
private func logVisibleApps() {
    let workspace = NSWorkspace.shared
    let visibleApps = workspace.runningApplications.filter {
        $0.activationPolicy == .regular && !$0.isHidden
    }

    print("👁️ Visible apps at screenshot time:")
    for app in visibleApps {
        print("  - \(app.localizedName ?? "Unknown") (\(app.bundleIdentifier ?? "no bundle id"))")
    }
}

// Call before snapshot()
logVisibleApps()
snapshot("01_MainWindow")
```

---

## Summary

| Issue | Severity | Location | Fix Priority |
|-------|----------|----------|--------------|
| Race condition (19s gap) | 🔴 CRITICAL | Shell script line 523 | **HIGH** - Move hiding to UI test |
| Weak `.hide()` in UI test | 🟡 MEDIUM | MacScreenshotTests.swift line 281 | **MEDIUM** - Use AppleScript quit |
| Activation thrashing | 🟡 MEDIUM | MacScreenshotTests.swift lines 229-240 | **MEDIUM** - Use single activation |
| Inconsistent pattern matching | 🟢 LOW | Shell script line 435 | **LOW** - Add missing patterns |

**Recommended Action**: Implement **Solution 1** (move hiding logic into UI test) as it eliminates the race condition entirely.
