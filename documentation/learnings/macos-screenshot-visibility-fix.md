# macOS Screenshot Visibility Fix

## Problem Analysis

Screenshots captured by macOS UI tests show other applications instead of ListAll app.

### Root Cause

**XCUIScreen.main.screenshot() captures the ENTIRE display**, not just the app window. This means:

1. All visible windows from all apps appear in the screenshot
2. Desktop wallpaper is visible
3. Menu bar and Dock (if visible) are captured
4. The ListAll window was either behind other windows or not properly activated

### Evidence

Screenshot at `~/Library/Caches/tools.fastlane/screenshots/Mac-01_MainWindow.png` shows:
- Multiple terminal/code editor windows
- Desktop wallpaper
- **ListAll app NOT visible**

Screenshot dimensions: 3840x1600 (ultrawide display, requires cropping to 16:10)

## Issues Found in Code

### 1. Early Return in forceWindowOnScreen()

**Location**: MacScreenshotTests.swift, line ~143

```swift
let mainWindow = app.windows.firstMatch
if mainWindow.exists && mainWindow.isHittable {
    print("  ✓ Window is visible via XCUIApplication.activate()")
    return  // ← EXITS WITHOUT VERIFYING WINDOW IS FRONTMOST
}
```

**Problem**: Checks if window *exists* and is *hittable*, but NOT if it's **frontmost** (on top of other windows).

**Fix**: Removed early return, always use AppleScript to force window to front.

### 2. No Window Size Verification

**Problem**: The app might launch with a tiny or hidden window that's technically "visible" but not actually shown.

**Fix**: Added AppleScript to ensure minimum window size (800x600).

### 3. No AXRaise Action

**Problem**: Setting frontmost=true doesn't guarantee the window is visually on top.

**Fix**: Added `perform action "AXRaise" of window 1` to explicitly bring window to front.

### 4. Other Apps Not Hidden

**Problem**: macOS screenshot captures ALL visible windows, not just the test app.

**Fix**: Added `hideAllOtherApps()` function to hide all other applications before taking screenshot.

### 5. Insufficient Delays

**Problem**: macOS window management is asynchronous. Window activation and rendering takes time.

**Fix**: Increased delays:
- forceWindowOnScreen(): Now sleeps 2 seconds after AppleScript
- prepareWindowForScreenshot(): Now sleeps 3 seconds after activation
- AppleScript itself has 0.5s and 1s delays for window operations

## Code Changes

### Modified Functions

#### 1. forceWindowOnScreen()

**Changes**:
- Removed early return logic
- Always use AppleScript for reliable window positioning
- Added window size check (minimum 800x600)
- Added AXRaise action to force window to front
- Added delay in AppleScript for frontmost to take effect
- Increased final sleep from 1s to 2s

#### 2. prepareWindowForScreenshot()

**Changes**:
- Added call to hideAllOtherApps() at the start
- Increased final sleep from 2s to 3s

#### 3. hideAllOtherApps() (NEW)

**Purpose**: Hide all other running applications to ensure only ListAll is visible in screenshots.

**Logic**:
- Get all running apps via NSWorkspace
- Filter out ListAll, Finder, and Dock
- Call .hide() on each app
- Sleep 1s to let apps hide

## Testing Instructions

### Before Testing

1. **Close/minimize other apps** manually for first test to verify fix works
2. After fix is verified, the `hideAllOtherApps()` function should handle this automatically

### Run Single Screenshot Test

```bash
cd /Users/aleksi/source/ListAllApp/ListAll

xcodebuild test \
  -project ListAll.xcodeproj \
  -scheme ListAllMac \
  -destination 'platform=macOS' \
  -only-testing:ListAllMacUITests/MacScreenshotTests/testScreenshot01_MainWindow
```

### Verify Screenshot

```bash
# Check screenshot was created
ls -lh ~/Library/Caches/tools.fastlane/screenshots/Mac-01_MainWindow.png

# View screenshot dimensions
sips -g pixelWidth -g pixelHeight ~/Library/Caches/tools.fastlane/screenshots/Mac-01_MainWindow.png

# Open screenshot to visually verify ListAll is visible
open ~/Library/Caches/tools.fastlane/screenshots/Mac-01_MainWindow.png
```

**Expected Result**: Screenshot should show ONLY ListAll app window, with desktop wallpaper in background.

### Run All Screenshot Tests

```bash
xcodebuild test \
  -project ListAll.xcodeproj \
  -scheme ListAllMac \
  -destination 'platform=macOS' \
  -only-testing:ListAllMacUITests/MacScreenshotTests
```

## Expected Behavior After Fix

1. **Before screenshot**: All other apps are hidden automatically
2. **Window activation**: AppleScript forces ListAll to frontmost
3. **Window positioning**: Window is moved on-screen if off-screen
4. **Window sizing**: Window is resized to minimum 800x600 if too small
5. **AXRaise**: Window is explicitly raised to top of window stack
6. **Delays**: Sufficient time for all operations to complete
7. **Screenshot capture**: XCUIScreen captures full display, but only ListAll is visible

## Known Limitations

### 1. Full Screen Capture

`XCUIScreen.main.screenshot()` captures the **entire display**, not just the app window. This means:

- Desktop wallpaper is visible
- Screenshot aspect ratio matches display (3840x1600 on ultrawide)
- Requires post-processing to crop to 16:10 for App Store

**Solution**: The `bundle exec fastlane ios screenshots_macos_normalize` command crops screenshots to 2880x1800.

### 2. Accessibility Permissions

AppleScript window manipulation requires:
- **Accessibility** permission
- **AppleScript** permission

**Impact**: First run may show permission dialogs. Grant permissions when prompted.

### 3. Display Requirements

For best results:
- 16:10 display (e.g., 2880x1800) - perfect for App Store
- 16:9 display (e.g., 3840x2160) - requires cropping
- 21:9 ultrawide (e.g., 3840x1600) - requires cropping (current setup)

### 4. Background Apps May Reappear

Some apps (like Finder) may automatically reappear or resist hiding. The `hideAllOtherApps()` function filters out Finder and Dock to prevent issues.

## Alternative Approaches (Not Implemented)

### Approach 1: Window-Only Screenshot (REJECTED)

**Idea**: Use CGWindowList APIs to capture only ListAll window.

**Pros**:
- No other apps in screenshot
- No desktop wallpaper
- Always correct aspect ratio

**Cons**:
- Requires bridging to Objective-C/CGImage APIs
- More complex implementation
- XCUITest doesn't provide direct access to window handles
- Would need significant refactoring

### Approach 2: Move Window to Empty Space (REJECTED)

**Idea**: Use Mission Control API to move ListAll to empty desktop space.

**Cons**:
- Mission Control API is private/undocumented
- May not work in UI test context
- More complex than hiding other apps

### Approach 3: Disable Desktop Wallpaper (NOT RECOMMENDED)

**Idea**: Temporarily disable desktop wallpaper for clean screenshots.

**Cons**:
- Requires System Preferences access
- May leave system in bad state if test crashes
- Not worth the complexity

## Post-Processing Pipeline

After screenshot tests complete, the normalization process:

1. **Capture**: XCUIScreen captures full display (e.g., 3840x1600)
2. **Normalize**: `fastlane ios screenshots_macos_normalize` crops to 2880x1800
3. **Framing**: Device frames are NOT applied to macOS screenshots (window is the "frame")
4. **Copy**: Screenshots moved to `fastlane/screenshots/mac/[locale]/`

## Troubleshooting

### Problem: Screenshot still shows other apps

**Check**:
1. Verify `hideAllOtherApps()` is being called
2. Check console logs for "Hiding X apps" message
3. Manually minimize other apps and re-run test

### Problem: Window too small or off-screen

**Check**:
1. Verify AppleScript completed successfully (look for "Window positioned on-screen via AppleScript")
2. Check console for AppleScript error messages
3. Manually resize/position window and verify it persists

### Problem: Permission dialogs appear

**Solution**:
1. Grant Accessibility permission to xcodebuild/Xcode
2. Grant AppleScript permission to Terminal (if running via shell)
3. Permissions persist after first grant

### Problem: Screenshot is blank or black

**Check**:
1. Verify app actually launched (check logs)
2. Increase delays if activation timing is issue
3. Check window state logs ("App has X windows")

## References

- Apple XCTest Documentation: https://developer.apple.com/documentation/xctest
- AppleScript Accessibility Reference: https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/
- NSWorkspace Documentation: https://developer.apple.com/documentation/appkit/nsworkspace
- Fastlane Snapshot: https://docs.fastlane.tools/actions/snapshot/

## Files Modified

- `/Users/aleksi/source/ListAllApp/ListAll/ListAllMacUITests/MacScreenshotTests.swift`
  - Modified: `forceWindowOnScreen()`
  - Modified: `prepareWindowForScreenshot()`
  - Added: `hideAllOtherApps()`

## Next Steps

1. Run single screenshot test to verify fix
2. If successful, run full screenshot test suite
3. Verify all 4 screenshots show ListAll app clearly
4. Update CI/CD script if needed to grant permissions
5. Document permission requirements in CI/CD setup guide
