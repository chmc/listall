---
name: test-isolation
description: Test isolation patterns to prevent permission dialogs on macOS. Use when tests trigger system access or when debugging permission issues.
---

# macOS Test Isolation

## The Problem

Direct instantiation of production classes triggers system resource access:
```swift
// BAD - triggers permission dialogs
let vm = ExportViewModel()
// Chain: ExportViewModel → ExportService → DataRepository → CoreDataManager.shared
//        → App Groups access → PERMISSION DIALOG
```

## Solution: Use TestHelpers

Always use `TestHelpers` factory methods instead of direct instantiation:

```swift
// GOOD - uses isolated dependencies
let vm = TestHelpers.createTestExportViewModel()
let dataManager = TestHelpers.createTestDataManager()
let mainViewModel = TestHelpers.createTestMainViewModel()
```

## Class Mapping

| Production Class | Test Alternative |
|-----------------|------------------|
| `ExportViewModel()` | `TestHelpers.createTestExportViewModel()` |
| `DataManager.shared` | `TestHelpers.createTestDataManager()` |
| `DataRepository()` | `TestDataRepository(dataManager:)` |
| `CoreDataManager.shared` | `TestCoreDataManager()` (in-memory) |
| `CloudKitService()` | `MockCloudKitService` or skip test |
| `AppleScriptExecutor` | `MockAppleScriptExecutor` |

## Skip Integration Tests

For tests that MUST use real system services:
```swift
override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipIf(
        TestHelpers.shouldSkipAppGroupsTest(),
        "Skipping: unsigned build would trigger permission dialogs"
    )
    cloudKitService = CloudKitService()
}
```

## Red Flags in Test Reviews

- Direct `ViewModel()` instantiation without TestHelpers
- Use of `.shared` singletons that access system resources
- Missing skip conditions for integration tests
- Tests that work locally but show permission dialogs

## Antipatterns

### Direct Instantiation
```swift
// BAD: Triggers system access
func testExportViewModel() {
    let vm = ExportViewModel()
    XCTAssertFalse(vm.isExporting)
}

// GOOD: Uses isolated dependencies
func testExportViewModel() {
    let vm = TestHelpers.createTestExportViewModel()
    XCTAssertFalse(vm.isExporting)
}
```

### Missing Skip Conditions
```swift
// BAD: Will trigger permission dialogs
func testCloudKitService() {
    let service = CloudKitService()
    XCTAssertNotNil(service)
}

// GOOD: Skip when unavailable
func testCloudKitService() throws {
    try XCTSkipIf(
        TestHelpers.shouldSkipAppGroupsTest(),
        "Requires signed build with App Groups"
    )
    let service = CloudKitService()
    XCTAssertNotNil(service)
}
```

## Creating Test Doubles

### In-Memory Core Data
```swift
class TestCoreDataManager {
    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "Model")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }
    }
}
```

### Protocol-Based Mocking
```swift
protocol DataStoring {
    func save(_ item: Item) throws
}

class MockDataStore: DataStoring {
    var savedItems: [Item] = []
    var saveError: Error?

    func save(_ item: Item) throws {
        if let error = saveError { throw error }
        savedItems.append(item)
    }
}
```
