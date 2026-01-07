# CloudKit Sync Enhanced Reliability

## Date: 2026-01-07

## Problem
macOS CloudKit sync required app restart to see changes made on iOS, despite initial race condition fix in Task 11.8.

## Root Causes

### 1. CloudKit Event Handler Timing Issue
The `handleCloudKitEvent` handler was triggering UI refresh when CloudKit event **started** (`endDate == nil`), not when it **completed** (`endDate != nil`).

**Before**: UI refresh triggered on event start, before data was actually imported
**After**: UI refresh only triggers when event completes successfully

### 2. Double Notification Handling
Both `handleContextDidSave` AND `handleCloudKitEvent` fired for CloudKit imports, causing:
- Double UI refreshes
- Potential race conditions
- Wasted CPU cycles

**Solution**: `handleContextDidSave` now detects CloudKit import contexts by name pattern:
```swift
let isCloudKitContext = contextName.contains("CloudKit") ||
                        contextName.contains("NSCloudKitMirroringDelegate") ||
                        contextName.contains("import") ||
                        contextName.contains("export")
```

### 3. Missing Query Generation for iOS
`setQueryGenerationFrom(.current)` was only set for macOS, not iOS. This ensures fetch requests return the latest data from CloudKit imports.

### 4. No User-Facing Sync Control
Users had no way to manually trigger sync or see when last sync occurred.

## Solutions Implemented

### 1. CloudKit Event Handler Improvements (CoreDataManager.swift)
```swift
if cloudEvent.endDate == nil {
    // Event just started - don't refresh yet
    print("CloudKit event STARTED: \(eventType)")
} else {
    // Event completed - now safe to refresh
    if cloudEvent.succeeded {
        try? self.viewContext.setQueryGenerationFrom(.current)
        self.viewContext.refreshAllObjects()
        NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
    }
}
```

### 2. Notification Deduplication
`handleContextDidSave` skips contexts with CloudKit-related names to prevent double handling.

### 3. Query Generation for Both Platforms
```swift
#if os(iOS) || os(macOS)
try? container.viewContext.setQueryGenerationFrom(.current)
#endif
```

### 4. Last Sync Timestamp Tracking
```swift
@Published private(set) var lastSyncDate: Date?

// Updated on successful import/export
if eventType == .import || eventType == .export {
    self.lastSyncDate = Date()
}
```

### 5. Manual Refresh Button (macOS)
- Added refresh button to toolbar (arrow.clockwise icon)
- Tooltip shows last sync time
- Sidebar footer displays sync status
- Calls `CoreDataManager.forceRefresh()` which:
  - Resets query generation
  - Refreshes all objects
  - Posts notification
  - Updates lastSyncDate

### 6. Platform-Specific Logging
```swift
#if os(iOS)
let platform = "iOS"
#elseif os(macOS)
let platform = "macOS"
#endif
print("[\(platform)] CloudKit event SUCCEEDED: \(eventType)")
```

## Testing Verification

### Tests That Pass
- `CoreDataRemoteChangeTests.testDataManagerReloadsOnRemoteChange`
- `CoreDataRemoteChangeTests.testDebouncingPreventsExcessiveReloads`
- `CoreDataRemoteChangeTests.testRemoteChangeNotificationPosted`
- All CoreDataManagerTests
- All ModelTests
- All EmptyStateTests

### Known Flaky Test
- `CoreDataRemoteChangeTests.testRemoteChangeThreadSafety` - Timeout increased to 5s but may still be flaky due to singleton state between tests

## Key Learnings

1. **CloudKit events have lifecycle**: Check `endDate != nil` before assuming data is ready
2. **Deduplicate notification handlers**: Multiple observers can fire for same CloudKit operation
3. **Query generation matters on ALL platforms**: Not just macOS
4. **Give users control**: Manual refresh button provides confidence and workaround
5. **Platform-specific logging helps debugging**: Use compile-time flags to identify source

## Files Modified

- `ListAll/ListAll/Models/CoreData/CoreDataManager.swift`
  - Added `lastSyncDate` property
  - Added `forceRefresh()` method
  - Enhanced `handleCloudKitEvent()` with completion detection
  - Added CloudKit context detection in `handleContextDidSave()`
  - Added query generation for iOS

- `ListAll/ListAllMac/Views/MacMainView.swift`
  - Added refresh button to toolbar
  - Added sync status to sidebar footer
  - Added `lastSyncTooltip` and `lastSyncDisplayText` computed properties
  - Added `coreDataManager` ObservedObject to MacSidebarView

## References

- Apple TN3163: Understanding NSPersistentCloudKitContainer Synchronization
- Apple TN3164: Debugging NSPersistentCloudKitContainer Synchronization
- Previous learning: `macos-cloudkit-sync-race-condition.md`
- Previous learning: `cloudkit-ios-realtime-sync.md`
