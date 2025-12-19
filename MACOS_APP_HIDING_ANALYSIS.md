# macOS App Hiding Analysis and Fix

## Problem Identified

The macOS screenshot generation had a **timing issue** with app hiding logic:

### Original Flow (Broken)
1. **Shell script** (`generate-screenshots-local.sh:441`):
   - Called `hide_background_apps_macos()` BEFORE launching fastlane
   - At this point, **ListAll doesn't exist yet** - it hasn't been launched
   - AppleScript tried to hide all apps EXCEPT "ListAll", but ListAll wasn't running
   - Result: **Ineffective** - other apps remained visible

2. **UI Tests** (`MacScreenshotTests.swift:176`):
   - Called `hideOtherApplications()` during EACH test (4 times)
   - Happened AFTER ListAll launched, but DURING test execution
   - Used `NSWorkspace.runningApplications` and `.hide()`
   - Result: **Repeated overhead** - apps hidden 4 times, causing delays
   - Side effect: Apps could pop back up between screenshots

### Root Cause
**Wrong order**: Shell script tried to hide apps before ListAll existed, then tests repeatedly hid apps during execution.

---

## Solution Implemented

### New Flow (Fixed)
1. **Shell script** (BEFORE launching tests):
   - Calls `hide_and_quit_background_apps_macos()`
   - **Quits** non-essential apps completely (more reliable than hiding)
   - **Hides** remaining system apps that can't be quit
   - **Minimizes** Finder windows to clear desktop
   - Result: **Clean slate** - desktop is empty before ListAll launches

2. **UI Tests** (DURING test execution):
   - Calls `prepareWindowForScreenshot()` only to **activate** ListAll
   - Does NOT try to hide other apps (already done by shell script)
   - Uses `NSWorkspace.activate()` to bring ListAll to foreground
   - Result: **Fast and simple** - just activate, no repeated hiding

---

## Code Changes

### 1. Shell Script: `/Users/aleksi/source/ListAllApp/.github/scripts/generate-screenshots-local.sh`

**Renamed function** from `hide_background_apps_macos()` to `hide_and_quit_background_apps_macos()`

**Enhanced logic** with 3-step cleanup:

```bash
# STEP 1: Quit non-essential applications completely
osascript <<'EOF'
tell application "System Events"
    set appList to name of every process whose background only is false
    repeat with appName in appList
        -- Skip essential apps: Finder, SystemUIServer, Dock, Terminal, Xcode, xctrunner, XCTestDriver
        if appName is not in {"Finder", "SystemUIServer", "Dock", "Terminal", "Xcode", ...} then
            try
                tell process appName to quit
            end try
        end if
    end repeat
end tell
EOF

# STEP 2: Hide remaining visible apps (for system apps that refused to quit)
osascript <<'EOF'
tell application "System Events"
    set visible of every process whose visible is true and name is not in {"Finder", "SystemUIServer", "Dock"} to false
end tell
EOF

# STEP 3: Minimize Finder windows to clear desktop
osascript <<'EOF'
tell application "Finder"
    set miniaturized of every window to true
end tell
EOF
```

**Key improvements:**
- **Quits apps** instead of just hiding them (more reliable)
- **Skips essential system processes** to prevent system instability
- **Clears Finder windows** to ensure clean desktop
- **Runs BEFORE ListAll launches** - creates clean environment

---

### 2. UI Tests: `/Users/aleksi/source/ListAllApp/ListAll/ListAllMacUITests/MacScreenshotTests.swift`

**Removed** the `hideOtherApplications()` function entirely (no longer needed).

**Simplified** `prepareWindowForScreenshot()` to ONLY activate ListAll:

```swift
private func prepareWindowForScreenshot() {
    print("🖥️ Preparing window for screenshot...")

    // Ensure our app is frontmost and visible
    // Use NSWorkspace for stronger activation that ignores other apps
    if let listAllApp = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == "io.github.chmc.ListAllMac"
    }) {
        listAllApp.activate(options: [.activateIgnoringOtherApps])
        print("  ✓ Activated ListAll via NSWorkspace")
    }

    // Also use XCUIApplication's activate for good measure
    app.activate()

    // Brief delay to let activation complete
    sleep(2)

    print("✅ Window prepared for screenshot (app activated)")
    print("ℹ️  Desktop should be clear from shell script pre-processing")
}
```

**Key improvements:**
- **No hiding logic** - relies on shell script's cleanup
- **Only activates ListAll** - brings app to foreground
- **Runs once per test** - not repeatedly for each screenshot
- **Faster execution** - removed 2-second delay per app hiding operation

---

## Benefits of New Approach

1. **Correct timing**: Apps are closed/hidden BEFORE ListAll launches
2. **More reliable**: Quitting apps is more permanent than hiding
3. **Faster tests**: No repeated app hiding during test execution (saves 8+ seconds)
4. **Cleaner screenshots**: Desktop is completely clear, not just hidden
5. **Simpler code**: Tests don't need complex app management logic
6. **Better separation**: Shell script handles environment, tests handle app interaction

---

## Testing Recommendations

### Verify the fix:
```bash
# Generate macOS screenshots locally
.github/scripts/generate-screenshots-local.sh macos
```

### Expected behavior:
1. Shell script closes/hides all apps (you'll see apps quit)
2. Desktop becomes clear (empty wallpaper)
3. Fastlane launches ListAll
4. Tests run with ListAll as the ONLY visible app
5. Screenshots show clean desktop with only ListAll

### Verification checklist:
- [ ] Shell script successfully closes non-essential apps
- [ ] Desktop is clear before tests run
- [ ] ListAll is the only visible app in screenshots
- [ ] No other app windows or menu bars visible in screenshots
- [ ] All 4 screenshots generated successfully
- [ ] Screenshots pass validation (2880x1800 at 16:10 aspect ratio)

---

## Related Files

- Shell script: `.github/scripts/generate-screenshots-local.sh`
- UI tests: `ListAll/ListAllMacUITests/MacScreenshotTests.swift`
- Fastlane lane: `fastlane/Fastfile` (screenshots_macos lane)

---

## Notes

- This fix only affects **local** screenshot generation, not CI/CD
- CI/CD environments already have clean desktops (GitHub Actions runners)
- The shell script uses AppleScript, which requires macOS
- If AppleScript fails, script continues with warning (graceful degradation)
- Test runner and Xcode are explicitly skipped to prevent breaking the test environment

---

## Further Improvements (Optional)

If screenshots still show clutter, consider:

1. **Enable "Do Not Disturb"** mode:
   ```bash
   # Disable notifications during screenshot generation
   ```

2. **Hide Dock**:
   ```bash
   osascript -e 'tell application "System Events" to set autohide of dock preferences to true'
   ```

3. **Hide menu bar** (macOS 13+):
   ```bash
   defaults write NSGlobalDomain _HIHideMenuBar -bool true
   killall SystemUIServer
   ```

4. **Set desktop wallpaper** to solid color:
   ```bash
   osascript -e 'tell application "System Events" to set picture of every desktop to "/System/Library/Desktop Pictures/Solid Colors/Black.png"'
   ```

These are not implemented yet to avoid system-level changes, but can be added if needed.
