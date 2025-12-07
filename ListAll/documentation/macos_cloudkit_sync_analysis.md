# macOS CloudKit Sync Analysis

**Issue**: macOS app doesn't auto-update when active, only when user switches away and back.

**Date**: 2025-12-07

---

## Root Cause Analysis

### Symptom
- macOS app receives CloudKit changes from iOS/other devices
- Changes do NOT appear in UI when app is active (foreground)
- Changes DO appear when user switches to another app and back (scenePhase becomes `.active`)

### Investigation Findings

#### 1. Remote Change Notification Flow

**CoreDataManager.swift** (lines 203-224):
```swift
private func setupRemoteChangeNotifications() {
    // Handler 1: NSPersistentStoreRemoteChange (from other processes/devices)
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handlePersistentStoreRemoteChange(_:)),
        name: .NSPersistentStoreRemoteChange,
        object: persistentContainer.persistentStoreCoordinator
    )

    // Handler 2: CloudKit event notifications (iOS 14+, macOS 11+)
    if #available(iOS 14.0, macOS 11.0, *) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: persistentContainer
        )
    }
}
```

Both handlers should fire on remote changes.

#### 2. CloudKit Event Handler (lines 268-294)

```swift
@objc private func handleCloudKitEvent(_ notification: Notification) {
    // ...
    if cloudEvent.succeeded {
        if eventType == .import {
            // Only posts notification for .import events
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
            }
        }
    }
}
```

**FINDING**: CloudKit import events correctly post `.coreDataRemoteChange` notification.

#### 3. Remote Change Handler (lines 226-251)

```swift
@objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {
    // ISSUE 1: isLocalSave flag might have race condition
    if isLocalSave {
        print("💾 CoreDataManager: Ignoring local save notification (not a remote change)")
        isLocalSave = false
        return
    }

    // ISSUE 2: Debouncing might delay updates too long
    remoteChangeDebounceTimer?.invalidate()
    remoteChangeDebounceTimer = Timer.scheduledTimer(
        withTimeInterval: remoteChangeDebounceInterval, // 0.5s
        repeats: false
    ) { [weak self] _ in
        self?.processRemoteChange()
    }
}
```

**FINDING**:
- `isLocalSave` flag prevents local saves from triggering reloads (correct behavior)
- 0.5s debounce delays processing (might be too long?)

#### 4. MainViewModel Remote Change Handler (lines 289-301)

```swift
@objc private func handleCoreDataRemoteChange(_ notification: Notification) {
    // ISSUE 3: Edit mode/drag guards might block legitimate updates
    if isDragging || isEditModeActive {
        print("⚠️ Core Data remote change received during edit mode/drag - IGNORING stale data")
        return
    }

    print("🌐 Core Data remote change detected - reloading lists from CloudKit")
    loadLists()
}
```

**CRITICAL FINDING**: The guard condition `isDragging || isEditModeActive` blocks remote changes during:
- Active drag operations (`isDragging = true` for 0.5s after each drag)
- Edit mode (`isEditModeActive = true` when iOS edit mode is active)

**macOS Specifics**:
- macOS doesn't use SwiftUI EditMode (lists are always editable)
- `isEditModeActive` should always be `false` on macOS
- `isDragging` is only `true` for 0.5s after drag-drop

**HYPOTHESIS**: The guard is NOT the issue on macOS (flags should be false).

#### 5. scenePhase Handler (MainView.swift lines 344-363)

```swift
.onChange(of: scenePhase) { newPhase in
    if newPhase == .active {
        // Reload lists to ensure we have the latest data
        viewModel.loadLists()
        // ...
    }
}
```

**FINDING**: This explains why switching away/back fixes the issue - it bypasses all guards and directly calls `loadLists()`.

---

## Identified Issues

### **Issue A: isLocalSave Race Condition**

**Location**: `CoreDataManager.swift` lines 22-23, 304, 309

**Problem**: The `isLocalSave` flag is NOT thread-safe:
```swift
private var isLocalSave = false  // NOT @MainActor, not synchronized

func save() {
    if context.hasChanges {
        isLocalSave = true  // Set on main thread
        try context.save()  // Might trigger notification on background thread
        // ...
    }
}

@objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {
    if isLocalSave {  // Read on notification thread (might be background)
        isLocalSave = false
        return
    }
}
```

**Race Condition Scenario**:
1. Main thread: `isLocalSave = true` (local save)
2. Background thread: CloudKit imports remote change
3. Background thread: `handlePersistentStoreRemoteChange()` fires
4. Background thread: Reads `isLocalSave = true` (race!)
5. **Remote change is incorrectly ignored as "local save"**

**Impact**: Remote changes might be randomly ignored when they coincide with local saves.

### **Issue B: Missing @MainActor Isolation**

**Location**: Multiple locations in `CoreDataManager.swift` and `MainViewModel.swift`

**Problem**: Core Data operations and UI updates are not properly isolated to main thread:
- `CoreDataManager.isLocalSave` is accessed from multiple threads
- `processRemoteChange()` posts notification without ensuring main thread
- `MainViewModel.loadLists()` modifies `@Published` properties (must be on main thread)

**Current Code**:
```swift
private func processRemoteChange() {
    viewContext.perform {  // Background context
        self.viewContext.refreshAllObjects()
    }

    // ISSUE: Posting notification immediately, before refresh completes
    NotificationCenter.default.post(
        name: .coreDataRemoteChange,
        object: nil
    )
}
```

### **Issue C: Debounce Timer Might Be Too Aggressive**

**Location**: `CoreDataManager.swift` line 19

```swift
private let remoteChangeDebounceInterval: TimeInterval = 0.5 // 500ms debounce
```

**Problem**:
- If multiple CloudKit changes arrive within 0.5s, only the LAST one triggers UI update
- User might not see intermediate states
- 0.5s feels sluggish for real-time sync

**Recommendation**: Reduce to 0.1s or 0.2s for more responsive UI.

### **Issue D: loadLists() Optimization Might Skip Legitimate Updates**

**Location**: `MainViewModel.swift` lines 351-366

```swift
func loadLists() {
    // ...
    let currentIds = lists.map { $0.id }
    let newIds = newLists.map { $0.id }
    if currentIds != newIds {
        print("📋 loadLists: Order changed, updating lists array")
        lists = newLists
    } else {
        // ISSUE: Only updates objects in-place, doesn't trigger @Published update
        for (index, newList) in newLists.enumerated() {
            if index < lists.count {
                lists[index] = newList  // Mutating array element
            }
        }
    }
}
```

**Problem**: When list IDs/order haven't changed (e.g., only item contents changed):
- Code updates array elements in-place: `lists[index] = newList`
- SwiftUI's `@Published` might NOT detect this as a change (depends on Combine's implementation)
- UI might not update even though data changed

**Recommendation**: Always reassign the entire array to ensure `@Published` fires:
```swift
lists = newLists
```

The "optimization" to skip reassignment might be causing CloudKit updates to not trigger UI refresh.

---

## Proposed Fixes

### Fix 1: Thread-Safe isLocalSave Flag

**File**: `/Users/aleksi/source/ListAllApp/ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

**Change**:
```swift
// OLD (line 23)
private var isLocalSave = false

// NEW
@MainActor
private var isLocalSave = false
```

**And update all access points**:
```swift
// In save() (line 304)
@MainActor
func save() {
    let context = persistentContainer.viewContext
    if context.hasChanges {
        do {
            isLocalSave = true
            try context.save()
            // ...
        }
    }
}

// In handlePersistentStoreRemoteChange() (line 226)
@objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {
    // Ensure main thread access
    guard Thread.isMainThread else {
        DispatchQueue.main.async { [weak self] in
            self?.handlePersistentStoreRemoteChange(notification)
        }
        return
    }

    // NOW safe to access isLocalSave
    if isLocalSave {
        print("💾 CoreDataManager: Ignoring local save notification")
        isLocalSave = false
        return
    }
    // ...
}
```

### Fix 2: Ensure processRemoteChange() Completes Before Posting Notification

**File**: `/Users/aleksi/source/ListAllApp/ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

**Change**:
```swift
// OLD (lines 253-264)
private func processRemoteChange() {
    viewContext.perform {
        self.viewContext.refreshAllObjects()
    }

    NotificationCenter.default.post(
        name: .coreDataRemoteChange,
        object: nil
    )
}

// NEW
private func processRemoteChange() {
    viewContext.perform {
        self.viewContext.refreshAllObjects()

        // Post notification AFTER refresh completes, on main thread
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .coreDataRemoteChange,
                object: nil
            )
        }
    }
}
```

### Fix 3: Remove loadLists() Optimization

**File**: `/Users/aleksi/source/ListAllApp/ListAll/ListAll/ViewModels/MainViewModel.swift`

**Change**:
```swift
// OLD (lines 349-366)
// Get active lists from DataManager and sort by orderNumber
let newLists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }

// OPTIMIZATION: Only update if order actually changed
let currentIds = lists.map { $0.id }
let newIds = newLists.map { $0.id }
if currentIds != newIds {
    print("📋 loadLists: Order changed, updating lists array")
    lists = newLists
} else {
    // Just update the list objects in place
    for (index, newList) in newLists.enumerated() {
        if index < lists.count {
            lists[index] = newList
        }
    }
}

// NEW
// Get active lists from DataManager and sort by orderNumber
let newLists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }

// ALWAYS update the array to ensure @Published fires
// This is critical for CloudKit sync - even if IDs/order unchanged, list/item contents might have changed
lists = newLists
```

### Fix 4: Reduce Debounce Interval

**File**: `/Users/aleksi/source/ListAllApp/ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

**Change**:
```swift
// OLD (line 19)
private let remoteChangeDebounceInterval: TimeInterval = 0.5 // 500ms debounce

// NEW
private let remoteChangeDebounceInterval: TimeInterval = 0.2 // 200ms debounce - more responsive
```

### Fix 5: Add Debug Logging

Add comprehensive logging to track sync events:

**File**: `/Users/aleksi/source/ListAllApp/ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

```swift
@objc private func handlePersistentStoreRemoteChange(_ notification: Notification) {
    // Add logging
    print("🔔 CoreDataManager: NSPersistentStoreRemoteChange received")
    print("   Thread: \(Thread.isMainThread ? "main" : "background")")
    print("   isLocalSave: \(isLocalSave)")

    // ... rest of handler
}

@objc private func handleCloudKitEvent(_ notification: Notification) {
    guard let cloudEvent = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else {
        return
    }

    let eventType = cloudEvent.type
    print("☁️ CloudKit event: \(eventType), succeeded: \(cloudEvent.succeeded)")

    // ... rest of handler
}
```

---

## Testing Plan

### Test 1: Verify Remote Changes Appear While App Active

1. Open macOS app (foreground)
2. On iOS device, add a new list
3. Wait 5 seconds
4. **EXPECTED**: macOS app shows new list without switching away/back

### Test 2: Verify No Race Condition with Local Saves

1. On macOS, rapidly create multiple lists (trigger local saves)
2. Simultaneously, on iOS, create lists
3. **EXPECTED**: All lists from both devices appear on both (no random drops)

### Test 3: Verify Drag-Drop Still Protected

1. On macOS, start dragging a list (don't release yet)
2. On iOS, reorder lists
3. **EXPECTED**: macOS ignores remote change during drag (prevents corruption)
4. Release drag on macOS
5. **EXPECTED**: After 0.5s, macOS updates to show iOS changes

---

## Priority

**HIGH PRIORITY** - This affects core sync functionality on macOS.

**Recommended Fix Order**:
1. **Fix 3** (Remove optimization) - Most likely to fix the issue, easiest to implement
2. **Fix 2** (Ensure refresh completes) - Ensures correct ordering of operations
3. **Fix 5** (Add logging) - Essential for debugging if issues persist
4. **Fix 1** (Thread safety) - Prevents race conditions
5. **Fix 4** (Reduce debounce) - Improves UX but not critical

---

## Additional Notes

- All fixes are backward compatible with iOS/watchOS
- No schema changes required
- Changes are isolated to sync infrastructure
- Risk level: LOW (fixes are defensive, don't change happy path)
