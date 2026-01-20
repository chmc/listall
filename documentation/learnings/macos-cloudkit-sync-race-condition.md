---
title: macOS CloudKit Sync Race Condition
date: 2026-01-06
severity: CRITICAL
category: macos
tags: [cloudkit, race-condition, threading, perform, performandwait]
symptoms:
  - Changes on iOS not reflected on macOS in real-time
  - Changes on macOS reflected on iOS (with delay)
  - macOS requires app restart to see iOS changes
  - TestFlight (Release) builds affected
root_cause: Race condition between viewContext.perform (async) and DispatchQueue.main.async - execution order undefined
solution: Change perform to performAndWait in sync polling timer
files_affected:
  - ListAll/ListAllMac/Views/MacMainView.swift
related:
  - cloudkit-ios-realtime-sync.md
  - cloudkit-push-notification-config.md
---

## The Bug

```swift
// BROKEN - Race condition:
viewContext.perform {              // Async on viewContext queue
    viewContext.refreshAllObjects()
}
DispatchQueue.main.async {         // Async on GCD main queue
    dataManager.loadData()         // May run BEFORE refreshAllObjects!
}
```

## Why This Breaks

`viewContext.perform {}` and `DispatchQueue.main.async {}` are **independent async mechanisms**:
- They don't guarantee execution order
- `perform` uses NSManagedObjectContext internal queue
- `DispatchQueue.main.async` uses libdispatch main queue
- Result: `loadData()` could fetch stale data

## The Fix

```swift
// FIXED - Synchronous refresh first:
viewContext.performAndWait {       // SYNC - blocks until complete
    viewContext.refreshAllObjects()
}
DispatchQueue.main.async {         // Safe - refresh already done
    dataManager.loadData()
}
```

## Why iOS Worked But macOS Didn't

iOS receives CloudKit changes via APNS push notifications, which trigger handlers in CoreDataManager using **synchronous** operations:

```swift
// CoreDataManager (correct):
DispatchQueue.main.async {
    self.viewContext.refreshAllObjects()  // Sync on main thread
    NotificationCenter.default.post(...)   // Then this runs
}
```

macOS doesn't receive push notifications, relying on sync polling timer which had the race condition.

## Queue Mechanism Comparison

| Method | Mechanism | Execution |
|--------|-----------|-----------|
| `viewContext.perform {}` | NSManagedObjectContext internal | Async |
| `viewContext.performAndWait {}` | NSManagedObjectContext internal | Sync |
| `DispatchQueue.main.async {}` | libdispatch main queue | Async |
| `DispatchQueue.main.sync {}` | libdispatch main queue | Sync |

**Rule**: When mixing context operations with GCD for dependent operations, use `performAndWait`.

## Prevention Rules

1. **Always use `performAndWait`** when subsequent code depends on operation completing
2. **Never mix `perform` with `DispatchQueue.main.async`** for dependent operations
3. **Test CloudKit sync across platforms** using TestFlight (not Debug builds)
4. **Add logging** to verify operation order when debugging
