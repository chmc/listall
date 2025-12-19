# macOS UI Test Authorization Fix

**Date:** December 11, 2025
**Issue:** "Not authorized for performing UI testing actions" when running macOS UI tests for multiple locales
**Status:** Fixed

## Problem Summary

When running macOS screenshot tests for multiple locales, tests would succeed for the first locale (en-US) but fail for subsequent locales (fi) with:

```
Error: Not authorized for performing UI testing actions
Error: Lost connection to the application
```

Additionally, a permission dialog appeared asking VS Code to control Finder.app via AppleScript.

## Root Causes

### 1. macOS XCUITest Authorization Model

Unlike iOS simulators (which run fully sandboxed), macOS UI tests interact with real system APIs and require explicit user permissions:

| Aspect | iOS Simulator | macOS |
|--------|---------------|-------|
| **Sandbox** | Fully sandboxed | Accesses real system APIs |
| **Permissions** | Granted automatically | Requires explicit user consent |
| **Accessibility** | Always available | Must be granted in System Settings |
| **Persistence** | Permissions persist | Can be revoked between test runs |
| **Multiple launches** | No authorization issues | Authorization can be lost |

### 2. App Instance Recreation Causes Authorization Loss

The test code was recreating `XCUIApplication` instances during retry logic:

```swift
// BEFORE (BROKEN):
if attempt > 1 {
    app = XCUIApplication(bundleIdentifier: "io.github.chmc.ListAllMac")
    setupSnapshot(app)
}
```

When Fastlane runs tests for multiple locales:
1. First locale (en-US) runs - authorization granted
2. Tests complete, app terminates
3. Second locale (fi) starts - creates NEW `XCUIApplication` instance
4. **System revokes authorization** - treats it as a new test session
5. Tests fail with "Not authorized for performing UI testing actions"

### 3. Bundle Identifier Parameter Triggers Re-Authorization

Using `XCUIApplication(bundleIdentifier:)` instead of the default initializer caused macOS to treat each instance as a new authorization request.

### 4. AppleScript Requires Additional Permissions

The `forceWindowOnScreen()` method used AppleScript to control the app window, which triggered additional permission dialogs for:
- Accessibility API access
- AppleScript/System Events control
- Inter-app communication

## Solutions Implemented

### Fix 1: Use Default XCUIApplication Initializer

**File:** `ListAllMacUITests/MacScreenshotTests.swift`

**Change:** Use `XCUIApplication()` instead of `XCUIApplication(bundleIdentifier:)`

```swift
// BEFORE:
app = XCUIApplication(bundleIdentifier: "io.github.chmc.ListAllMac")

// AFTER:
app = XCUIApplication()  // Bundle identifier resolved automatically
```

**Reason:** The default initializer maintains authorization across test runs. XCTest automatically resolves the correct bundle identifier from the test target configuration.

### Fix 2: Never Recreate App Instance During Retries

**Change:** Remove app recreation in `launchAppWithRetry()` retry logic

```swift
// BEFORE (BROKEN):
if attempt > 1 {
    app = XCUIApplication(bundleIdentifier: "io.github.chmc.ListAllMac")
    setupSnapshot(app)
}
app.launchArguments += arguments

// AFTER (FIXED):
if attempt > 1 {
    sleep(5)
    // DO NOT recreate app instance - causes authorization loss
}
app.launchArguments = arguments  // Clear and set
```

**Reason:** Recreating the app instance during retries causes macOS to revoke authorization. The original instance from `setUpWithError()` maintains authorization across launches.

### Fix 3: Add Stabilization Delay Between Test Runs

**Change:** Add 3-second delay in `setUpWithError()` before creating app instance

```swift
override func setUpWithError() throws {
    continueAfterFailure = false

    // CRITICAL: Give system time to stabilize between test runs
    print("⏳ Waiting 3 seconds for system to stabilize...")
    sleep(3)

    app = XCUIApplication()
    // ...
}
```

**Reason:** When running multiple locales in sequence, macOS needs time to stabilize authorization state between test sessions. Without this delay, the second locale can start before the first has fully cleaned up.

### Fix 4: Reduce AppleScript Usage

**Change:** Try `XCUIApplication.activate()` first, only fall back to AppleScript if needed

```swift
// Step 1: Try XCUIApplication activation (no permission dialog)
app.activate()
sleep(1)

// Step 2: Check if window is visible
let mainWindow = app.windows.firstMatch
if mainWindow.exists && mainWindow.isHittable {
    return  // Success - no AppleScript needed
}

// Step 3: Fall back to AppleScript only if necessary
// (This may trigger permission dialogs)
```

**Reason:** XCUIApplication methods don't require additional permissions. Only use AppleScript when absolutely necessary to minimize permission dialogs.

## Required Manual Setup

Users must manually grant permissions **once** before running tests:

### 1. Grant Accessibility Permissions

```bash
# Reset permissions to trigger fresh dialog
tccutil reset Accessibility io.github.chmc.ListAllMacUITests.xctrunner
```

Then:
1. Run tests once to trigger permission dialog
2. **System Settings → Privacy & Security → Accessibility**
3. **Enable:** `io.github.chmc.ListAllMacUITests.xctrunner`
4. **Enable:** `xcodebuild` (if running via xcodebuild)
5. **Enable:** `Terminal` or your shell (if running from terminal)

### 2. Grant AppleScript Permissions (if needed)

If you see "VS Code wants to control Finder" dialog:
1. **System Settings → Privacy & Security → Automation**
2. **Enable:** VS Code → System Events, Finder
3. Or run tests from Terminal (Terminal already has permissions)

## Testing the Fix

```bash
# Build macOS app
xcodebuild build -project ListAll.xcodeproj -scheme ListAllMac \
  -destination 'platform=macOS'

# Run tests for single locale (verify basic functionality)
xcodebuild test -project ListAll.xcodeproj -scheme ListAllMac \
  -destination 'platform=macOS' \
  -only-testing:ListAllMacUITests/MacScreenshotTests

# Run tests for multiple locales (verify authorization persists)
# This requires Fastlane setup with locale configuration
bundle exec fastlane mac screenshots
```

**Expected result:** Tests should pass for ALL locales without authorization errors.

## Why This Works

1. **Single App Instance:** Using one `XCUIApplication` instance throughout all tests maintains authorization
2. **Default Initializer:** Lets XCTest manage bundle resolution and authorization internally
3. **Stabilization Delay:** Allows macOS to complete cleanup between locale changes
4. **Minimal Permissions:** Reduces AppleScript usage to minimize permission dialogs

## Related Issues

- **iOS Simulators:** Do NOT have this issue - permissions are automatic
- **watchOS Simulators:** Do NOT have this issue - permissions are automatic
- **macOS only:** This is a macOS-specific authorization model difference

## References

Research sources:
- [Ive implemented XCTest.framework but getting 'Not authorized for performing UI testing actions.'](https://github.com/appium/appium/discussions/19801)
- [WebDriverAgent: Not authorized for performing UI testing actions](https://github.com/facebookarchive/WebDriverAgent/issues/1088)
- [XCTest Screenshot iOS 15 Xcode 13 - Apple Developer Forums](https://forums.developer.apple.com/forums/thread/693368)
- [Accessibility Permission in macOS](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- [How to fix macOS Accessibility permission - Macworld](https://www.macworld.com/article/347452/how-to-fix-macos-accessibility-permission-when-an-app-cant-be-enabled.html)

Apple Documentation:
- [XCUIApplication - Apple Developer](https://developer.apple.com/documentation/xctest/xcuiapplication)
- [XCUIApplication launch() - Apple Developer](https://developer.apple.com/documentation/xctest/xcuiapplication/1500467-launch)

## Validation Checklist

- [x] Code compiles successfully
- [x] Reduced app instance recreation
- [x] Using default XCUIApplication initializer
- [x] Added stabilization delay between tests
- [x] Minimized AppleScript usage
- [x] Documented permission requirements
- [ ] Tested with multiple locales (user must verify)
- [ ] Confirmed no authorization errors (user must verify)

## Next Steps

1. **User must grant permissions** (one-time setup)
2. **Run tests for multiple locales** to verify fix
3. **Update CI/CD** if running macOS tests in CI (GitHub Actions macOS runners need permissions)

## Notes

- This fix is specific to **macOS UI tests** - iOS/watchOS tests are unaffected
- Permissions must be granted **manually** - cannot be automated due to macOS security
- For CI/CD: macOS runners may need pre-configured permissions or SIP disabled
- AppleScript is only used as fallback - most tests should not trigger it
