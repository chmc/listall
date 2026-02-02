---
title: CoreData Notification Tests Flaky in CI Due to Timer Scheduling
date: 2026-02-02
severity: MEDIUM
category: testing
tags:
  - xctest
  - notification
  - timer
  - ci-flakiness
  - test-isolation
  - coredata
symptoms:
  - testRemoteChangeNotificationPosted fails intermittently in CI
  - Timer.scheduledTimer doesn't fire reliably in test environment
  - Tests pass locally but fail in GitHub Actions
root_cause: Timer-based debouncing combined with missing test isolation and run loop timing differences in CI
solution: Add CoreDataManager.resetForTesting() in setUp/tearDown, use XCTest notification expectations, post notifications on main thread async
files_affected:
  - ListAll/ListAllTests/CoreDataRemoteChangeTests.swift
related:
  - swift-testing-coredata-mainactor.md
  - macos-test-isolation-permission-dialogs.md
---

## Problem

`CoreDataRemoteChangeTests.testRemoteChangeNotificationPosted()` failed intermittently in CI (GitHub Actions) but passed consistently locally. The test verifies that posting `NSPersistentStoreRemoteChange` triggers the debounced `coreDataRemoteChange` notification.

## Root Cause

Multiple factors combined to cause CI-specific flakiness:

1. **Missing Test Isolation**: No `CoreDataManager.resetForTesting()` call meant pending debounce timers from previous tests could interfere

2. **Timer Scheduling in CI**: `Timer.scheduledTimer` requires an active run loop. In CI's slower environment, the main run loop might not be processing timers at the expected rate

3. **Thread Timing**: The notification post and timer scheduling had race conditions when the test thread wasn't the main thread

```swift
// BAD - Not CI-reliable
func testRemoteChangeNotificationPosted() throws {
    let observer = NotificationCenter.default.addObserver(
        forName: .coreDataRemoteChange, object: nil, queue: .main
    ) { _ in expectation.fulfill() }

    // Direct post without ensuring main thread
    NotificationCenter.default.post(
        name: .NSPersistentStoreRemoteChange,
        object: CoreDataManager.shared.persistentContainer.persistentStoreCoordinator
    )

    wait(for: [expectation], timeout: 2.0)  // Too short for CI
}

// GOOD - CI-reliable
func testRemoteChangeNotificationPosted() throws {
    // Use XCTest's built-in notification expectation
    let notificationExpectation = expectation(
        forNotification: .coreDataRemoteChange, object: nil, handler: nil
    )

    // Give run loop time to settle
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))

    // Ensure main thread for timer scheduling
    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: .NSPersistentStoreRemoteChange,
            object: CoreDataManager.shared.persistentContainer.persistentStoreCoordinator
        )
    }

    wait(for: [notificationExpectation], timeout: 3.0)  // Buffer for CI
}
```

## Solution

1. Call `CoreDataManager.resetForTesting()` in both `setUp()` and `tearDown()` to clear pending timers
2. Force-initialize the persistent container in `setUp()` before tests run
3. Use `expectation(forNotification:)` instead of manual observers
4. Add `RunLoop.current.run()` before posting to let pending work complete
5. Post notifications via `DispatchQueue.main.async` for consistent timer scheduling
6. Increase timeout from 2.0s to 3.0s for CI buffer

## Prevention

- [ ] Always call `resetForTesting()` in setUp/tearDown for singleton-dependent tests
- [ ] Use XCTest's built-in notification expectations when possible
- [ ] Add 50% timeout buffer for CI environments
- [ ] Post notifications on main thread when testing timer-based code
- [ ] Include 100ms run loop delay before triggering async operations in tests

## Key Insight

> Timer-based tests need explicit test isolation, main-thread notification posting, and generous timeouts to be reliable in CI where run loop scheduling differs from local development.
