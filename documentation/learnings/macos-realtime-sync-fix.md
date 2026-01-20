---
title: macOS Real-Time CloudKit Sync UI Fix
date: 2025-12-07
severity: HIGH
category: cloudkit
tags: [swiftui, main-thread, published, environmentobject, real-time-sync]
symptoms: [macOS UI not updating during CloudKit sync, manual refresh required, view not re-rendering]
root_cause: @Published property updated off main thread; SwiftUI observation breaks at DataManager->View boundary
solution: Dispatch @Published updates to main thread; use .onChange(of:) for explicit observation
files_affected: [ListAll/Models/CoreData/CoreDataManager.swift, ListAllMac/Views/MacMainView.swift]
related: [macos-cloudkit-sync-analysis.md, ios-cloudkit-sync-polling-timer.md]
---

## Integration Flow

```
CloudKit Import
       |
       v
NSPersistentCloudKitContainer.eventChangedNotification
       |
       v
CoreDataManager posts .coreDataRemoteChange
       |
       v
MacMainView calls dataManager.loadData()
       |
       v
DataManager updates @Published var lists  <-- FAILURE POINT
       |                                      (off main thread)
       v
SwiftUI observation BREAKS
```

## Fix 1: Main Thread Publication (CRITICAL)

```swift
func loadData() {
    let listEntities = try coreDataManager.viewContext.fetch(request)
    let newLists = listEntities.map { $0.toList() }

    // CRITICAL: @Published must update on main thread
    DispatchQueue.main.async { [weak self] in
        self?.lists = newLists
    }
}
```

**Why**: SwiftUI's `@Published` observation requires main thread changes.

## Fix 2: Explicit State Observation

```swift
struct MacListDetailView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var items: [Item] = []

    var body: some View {
        // ... UI ...
        .onChange(of: dataManager.lists) { _, _ in
            items = dataManager.getItems(forListId: list.id)
        }
    }
}
```

**Why**: Computed properties may miss changes; `.onChange` creates explicit subscription.

## Fix 3: Force Observation in Computed Property

```swift
private var displayedLists: [List] {
    // CRITICAL: Read directly to establish observation
    let allLists = dataManager.lists
    return allLists.filter { !$0.isArchived }
}
```

**Why**: Ensures SwiftUI dependency tracking registers the computed property.

## Performance

| Fix | Cost |
|-----|------|
| Main thread dispatch | 1 call per sync (~500ms debounced) |
| Extra fetch | 1-2 queries per visible detail view |
| Dependency tracking | Zero runtime overhead |

**Total sync latency**: ~600ms (500ms CloudKit + 100ms fetch + 16ms render)

## Apply Same Pattern To

- WatchConnectivityService (`receiveMessage` handlers)
- iOS ContentView (if sync issues arise)
- Any future DataRepository pattern
