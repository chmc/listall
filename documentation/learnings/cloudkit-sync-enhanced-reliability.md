---
title: CloudKit Sync Enhanced Reliability
date: 2026-01-07
severity: HIGH
category: cloudkit
tags: [sync, event-timing, deduplication, query-generation, manual-refresh]
symptoms:
  - macOS CloudKit sync requires app restart to see iOS changes
  - Double UI refreshes occurring
  - No way to manually trigger sync
  - UI updates before data actually imported
root_cause: CloudKit event handler triggered on event START instead of COMPLETION, plus missing query generation for iOS
solution: Check endDate for event completion, deduplicate notification handlers, add query generation for iOS, add manual refresh UI
files_affected:
  - ListAll/ListAll/Models/CoreData/CoreDataManager.swift
  - ListAll/ListAllMac/Views/MacMainView.swift
related:
  - macos-cloudkit-sync-race-condition.md
  - cloudkit-ios-realtime-sync.md
---

## Root Causes

### 1. Event Handler Timing Issue
Handler triggered when CloudKit event **started** (`endDate == nil`), not **completed** (`endDate != nil`).

### 2. Double Notification Handling
Both `handleContextDidSave` AND `handleCloudKitEvent` fired for CloudKit imports causing double refreshes.

### 3. Missing Query Generation for iOS
`setQueryGenerationFrom(.current)` was macOS-only.

### 4. No User-Facing Sync Control
No manual refresh button or sync status indicator.

## Solutions

### 1. Check Event Completion
```swift
if cloudEvent.endDate == nil {
    print("CloudKit event STARTED: \(eventType)")  // Don't refresh yet
} else if cloudEvent.succeeded {
    try? self.viewContext.setQueryGenerationFrom(.current)
    self.viewContext.refreshAllObjects()
    NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
}
```

### 2. Deduplicate Handlers
`handleContextDidSave` skips CloudKit contexts:
```swift
let isCloudKitContext = contextName.contains("CloudKit") ||
                        contextName.contains("NSCloudKitMirroringDelegate") ||
                        contextName.contains("import") ||
                        contextName.contains("export")
```

### 3. Query Generation for Both Platforms
```swift
#if os(iOS) || os(macOS)
try? container.viewContext.setQueryGenerationFrom(.current)
#endif
```

### 4. Manual Refresh UI (macOS)
- Refresh button in toolbar (arrow.clockwise icon)
- Tooltip shows last sync time
- Sidebar footer displays sync status
- Calls `CoreDataManager.forceRefresh()`

### 5. Last Sync Tracking
```swift
@Published private(set) var lastSyncDate: Date?

if eventType == .import || eventType == .export {
    self.lastSyncDate = Date()
}
```

## Key Learnings

1. **CloudKit events have lifecycle** - Check `endDate != nil` before assuming data ready
2. **Deduplicate notification handlers** - Multiple observers fire for same operation
3. **Query generation matters on ALL platforms** - Not just macOS
4. **Give users control** - Manual refresh provides confidence and workaround
5. **Platform-specific logging** - Use compile-time flags to identify source
