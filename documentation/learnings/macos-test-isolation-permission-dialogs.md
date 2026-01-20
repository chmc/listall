# macOS Test Isolation: Preventing Permission Dialogs

## Problem

Tests were triggering macOS permission dialogs:
- "ListAll would like to access data from other apps"
- iCloud/CloudKit access prompts

This happened because tests directly instantiated production classes that access system resources.

## Root Cause

Direct instantiation of production classes triggers their dependencies:

```swift
// BAD - triggers permission dialogs
let vm = ExportViewModel()

// Dependency chain:
// ExportViewModel()
//   → ExportService()
//     → DataRepository()
//       → CoreDataManager.shared
//         → FileManager.containerURL(forSecurityApplicationGroupIdentifier:)
//         → PERMISSION DIALOG
```

## Solution

### 1. Use Test Helpers for Isolated Instantiation

The project has `TestHelpers.swift` with factory methods that inject test doubles:

```swift
// GOOD - uses isolated dependencies
let vm = TestHelpers.createTestExportViewModel()

// Creates with:
// - TestDataManager (in-memory Core Data)
// - TestDataRepository (no App Groups)
// - ExportService with test dependencies
```

### 2. Skip Integration Tests on Unsigned Builds

For tests that MUST use real system services (CloudKit, AppleScript):

```swift
override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(TestHelpers.shouldSkipAppGroupsTest(),
                  "Skipping: unsigned build would trigger permission dialogs")
    cloudKitService = CloudKitService()
}
```

### 3. Available Test Doubles

| Production Class | Test Double |
|-----------------|-------------|
| `ExportViewModel()` | `TestHelpers.createTestExportViewModel()` |
| `DataManager.shared` | `TestHelpers.createTestDataManager()` |
| `DataRepository()` | `TestDataRepository(dataManager:)` |
| `CoreDataManager.shared` | `TestCoreDataManager()` (in-memory) |
| `CloudKitService()` | `MockCloudKitService` |
| `AppleScriptExecutor` | `MockAppleScriptExecutor` |

## Classes That Trigger System Access

| Class | Triggers | System Resource |
|-------|----------|-----------------|
| `CoreDataManager.shared` | App Groups | `containerURL(forSecurityApplicationGroupIdentifier:)` |
| `DataManager.shared` | App Groups | via CoreDataManager |
| `DataRepository()` | App Groups | via CoreDataManager |
| `ExportViewModel()` | App Groups | via ExportService → DataRepository |
| `CloudKitService()` | iCloud | CloudKit container access |
| `RealAppleScriptExecutor` | Automation | NSAppleScript execution |

## Key Learnings

1. **Lazy initialization doesn't help**: Even with `lazy var`, once the code path is executed during tests, system access is triggered.

2. **Test entitlements are minimal**: `ListAllMacTests.entitlements` deliberately omits App Groups to catch isolation issues early.

3. **Check `TestHelpers.isUnsignedTestBuild`**: Use this to conditionally skip tests that require signed entitlements.

4. **Use dependency injection**: All ViewModels and Services should support constructor injection for testing.

## Files Modified

- `ListAllMacTests/ListAllMacTests.swift`:
  - Replaced 23 `ExportViewModel()` → `TestHelpers.createTestExportViewModel()`
  - Added skip condition to `CloudKitServiceMacTests`

- `ListAllMacTests/MacFinalIntegrationTests.swift`:
  - Added skip conditions to CloudKit instantiation tests

## Date

January 20, 2026
