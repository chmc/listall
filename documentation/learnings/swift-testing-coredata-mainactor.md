---
title: Swift Testing + Core Data Requires @MainActor
date: 2026-01-20
severity: CRITICAL
category: testing
tags: [swift-testing, coredata, mainactor, threading, crash]
symptoms: ["-[__NSCFSet removeObject:] / abort() crash", "Core Data threading violation", "Tests crash during viewContext access"]
root_cause: Swift Testing async tests run on arbitrary threads, but viewContext requires main thread
solution: Add @MainActor annotation to test suites that access Core Data
files_affected: [ListAllMacTests/RestoreArchivedListsTests.swift]
related: [xtest-nsapplescript-malloc-error.md, macos-test-isolation-permission-dialogs.md, macos-test-permission-fix.md]
---

## Problem

Tests using Core Data's `viewContext` crash with:
```
-[__NSCFSet removeObject:] / abort()
```

## Root Cause

Swift Testing runs `async` tests on arbitrary threads (not main thread). `NSPersistentContainer.viewContext` is tied to the main queue - accessing it from other threads causes undefined behavior.

The `-[__NSCFSet removeObject:]` error is a classic Core Data concurrency violation - Core Data's internal relationship tracking uses sets that fail when accessed from wrong thread.

## Solution

Add `@MainActor` annotation to test suites:

```swift
// BEFORE - crashes on arbitrary threads
@Suite(.serialized)
struct RestoreArchivedListsTests {
    @Test func testSomething() async throws {
        viewModel.archiveList(list)  // CRASH - wrong thread
    }
}

// AFTER - runs on main thread
@Suite(.serialized)
@MainActor
struct RestoreArchivedListsTests {
    @Test func testSomething() async throws {
        viewModel.archiveList(list)  // OK - main thread
    }
}
```

## Key Insight

**Swift Testing `async throws` tests DO NOT run on main thread by default**, unlike XCTest's synchronous tests.

When migrating from XCTest to Swift Testing, tests that access:
- Core Data `viewContext`
- `@MainActor`-isolated properties
- ViewModels expecting main-thread execution

...need `@MainActor` annotation.

## Prevention

1. Always add `@MainActor` to test suites accessing Core Data or ViewModels
2. Or use `context.perform {}` / `context.performAndWait {}` for Core Data operations
3. Document threading requirements in test suite comments
