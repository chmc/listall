# macOS Screenshot Localization Fix

**Date:** 2025-12-31
**Issue:** macOS Finnish screenshots were showing English UI/data instead of Finnish
**Status:** FIXED

## Problem Description

macOS screenshots for Finnish locale (fi) were displaying English text and data, despite Finnish translations existing in the app and Fastfile correctly iterating through locales.

## Root Causes (Multiple Issues)

### 1. Incorrect Cache Path for Language Files

**Issue:** Fastfile was writing `language.txt` and `locale.txt` to the wrong path.

- **Fastfile wrote to:** `~/Library/Caches/tools.fastlane/` (real HOME directory)
- **MacSnapshotHelper read from:** Container path `~/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data/Library/Caches/tools.fastlane/`

On macOS, XCUITest runners are sandboxed. `NSHomeDirectory()` in the test runner returns the **container path**, not the real home directory.

**Fix:** Updated `fastlane/Fastfile` to write to the container path:
```ruby
# CRITICAL: macOS XCUITest runner is sandboxed
container_base = File.expand_path("~/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data")
container_cache_dir = File.join(container_base, "Library/Caches/tools.fastlane")
File.write(File.join(container_cache_dir, "language.txt"), language_code)
File.write(File.join(container_cache_dir, "locale.txt"), locale)
```

### 2. Launch Arguments Being Overwritten

**Issue:** In `MacScreenshotTests.swift`, `launchAppWithRetry()` was **replacing** launch arguments instead of **appending**:

```swift
// BAD: This OVERWROTE the -AppleLanguages set by MacSnapshotHelper!
app.launchArguments = arguments
```

MacSnapshotHelper.setupSnapshot() sets `-AppleLanguages (fi)` but then the test method reset all arguments to just `["UITEST_MODE"]`.

**Fix:** Changed to append to existing arguments:
```swift
// GOOD: Preserve MacSnapshotHelper's language arguments
let baseArguments = app.launchArguments
app.launchArguments = baseArguments + arguments
```

### 3. Fallback Language Detection (Enhancement)

**Enhancement:** Added fallback to parse `-AppleLanguages` directly from `ProcessInfo.processInfo.arguments` in `LocalizationManager.swift`, in case Foundation doesn't automatically map launch arguments to UserDefaults:

```swift
if let appleLanguagesIndex = arguments.firstIndex(of: "-AppleLanguages"),
   appleLanguagesIndex + 1 < arguments.count {
    let languageArg = arguments[appleLanguagesIndex + 1]
    let cleanedArg = languageArg.trimmingCharacters(in: CharacterSet(charactersIn: "()\"'"))
    // Use cleanedArg for language detection
}
```

## Files Modified

1. **fastlane/Fastfile** (line ~3780-3830)
   - Write language/locale files to container path
   - Added debug logging

2. **ListAll/ListAllMacUITests/MacScreenshotTests.swift** (line ~79-95)
   - Changed from `app.launchArguments = arguments` to `app.launchArguments = baseArguments + arguments`
   - Preserve MacSnapshotHelper's language settings

3. **ListAll/ListAll/Utils/LocalizationManager.swift** (line ~62-110)
   - Added verbose logging for debugging
   - Added fallback to parse ProcessInfo.arguments directly

## Key Learnings

1. **macOS XCUITest Sandboxing:** Unlike iOS simulators, macOS UI tests run in a sandboxed container. `NSHomeDirectory()` returns the container path, not the real HOME.

2. **Preserve Launch Arguments:** When adding test-specific launch arguments, always APPEND to existing arguments rather than replacing them, to preserve locale settings from snapshot helpers.

3. **Foundation Argument Parsing:** While Foundation typically auto-parses `-Key Value` launch arguments to UserDefaults, this isn't always reliable. Implement fallback parsing as a safety measure.

4. **Debug Cache Paths:** When troubleshooting locale issues, verify both:
   - Where Fastfile/scripts write configuration files
   - Where the app/test runner reads them from (check NSHomeDirectory() output)

## Verification

After fixes, screenshot MD5 hashes are different between locales:
- en-US screenshots show English test data
- fi screenshots show Finnish test data ("Ruokaostokset", "Maito", etc.)
