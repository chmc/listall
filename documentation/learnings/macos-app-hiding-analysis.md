---
title: macOS Screenshot App Hiding Timing Fix
date: 2024-12-19
severity: HIGH
category: macos
tags: [screenshots, app-hiding, automation, timing, applescript, nsworkspace]
symptoms:
  - Other apps visible in macOS screenshots
  - Repeated app hiding during test execution (4 times)
  - Apps pop back up between screenshots
  - Extra 8+ second delay from repeated hiding
root_cause: Shell script tried to hide apps before ListAll existed; tests repeatedly hid apps during execution
solution: Shell script quits apps BEFORE tests; UI tests only activate ListAll without hiding logic
files_affected:
  - .github/scripts/generate-screenshots-local.sh
  - ListAll/ListAllMacUITests/MacScreenshotTests.swift
  - fastlane/Fastfile
related:
  - macos-applescript-analysis.md
---

## Original Flow (Broken)

1. **Shell script** called `hide_background_apps_macos()` BEFORE launching fastlane
   - ListAll doesn't exist yet - hasn't been launched
   - AppleScript tried to hide all apps EXCEPT "ListAll", but ListAll wasn't running
   - Result: Ineffective - other apps remained visible

2. **UI Tests** called `hideOtherApplications()` during EACH test (4 times)
   - Happened AFTER ListAll launched, but DURING test execution
   - Used `NSWorkspace.runningApplications` and `.hide()`
   - Result: Repeated overhead - apps hidden 4 times
   - Side effect: Apps could pop back up between screenshots

## Fixed Flow

1. **Shell script** (BEFORE launching tests):
   - Calls `hide_and_quit_background_apps_macos()`
   - **Quits** non-essential apps completely (more reliable than hiding)
   - **Hides** remaining system apps that can't be quit
   - **Minimizes** Finder windows to clear desktop
   - Result: Clean slate before ListAll launches

2. **UI Tests** (DURING test execution):
   - Calls `prepareWindowForScreenshot()` only to **activate** ListAll
   - Does NOT try to hide other apps (already done by shell script)
   - Uses `NSWorkspace.activate()` to bring ListAll to foreground
   - Result: Fast and simple - just activate, no repeated hiding

## Shell Script 3-Step Cleanup

```bash
# STEP 1: Quit non-essential applications
osascript <<'EOF'
tell application "System Events"
    set appList to name of every process whose background only is false
    repeat with appName in appList
        if appName is not in {"Finder", "SystemUIServer", "Dock", "Terminal", "Xcode"} then
            try
                tell process appName to quit
            end try
        end if
    end repeat
end tell
EOF

# STEP 2: Hide remaining visible apps
osascript <<'EOF'
tell application "System Events"
    set visible of every process whose visible is true and name is not in {"Finder", "SystemUIServer", "Dock"} to false
end tell
EOF

# STEP 3: Minimize Finder windows
osascript <<'EOF'
tell application "Finder"
    set miniaturized of every window to true
end tell
EOF
```

## Simplified UI Test

```swift
private func prepareWindowForScreenshot() {
    if let listAllApp = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == "io.github.chmc.ListAllMac"
    }) {
        listAllApp.activate(options: [.activateIgnoringOtherApps])
    }
    app.activate()
    sleep(2)
}
```

## Benefits

1. **Correct timing** - Apps closed/hidden BEFORE ListAll launches
2. **More reliable** - Quitting apps is more permanent than hiding
3. **Faster tests** - No repeated app hiding (saves 8+ seconds)
4. **Cleaner screenshots** - Desktop completely clear
5. **Simpler code** - Tests don't need complex app management logic
6. **Better separation** - Shell handles environment, tests handle app interaction

## Verification

```bash
.github/scripts/generate-screenshots-local.sh macos
```

Expected:
- Shell script closes/hides all apps
- Desktop becomes clear
- ListAll is only visible app in screenshots
- All 4 screenshots generated successfully

## Notes

- Only affects **local** screenshot generation, not CI/CD
- CI/CD environments already have clean desktops (GitHub Actions runners)
- AppleScript requires macOS
- If AppleScript fails, script continues with warning (graceful degradation)
- Test runner and Xcode explicitly skipped to prevent breaking test environment

## Optional Enhancements

If screenshots still show clutter:
- Enable Do Not Disturb mode
- Hide Dock: `osascript -e 'tell application "System Events" to set autohide of dock preferences to true'`
- Set solid color wallpaper
