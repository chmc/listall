---
title: macOS Screenshot Localization - Finnish Screenshots Show English
date: 2025-12-31
severity: HIGH
category: macos
tags: [localization, xcuitest, sandbox, fastlane, launch-arguments]
symptoms: [Finnish screenshots showing English UI, locale files not found, wrong language in screenshots]
root_cause: XCUITest runner is sandboxed - NSHomeDirectory() returns container path not real HOME; launch arguments being overwritten instead of appended
solution: Write locale files to container path; append launch arguments instead of replacing
files_affected:
  - fastlane/Fastfile
  - ListAll/ListAllMacUITests/MacScreenshotTests.swift
  - ListAll/ListAll/Utils/LocalizationManager.swift
related:
  - macos-screenshot-generation.md
---

## Problem

macOS Finnish screenshots displayed English text despite Finnish translations existing and Fastfile correctly iterating through locales.

## Root Causes

### 1. Wrong Cache Path for Language Files

```ruby
# Fastfile wrote to real HOME
~/Library/Caches/tools.fastlane/

# MacSnapshotHelper read from sandboxed container
~/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data/Library/Caches/tools.fastlane/
```

**Fix:**
```ruby
container_base = File.expand_path("~/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data")
container_cache_dir = File.join(container_base, "Library/Caches/tools.fastlane")
File.write(File.join(container_cache_dir, "language.txt"), language_code)
File.write(File.join(container_cache_dir, "locale.txt"), locale)
```

### 2. Launch Arguments Overwritten

```swift
// BAD: Overwrites -AppleLanguages set by MacSnapshotHelper
app.launchArguments = arguments

// GOOD: Preserves language arguments
let baseArguments = app.launchArguments
app.launchArguments = baseArguments + arguments
```

### 3. Fallback Language Detection

Added fallback to parse `-AppleLanguages` directly from `ProcessInfo.processInfo.arguments`.

## Key Learnings

1. **macOS XCUITest is sandboxed** - `NSHomeDirectory()` returns container path
2. **Always APPEND launch arguments** - never replace, to preserve locale settings
3. **Foundation argument parsing unreliable** - implement fallback parsing
4. **Debug cache paths** - verify both write and read locations

## Verification

After fix, screenshot MD5 hashes differ between locales:
- en-US: English test data
- fi: Finnish test data ("Ruokaostokset", "Maito", etc.)
