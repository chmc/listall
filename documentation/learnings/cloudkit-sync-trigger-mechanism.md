# CloudKit Sync Trigger Mechanism

## Date: 2026-01-08

## Problem

CloudKit sync between iOS and macOS only works after app restart. Manual sync button and polling timer don't trigger real-time updates between devices.

**User-Reported Symptoms:**
- Changes made on iOS only appear on macOS after BOTH apps restart
- Changes made on macOS only appear on iOS after iOS restarts
- Manual sync button has no effect
- This occurs on TestFlight (Release) builds

## Root Cause Analysis

### Finding 1: CloudKitService.sync() Was Empty

The `CloudKitService.sync()` method had a placeholder that did nothing:

```swift
// BEFORE - Does nothing useful:
coreDataManager.persistentContainer.persistentStoreCoordinator.performAndWait {
    // This triggers the CloudKit sync  <-- EMPTY BLOCK!
}
```

### Finding 2: NSPersistentCloudKitContainer Sync is Passive

**Key Insight**: You CANNOT force CloudKit to fetch from the server on-demand. NSPersistentCloudKitContainer sync is:
- **Push-based**: Local changes are exported automatically when you save
- **Notification-based**: Remote changes are imported when Apple Push Notification Service (APNS) delivers silent push notifications
- **Unreliable when foregrounded**: Silent push notifications are often delayed/dropped when app is in foreground

**What `refreshAllObjects()` does**: Only refreshes objects from the LOCAL persistent store. If CloudKit hasn't imported data yet, there's nothing to refresh.

### Finding 3: macOS Timer Pattern Was Problematic

macOS used `Timer.scheduledTimer` with `[self]` capture in a SwiftUI View struct:

```swift
// PROBLEMATIC - Captures stale copy of struct:
syncPollingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [self] _ in
    // This closure captures a COPY of the struct at timer creation time
    // Any state changes after timer creation are not visible
}
```

iOS had already been fixed to use `Timer.publish` with `.onReceive`, which properly integrates with SwiftUI's view lifecycle.

### Finding 4: No Mechanism to Wake Up CloudKit

While we can't force CloudKit to fetch, we CAN encourage it to process pending operations by triggering background context activity:

```swift
// Wakes up CloudKit's mirroring delegate to check for pending operations:
persistentContainer.performBackgroundTask { context in
    context.processPendingChanges()
}
```

## Solutions Implemented

### 1. Fixed CloudKitService.sync() (CloudKitService.swift)

```swift
func sync() async {
    // ... guards ...

    // Trigger CloudKit sync engine to wake up
    coreDataManager.triggerCloudKitSync()

    // Give CloudKit time to process (heuristic)
    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

    // Now force refresh to pick up any imported changes
    await MainActor.run {
        coreDataManager.forceRefresh()
    }

    // ... completion handling ...
}
```

### 2. Added triggerCloudKitSync() (CoreDataManager.swift)

```swift
/// Triggers CloudKit sync engine to wake up and check for pending operations
func triggerCloudKitSync() {
    persistentContainer.performBackgroundTask { context in
        context.processPendingChanges()
        print("☁️ [\(platform)] Triggered CloudKit sync engine")
    }
}
```

### 3. Updated forceRefresh() to Call triggerCloudKitSync()

```swift
func forceRefresh() {
    DispatchQueue.main.async { [weak self] in
        // Trigger CloudKit sync engine first
        self.triggerCloudKitSync()

        // Then refresh local objects
        try? self.viewContext.setQueryGenerationFrom(.current)
        self.viewContext.refreshAllObjects()

        // Post notification for UI
        NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
    }
}
```

### 4. Fixed macOS Timer to Use Timer.publish (MacMainView.swift)

```swift
// BEFORE (problematic):
@State private var syncPollingTimer: Timer?
syncPollingTimer = Timer.scheduledTimer(...) { [self] _ in ... }

// AFTER (correct SwiftUI pattern):
@State private var isSyncPollingActive = false
private let syncPollingTimer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()

// Used with:
.onReceive(syncPollingTimer) { _ in
    guard isSyncPollingActive else { return }
    performSyncPoll()
}
```

### 5. Added triggerCloudKitSync() to Polling (Both Platforms)

Both iOS and macOS polling now call `triggerCloudKitSync()` before refreshing:

```swift
// Refresh local objects
viewContext.performAndWait {
    viewContext.refreshAllObjects()
}

// Wake up CloudKit sync engine
CoreDataManager.shared.triggerCloudKitSync()

// Reload UI
dataManager.loadData()
```

## Key Learnings

1. **You cannot force CloudKit to fetch** - NSPersistentCloudKitContainer relies on APNS silent push notifications which are unreliable when app is foregrounded

2. **refreshAllObjects() only refreshes LOCAL data** - It re-reads from the persistent store, not from CloudKit server

3. **Background context operations wake up CloudKit** - `performBackgroundTask` with `processPendingChanges()` encourages the CloudKit mirroring delegate to check for pending operations

4. **Timer.scheduledTimer is wrong for SwiftUI Views** - SwiftUI Views are structs; `[self]` captures a copy. Use `Timer.publish` with `.onReceive` instead

5. **Polling is a necessary fallback** - Because APNS is unreliable when foregrounded, polling every 30 seconds is essential for sync reliability

6. **Give CloudKit time to process** - After triggering sync, add a small delay (0.5s) before refreshing UI to allow time for import processing

## Important Caveats

- **This is not a guaranteed fix** - CloudKit sync timing is controlled by Apple's infrastructure
- **Data will eventually sync** - The question is how quickly
- **App restart still works best** - Fresh initialization triggers a full zone fetch
- **TestFlight/Release builds are required** - Debug builds on macOS disable CloudKit

## Files Modified

- `ListAll/ListAll/Models/CoreData/CoreDataManager.swift`
  - Added `triggerCloudKitSync()` method
  - Updated `forceRefresh()` to call `triggerCloudKitSync()`

- `ListAll/ListAll/Services/CloudKitService.swift`
  - Rewrote `sync()` to actually trigger sync and refresh
  - Removed empty `checkForRemoteChanges()` stub

- `ListAll/ListAllMac/Views/MacMainView.swift`
  - Added `import Combine` for Timer.publish
  - Changed from `Timer.scheduledTimer` to `Timer.publish` pattern
  - Added `performSyncPoll()` method
  - Added `triggerCloudKitSync()` call in polling

- `ListAll/ListAll/Views/MainView.swift`
  - Added `triggerCloudKitSync()` call in polling

## References

- Apple WWDC 2019: Using Core Data With CloudKit
- Apple TN3163: Understanding NSPersistentCloudKitContainer Synchronization
- Apple TN3164: Debugging NSPersistentCloudKitContainer Synchronization
- Previous learning: `ios-cloudkit-sync-polling-timer.md` (Timer.publish pattern)
- Previous learning: `cloudkit-sync-enhanced-reliability.md` (event timing)
