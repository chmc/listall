---
name: coredata-sync
description: Core Data and CloudKit sync patterns for iOS. Use when debugging sync issues, race conditions, or data consistency problems.
---

# Core Data & CloudKit Sync Patterns

## Save vs Fetch Race Condition

### The Problem
```swift
context.save()  // Synchronous TO CONTEXT, but disk write is ASYNC
loadData()      // May fetch STALE data if disk write incomplete
```

### Why It Happens
- `NSManagedObjectContext.save()` commits to context immediately
- Persistent store coordinator writes to SQLite asynchronously
- Fetch after save may get old data from cache/disk

### Solutions
1. Don't fetch immediately after save - trust in-memory state
2. Use completion handler or async/await for save
3. Block other reloads during mutation with a flag

## Remote Change Notification Timing

### Problem
```swift
// NSPersistentStoreRemoteChange fires when disk changes
// Often triggers reload that races with in-flight save
NotificationCenter.observe(.NSPersistentStoreRemoteChange) {
    dataManager.loadData()  // Can overwrite correct data with stale!
}
```

### Solution
Skip reloads while the state that a reload would break is active, based on state, not a timer. `MainViewModel.loadLists()` (`ListAll/ListAll/ViewModels/MainViewModel.swift`) returns early while `isDragging || isEditModeActive`, because replacing the array SwiftUI is animating breaks drag and drop:

```swift
private var isDragOperationInProgress: Bool { isDragging || isEditModeActive }

func loadLists() {
    if isDragOperationInProgress { return }  // reload again when the drag/edit ends
    // ... load
}
```

Coalesce notification bursts into one reload (`WatchMainViewModel.scheduleSyncReload()`: cancellable `DispatchWorkItem`, `[weak self]`). Avoid fixed `asyncAfter` delays as a lock: they are guesses that fail under load.

## CloudKit Sync Configuration

### Pattern
```swift
// Use NSPersistentCloudKitContainer for automatic sync
let container = NSPersistentCloudKitContainer(name: "Model")

// Configure merge policy
context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

// Monitor sync events
NotificationCenter.default.addObserver(
    forName: NSPersistentCloudKitContainer.eventChangedNotification,
    object: container,
    queue: .main
) { notification in
    guard let event = notification.userInfo?[
        NSPersistentCloudKitContainer.eventNotificationUserInfoKey
    ] as? NSPersistentCloudKitContainer.Event else { return }

    if event.endDate != nil {
        if let error = event.error {
            handleSyncError(error)
        }
    }
}
```

## Context Management

### Pattern
```swift
// Use appropriate context for operation type
func performBackgroundSync(_ data: SyncData) async throws {
    try await container.performBackgroundTask { context in
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        for item in data.items {
            let entity = ItemEntity.findOrCreate(id: item.id, in: context)
            entity.update(from: item)
        }

        try context.save()
    }
}
```

### Antipattern
```swift
// Never pass managed objects between threads
let item = mainContext.fetch(...)  // Main thread
Task.detached {
    item.name = "Updated"  // BUG: Wrong thread!
}
```

## Common Failures

### "Merge conflict with no resolution"
- **Cause**: NSMergePolicy not set or inappropriate
- **Fix**: Configure `mergeByPropertyObjectTrump` or custom policy
- **Prevention**: Always set merge policy explicitly

### "Sync stuck in pending state"
- **Cause**: CloudKit quota exceeded or network issues
- **Fix**: Check CloudKit Dashboard, verify container permissions
- **Prevention**: Monitor sync events, implement timeout

### "Data appears on one device but not another"
- **Cause**: Different iCloud accounts or sync delay
- **Fix**: Verify accounts match, wait for sync, check logs
- **Prevention**: Add sync status indicators to UI

### "Duplicate entities after sync"
- **Cause**: Missing unique constraint or improper upsert
- **Fix**: Add unique constraint, use findOrCreate pattern
- **Prevention**: Always use upsert logic for synced entities
