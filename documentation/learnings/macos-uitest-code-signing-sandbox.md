# macOS XCUITest Code Signing and Sandbox Path Issues

## Date
2025-12-30

## Problem Summary
macOS screenshot generation via `bundle exec fastlane ios screenshots_macos` was failing with two related issues:
1. XCUITest could not launch the app ("Application does not have a process ID")
2. Screenshots were saved but not found by Fastlane

## Root Causes

### Issue 1: Code Signing Required for XCUITest
When the Fastfile used these xcode build arguments:
```ruby
xcargs: "CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO ..."
```

The app was built with ad-hoc signing, which XCUITest cannot launch. The error message was:
```
Application 'io.github.chmc.ListAllMac' does not have a process ID
```

**Solution**: Remove the code signing disabling flags. XCUITest requires properly signed apps:
```ruby
xcargs: "-test-timeouts-enabled YES -default-test-execution-time-allowance 300 -maximum-test-execution-time-allowance 600"
```

### Issue 2: Sandbox Container Path Mismatch
MacSnapshotHelper runs inside a sandboxed container, so `NSHomeDirectory()` returns:
```
/Users/aleksi/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data/
```

Not the actual user home directory:
```
/Users/aleksi/
```

This caused screenshots to be saved to:
```
~/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data/Library/Caches/tools.fastlane/screenshots/
```

But Fastlane was looking in:
```
~/Library/Caches/tools.fastlane/screenshots/
```

**Solution**: Update Fastfile to use the sandboxed container path:
```ruby
container_base = File.expand_path("~/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data")
fastlane_cache_dir = File.join(container_base, "Library/Caches/tools.fastlane")
screenshots_cache_dir = File.join(fastlane_cache_dir, "screenshots")
```

Also write `language.txt` and `locale.txt` to the container path so MacSnapshotHelper can read them.

## Files Modified
- `fastlane/Fastfile` - Fixed code signing flags and sandbox paths in `screenshots_macos` lane

## Key Learnings
1. **XCUITest requires properly signed apps** - Never disable code signing for UI tests
2. **macOS UI tests run in sandbox containers** - `NSHomeDirectory()` returns the container path, not the real home
3. **Container bundle ID pattern**: `io.github.chmc.{TestTargetName}.xctrunner`
4. **Debug sandbox issues** by checking NSLog output for actual paths used

## Verification
After fix:
- Tests: 5/5 passed
- Screenshots: 8 captured (4 per locale)
- Both en-US and fi locales working

## Related Issues
- This is related to but different from the macOS Tahoe window creation issues documented in `macos-tahoe-window-creation-xcode.md`
