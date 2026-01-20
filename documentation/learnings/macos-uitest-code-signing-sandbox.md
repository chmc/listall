---
title: macOS XCUITest Requires Code Signing and Runs in Sandbox Container
date: 2025-12-30
severity: HIGH
category: testing
tags: [xcuitest, macos, code-signing, sandbox, fastlane, screenshots]
symptoms:
  - "Application does not have a process ID"
  - XCUITest cannot launch the app
  - Screenshots saved but not found by Fastlane
root_cause: Disabling code signing prevents XCUITest from launching; sandbox container path differs from user home directory
solution: Remove code signing disabling flags; use sandbox container path for screenshot files
files_affected:
  - fastlane/Fastfile
related:
  - macos-uitest-authorization-fix.md
  - macos-xcuitest-list-selection.md
---

## Issue 1: Code Signing Required

XCUITest cannot launch ad-hoc signed apps.

```ruby
# WRONG - breaks XCUITest
xcargs: "CODE_SIGN_IDENTITY='' CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"

# CORRECT - proper signing required
xcargs: "-test-timeouts-enabled YES -default-test-execution-time-allowance 300"
```

## Issue 2: Sandbox Container Path

MacSnapshotHelper runs sandboxed. `NSHomeDirectory()` returns:
```
~/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data/
```

Not:
```
~/
```

### Fix in Fastfile

```ruby
container_base = File.expand_path("~/Library/Containers/io.github.chmc.ListAllMacUITests.xctrunner/Data")
fastlane_cache_dir = File.join(container_base, "Library/Caches/tools.fastlane")
screenshots_cache_dir = File.join(fastlane_cache_dir, "screenshots")
```

Write `language.txt` and `locale.txt` to the container path.

## Key Learnings

1. **Never disable code signing for UI tests**
2. **macOS UI tests run in sandbox containers** - NSHomeDirectory() returns container path
3. **Container bundle ID pattern**: `io.github.chmc.{TestTargetName}.xctrunner`
4. **Debug sandbox issues** by checking NSLog output for actual paths
