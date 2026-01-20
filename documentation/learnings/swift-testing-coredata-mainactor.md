# Swift Testing + Core Data: @MainActor Requirement

**Date**: January 2026
**Task**: Fix crashes during test execution
**Severity**: CRITICAL (app crashes repeatedly)

## Problem

Tests using Core Data's `viewContext` were crashing with:
```
-[__NSCFSet removeObject:] / abort()
```

The crash happened specifically in:
- `RestoreArchivedListsTests.swift:522` - `testArchivedListIndicatesReadOnlyState()`
- `TestMainViewModel.archiveList(_:)` calling Core Data save

## Root Cause

**Core Data threading violation** combined with **Swift Testing's async behavior**.

### The Chain of Events

1. Swift Testing runs `async` tests on **arbitrary threads** (not the main thread)
2. Test calls `viewModel.archiveList(list)`
3. `archiveList` accesses `coreDataManager.viewContext` (main-thread only context)
4. Core Data detects threading violation and crashes

### Why This Matters

`NSPersistentContainer.viewContext` is **tied to the main queue**. Accessing it from any other thread causes undefined behavior and crashes.

The `-[__NSCFSet removeObject:]` error is a classic Core Data concurrency violation - Core Data's internal relationship tracking uses sets, and when accessed from the wrong thread, these operations fail.

## Solution

Add `@MainActor` annotation to test suites that access Core Data:

```swift
// BEFORE - crashes on arbitrary threads
@Suite(.serialized)
struct RestoreArchivedListsTests {
    @Test("...")
    func testSomething() async throws {
        viewModel.archiveList(list)  // CRASH - wrong thread
    }
}

// AFTER - runs on main thread
@Suite(.serialized)
@MainActor
struct RestoreArchivedListsTests {
    @Test("...")
    func testSomething() async throws {
        viewModel.archiveList(list)  // OK - main thread
    }
}
```

## Key Insight

**Swift Testing `async throws` tests DO NOT run on the main thread by default**, unlike XCTest's synchronous tests which ran on the main thread.

When migrating from XCTest to Swift Testing, any tests that:
- Access Core Data `viewContext`
- Access `@MainActor`-isolated properties
- Use ViewModels that expect main-thread execution

...need `@MainActor` annotation.

## Files Modified

- `ListAll/ListAllMacTests/RestoreArchivedListsTests.swift` - Added `@MainActor` to 4 test suites:
  - `RestoreArchivedListsTests`
  - `RestoreArchivedListsDataManagerTests`
  - `RestoreArchivedListsCoreDataTests`
  - `ArchivedListsReadOnlyTests`

## Prevention

When writing new tests that access Core Data or ViewModels:
1. Always add `@MainActor` to the test suite
2. Or use `context.perform {}` / `context.performAndWait {}` for Core Data operations
3. Document the threading requirements in test suite comments
