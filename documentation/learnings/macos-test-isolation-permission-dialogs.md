---
title: macOS Test Isolation - Preventing Permission Dialogs
date: 2026-01-20
severity: HIGH
category: macos
tags: [testing, permission-dialogs, app-groups, dependency-injection, test-isolation]
symptoms: ["ListAll would like to access data from other apps dialog", "iCloud/CloudKit access prompts during tests"]
root_cause: Direct instantiation of production classes triggers App Groups and iCloud access
solution: Use TestHelpers factory methods that inject test doubles with in-memory stores
files_affected: [ListAllMacTests/ListAllMacTests.swift, ListAllMacTests/MacFinalIntegrationTests.swift]
related: [macos-test-permission-fix.md, macos-app-groups-test-dialogs.md]
---

## Problem

Tests trigger macOS permission dialogs when directly instantiating production classes that access system resources.

## Dependency Chain That Triggers Dialogs

```
ExportViewModel()
  -> ExportService()
    -> DataRepository()
      -> CoreDataManager.shared
        -> FileManager.containerURL(forSecurityApplicationGroupIdentifier:)
        -> PERMISSION DIALOG
```

## Solution

### 1. Use TestHelpers Factory Methods

```swift
// BAD - triggers permission dialogs
let vm = ExportViewModel()

// GOOD - uses isolated dependencies
let vm = TestHelpers.createTestExportViewModel()
```

### 2. Skip Integration Tests on Unsigned Builds

```swift
override func setUpWithError() throws {
    try XCTSkipIf(TestHelpers.shouldSkipAppGroupsTest(),
                  "Skipping: unsigned build would trigger permission dialogs")
}
```

### 3. Available Test Doubles

| Production Class | Test Double |
|-----------------|-------------|
| `ExportViewModel()` | `TestHelpers.createTestExportViewModel()` |
| `DataManager.shared` | `TestHelpers.createTestDataManager()` |
| `CoreDataManager.shared` | `TestCoreDataManager()` (in-memory) |
| `CloudKitService()` | `MockCloudKitService` |

## Classes That Trigger System Access

| Class | System Resource |
|-------|-----------------|
| `CoreDataManager.shared` | App Groups container |
| `CloudKitService()` | iCloud container |
| `RealAppleScriptExecutor` | Automation permissions |

## Key Points

- Lazy initialization does not help - code path execution still triggers access
- `ListAllMacTests.entitlements` deliberately omits App Groups to catch issues early
- Use `TestHelpers.isUnsignedTestBuild` to conditionally skip tests
- All ViewModels/Services should support constructor injection
