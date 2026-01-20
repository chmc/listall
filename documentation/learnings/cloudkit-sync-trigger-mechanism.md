---
title: CloudKit Sync Trigger Mechanism
date: 2026-01-08
severity: CRITICAL
category: cloudkit
tags: [sync, polling, timer, performbackgroundtask, swiftui]
symptoms:
  - CloudKit sync only works after app restart
  - Manual sync button has no effect
  - Changes between iOS and macOS require both apps restart
  - Occurs on TestFlight (Release) builds
root_cause: CloudKitService.sync() was empty placeholder; NSPersistentCloudKitContainer sync is passive/push-based and cannot be forced
solution: Use performBackgroundTask with processPendingChanges to wake up CloudKit, fix Timer.scheduledTimer SwiftUI pattern
files_affected:
  - ListAll/ListAll/Models/CoreData/CoreDataManager.swift
  - ListAll/ListAll/Services/CloudKitService.swift
  - ListAll/ListAllMac/Views/MacMainView.swift
  - ListAll/ListAll/Views/MainView.swift
related:
  - cloudkit-sync-enhanced-reliability.md
  - ios-cloudkit-sync-polling-timer.md
---

## Critical Understanding

**You CANNOT force CloudKit to fetch from server on-demand.**

NSPersistentCloudKitContainer sync is:
- **Push-based**: Local changes exported on save
- **Notification-based**: Remote changes imported via APNS silent push
- **Unreliable when foregrounded**: Silent pushes often delayed/dropped

`refreshAllObjects()` only refreshes from LOCAL persistent store - if CloudKit hasn't imported, nothing to refresh.

## Solutions

### 1. Wake Up CloudKit Engine
```swift
func triggerCloudKitSync() {
    persistentContainer.performBackgroundTask { context in
        context.processPendingChanges()
    }
}
```

### 2. Fixed CloudKitService.sync()
```swift
func sync() async {
    coreDataManager.triggerCloudKitSync()
    try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s for CloudKit
    await MainActor.run {
        coreDataManager.forceRefresh()
    }
}
```

### 3. Fixed macOS Timer Pattern

**Before (problematic):**
```swift
syncPollingTimer = Timer.scheduledTimer(...) { [self] _ in
    // Captures COPY of struct at creation time
}
```

**After (correct SwiftUI):**
```swift
private let syncPollingTimer = Timer.publish(every: 30.0, on: .main, in: .common).autoconnect()

.onReceive(syncPollingTimer) { _ in
    guard isSyncPollingActive else { return }
    performSyncPoll()
}
```

### 4. Polling Now Wakes CloudKit
```swift
viewContext.performAndWait {
    viewContext.refreshAllObjects()
}
CoreDataManager.shared.triggerCloudKitSync()
dataManager.loadData()
```

## Key Learnings

| Fact | Implication |
|------|-------------|
| Cannot force CloudKit fetch | Use workarounds to encourage sync |
| refreshAllObjects() is local only | Won't help if CloudKit hasn't imported |
| Background context operations wake CloudKit | performBackgroundTask + processPendingChanges |
| Timer.scheduledTimer wrong for SwiftUI | Views are structs; [self] captures copy |
| APNS unreliable when foregrounded | Polling every 30s is essential fallback |
| Give CloudKit time to process | Add 0.5s delay before UI refresh |

## Important Caveats

- Not a guaranteed fix - CloudKit timing controlled by Apple
- Data will eventually sync - question is speed
- App restart still works best - triggers full zone fetch
- TestFlight/Release builds required - Debug on macOS disables CloudKit
