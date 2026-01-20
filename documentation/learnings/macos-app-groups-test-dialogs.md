---
title: macOS App Groups Permission Dialogs During Tests
date: 2026-01-20
severity: HIGH
category: macos
tags: [app-groups, testing, permission-dialogs, entitlements, sandbox]
symptoms: ["ListAll would like to access data from other apps dialog", "xcodebuild reports TEST FAILED despite passing tests"]
root_cause: macOS prompts for App Groups access based on entitlements even with guarded code
solution: Multi-layer defense - code guards, separate debug entitlements, minimal test entitlements
files_affected: [ListAll/Utils/LocalizationManager.swift, ListAllMac/ListAllMacApp.swift, ListAllMac/ListAllMac.Debug.entitlements, ListAllMacTests/ListAllMacTests.entitlements]
related: [macos-test-permission-fix.md, macos-test-isolation-permission-dialogs.md]
---

## Problem

macOS permission dialog appears during unit tests even with properly guarded code because:
1. Test target uses TEST_HOST to run within app context
2. App is code-signed with App Groups entitlements
3. macOS prompts based on entitlements alone

## Solution: Multi-Layer Defense

### 1. Code-Level Guards

```swift
// LocalizationManager.swift
let isUnitTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil && !isUITesting
if !isUITesting && !isUnitTesting, let sharedDefaults = UserDefaults(suiteName: "...") {
    // Only access App Groups in production
}
```

### 2. Separate Debug Entitlements

`ListAllMac.Debug.entitlements` without App Groups or iCloud:
- Debug builds don't include App Groups entitlements
- Release builds retain full entitlements

### 3. Minimal Test Target Entitlements

`ListAllMacTests.entitlements` has minimal sandbox permissions without App Groups.

### 4. App Initialization Guards

- CoreDataManager uses `/dev/null` SQLite store in test mode
- ListAllMacApp shows minimal "Unit Test Mode" view
- Uses lazy DataManagerWrapper to defer singleton access

## Important Notes

- Tests still pass - dialog doesn't block execution
- xcodebuild may report "TEST FAILED" cosmetically when dialog appears
- Click "Allow" once to authorize; dialog should not reappear
- TCC reset if needed: `tccutil reset All io.github.chmc.ListAll`
- TEST_HOST required for `@testable import ListAll` access
