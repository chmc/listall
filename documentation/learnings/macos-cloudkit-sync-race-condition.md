# macOS CloudKit Sync Race Condition Fix (January 2026)

## Problem: macOS Not Receiving CloudKit Changes from iOS

### Symptoms

- Changes made on iOS were NOT reflected on macOS in real-time
- Changes made on macOS WERE reflected on iOS (with some delay)
- macOS required app restart to see iOS changes
- Both apps using TestFlight (Release builds) with CloudKit Production environment

### Root Cause: Race Condition in Sync Polling Timer

**Location**: `ListAllMac/Views/MacMainView.swift` (startSyncPolling function)

```swift
// BROKEN CODE - Race condition!
viewContext.perform {          // Async - schedules on viewContext queue
    viewContext.refreshAllObjects()
}

DispatchQueue.main.async {     // Async - schedules on main dispatch queue
    dataManager.loadData()     // May execute BEFORE refreshAllObjects() !
}
```

**Why This Causes the Bug**:

1. `viewContext.perform { }` and `DispatchQueue.main.async { }` are **independent async mechanisms**
2. They don't guarantee execution order, even though both target the main thread
3. `perform` uses NSManagedObjectContext's internal queue scheduling
4. `DispatchQueue.main.async` uses libdispatch's main queue
5. Result: `loadData()` could execute BEFORE `refreshAllObjects()`, fetching stale data

### Why iOS Worked But macOS Didn't

iOS receives CloudKit changes via **push notifications** (APNS), which trigger the `handleCloudKitEvent` and `handleContextDidSave` handlers in `CoreDataManager`. These handlers correctly use **synchronous** `refreshAllObjects()`:

```swift
// CoreDataManager (CORRECT - synchronous on main thread)
DispatchQueue.main.async {
    self.viewContext.refreshAllObjects()  // Sync - runs first
    NotificationCenter.default.post(...)   // Then this runs
}
```

macOS doesn't receive push notifications, so it relies on the **sync polling timer** as a fallback. The timer had the race condition bug.

### The Fix

Changed `perform` to `performAndWait` (synchronous) in MacMainView.swift:

```swift
// FIXED CODE - No race condition
viewContext.performAndWait {           // SYNC - blocks until complete
    viewContext.refreshAllObjects()
}

DispatchQueue.main.async {             // Safe - refresh already done
    dataManager.loadData()
}
```

### Key Insight: NSManagedObjectContext Queue vs GCD Main Queue

Even when using `mainQueueConcurrencyType`, the NSManagedObjectContext's `perform` method and GCD's `DispatchQueue.main.async` are **NOT the same queue**:

| Method | Queue Mechanism | Execution |
|--------|----------------|-----------|
| `viewContext.perform { }` | NSManagedObjectContext internal | Async |
| `viewContext.performAndWait { }` | NSManagedObjectContext internal | Sync (blocking) |
| `DispatchQueue.main.async { }` | libdispatch main queue | Async |
| `DispatchQueue.main.sync { }` | libdispatch main queue | Sync (blocking) |

When mixing `perform` (async) with `DispatchQueue.main.async`, execution order is **undefined**. Always use `performAndWait` when subsequent code depends on the context operation completing.

## Testing the Fix

After deploying via TestFlight:

1. Open macOS app (should start sync polling timer)
2. Make change on iOS (add/edit item)
3. Wait up to 30 seconds (polling interval)
4. Verify macOS shows the change without restart

Console logs should show:
```
🔄 macOS: Polling for CloudKit changes (timer-based fallback)
📱 DataManager: Updated lists array with X lists (synchronous)
```

## Files Changed

- `ListAll/ListAllMac/Views/MacMainView.swift` - Changed `perform` to `performAndWait` in sync polling timer

## Prevention

When working with Core Data contexts:

1. **Always use `performAndWait`** when subsequent code depends on the operation completing
2. **Never mix `perform` with `DispatchQueue.main.async`** for dependent operations
3. **Test CloudKit sync across platforms** using TestFlight (not Debug builds)
4. **Add logging** to verify operation order when debugging sync issues

## Related

- `cloudkit-ios-realtime-sync.md` - Previous iOS sync fix (threading issues)
- `cloudkit-push-notification-config.md` - Push notification configuration analysis

## Investigation Process

The bug was found by:
1. Swarm of agents analyzed CoreDataManager, MacMainView, and MainViewModel
2. Compared iOS working code with macOS non-working code
3. Identified that CoreDataManager handlers use synchronous operations
4. Found the sync polling timer used async `perform` instead of sync `performAndWait`
