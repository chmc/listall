# CloudKit iOS Real-Time Sync (December 2025)

## Problem: iOS Not Receiving CloudKit Changes in Real-Time

### Symptoms

- Changes made on macOS synced to iOS only when iOS app was closed and reopened
- Changes made on iOS synced to macOS correctly (when window became active)
- iOS console showed massive threading violations:
  - "Publishing changes from background threads is not allowed"
  - "Updating ObservedObject<MainViewModel> from background threads will cause undefined behavior"
  - "Unsupported layout off the main thread"
- Data was being received (logs showed updates) but UI wasn't refreshing

### Root Cause (Multi-Part Bug)

**Part 1: Missing Observers**
iOS was missing notification observers that macOS had.

**Part 2: Critical Threading Bug (THE REAL ISSUE)**
`viewContext.perform { }` was being used inside `DispatchQueue.main.async`, which **re-dispatched to a background queue**:

```swift
// BROKEN CODE:
DispatchQueue.main.async {  // ✅ We're on main thread now
    self.viewContext.perform {  // ❌ This RE-DISPATCHES to background queue!
        self.viewContext.refreshAllObjects()
    }
    NotificationCenter.default.post(...)  // ❌ Now on background thread!
}
```

**Why this breaks iOS:**
1. `viewContext.perform { }` schedules work on the viewContext's queue (background)
2. The notification is posted from the background thread
3. All `@objc` notification handlers receive it on the background thread
4. `@Published` property updates from background threads are **silently ignored** by SwiftUI
5. The UI never updates, even though the data was successfully loaded

## The Fix (4 Parts)

### Part 1: Remove viewContext.perform from CoreDataManager

**File**: `CoreDataManager.swift` - processRemoteChange(), handleContextDidSave(), handleCloudKitEvent()

```swift
// BEFORE (BROKEN):
DispatchQueue.main.async { [weak self] in
    self?.viewContext.perform {  // ❌ Re-dispatches to background!
        self?.viewContext.refreshAllObjects()
    }
    NotificationCenter.default.post(...)  // ❌ Background thread!
}

// AFTER (FIXED):
DispatchQueue.main.async { [weak self] in
    guard let self = self else { return }
    // CRITICAL: Don't use viewContext.perform - we're already on main thread!
    self.viewContext.refreshAllObjects()  // ✅ Main thread
    NotificationCenter.default.post(...)  // ✅ Main thread!
}
```

### Part 2: Add Main Thread Guards to @objc Handlers

**File**: `MainViewModel.swift` - handleCoreDataRemoteChange(), handleWatchSyncNotification(), handleWatchListsData()

```swift
@objc private func handleCoreDataRemoteChange(_ notification: Notification) {
    // CRITICAL: @objc selectors can be called from any thread
    // @MainActor attribute does NOT protect @objc selectors!
    guard Thread.isMainThread else {
        DispatchQueue.main.async { [weak self] in
            self?.handleCoreDataRemoteChange(notification)
        }
        return
    }
    // Now safe to update @Published properties
    loadLists()
}
```

### Part 3: Enable Background Context Save Observer for iOS

CoreDataManager had this observer only for macOS. Extended to iOS:

```swift
// BEFORE: macOS only
#if os(macOS)
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleContextDidSave(_:)),
    name: .NSManagedObjectContextDidSave,
    object: nil
)
#endif

// AFTER: iOS + macOS
#if os(iOS) || os(macOS)
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleContextDidSave(_:)),
    name: .NSManagedObjectContextDidSave,
    object: nil
)
#endif
```

And moved `handleContextDidSave(_:)` method from `#if os(macOS)` to `#if os(iOS) || os(macOS)`.

### Part 2: Add refreshAllObjects() for iOS in CloudKit Event Handler

```swift
// BEFORE: Only macOS refreshed objects
if eventType == .import {
    DispatchQueue.main.async { [weak self] in
        #if os(macOS)
        self?.viewContext.perform {
            self?.viewContext.refreshAllObjects()
        }
        #endif
        NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
    }
}

// AFTER: Both iOS and macOS refresh objects
if eventType == .import {
    DispatchQueue.main.async { [weak self] in
        self?.viewContext.perform {
            self?.viewContext.refreshAllObjects()
        }
        NotificationCenter.default.post(name: .coreDataRemoteChange, object: nil)
    }
}
```

### Part 3: Add UI Notification Observers

**MainView.swift** - Added observer to refresh list of lists:
```swift
.onReceive(NotificationCenter.default.publisher(for: .coreDataRemoteChange)) { _ in
    print("🌐 iOS: Received Core Data remote change notification - refreshing UI")
    viewModel.loadLists()
}
```

**ListViewModel.swift** - Added observer to refresh items within a list:
```swift
private func setupRemoteChangeObserver() {
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleRemoteChange(_:)),
        name: .coreDataRemoteChange,
        object: nil
    )
}

@objc private func handleRemoteChange(_ notification: Notification) {
    print("🌐 ListViewModel: Received Core Data remote change - refreshing items")
    DispatchQueue.main.async { [weak self] in
        self?.loadItems()
    }
}
```

## Why macOS Worked But iOS Didn't

macOS had multiple fallback mechanisms that iOS lacked:

| Mechanism | macOS | iOS (Before) | iOS (After) |
|-----------|-------|--------------|-------------|
| `NSPersistentStoreRemoteChange` observer | ✓ | ✓ | ✓ |
| `NSManagedObjectContextDidSave` observer | ✓ | ✗ | ✓ |
| CloudKit event notification observer | ✓ | ✓ | ✓ |
| `refreshAllObjects()` on import | ✓ | ✗ | ✓ |
| Sync polling timer (30s) | ✓ | ✗ | ✗ |
| `.coreDataRemoteChange` observer in Views | ✓ | ✗ | ✓ |

macOS's sync polling timer provided a fallback even if notifications didn't fire. iOS had no such fallback and relied entirely on notifications that weren't firing reliably.

## Key Insight: NSPersistentStoreRemoteChange is Unreliable When Foregrounded

Apple's `NSPersistentStoreRemoteChange` notification is documented to fire when "the persistent store coordinator detects changes from another process". However, when using `NSPersistentCloudKitContainer`:

1. CloudKit imports happen on a **background context**
2. The background context save may not trigger `NSPersistentStoreRemoteChange` reliably
3. Observing `NSManagedObjectContextDidSave` on ALL contexts catches these background saves

## Testing Checklist

After implementing this fix:

- [ ] Make change on macOS while iOS app is foregrounded
- [ ] Verify iOS UI updates within seconds (no app restart needed)
- [ ] Make change on iOS while macOS is foregrounded
- [ ] Verify macOS UI updates within seconds
- [ ] Verify no "sync ping-pong" loops occur (check console for excessive refresh logs)
- [ ] Test with both apps on same iCloud account
- [ ] Test across Development and Production CloudKit environments

## Files Changed

1. `ListAll/ListAll/Models/CoreData/CoreDataManager.swift`
   - Extended `NSManagedObjectContextDidSave` observer to iOS
   - Extended `handleContextDidSave(_:)` method to iOS
   - Added `refreshAllObjects()` for iOS in CloudKit event handler

2. `ListAll/ListAll/Views/MainView.swift`
   - Added `.onReceive` for `.coreDataRemoteChange` notification

3. `ListAll/ListAll/ViewModels/ListViewModel.swift`
   - Added `setupRemoteChangeObserver()` method
   - Added `handleRemoteChange(_:)` method

## Prevention

When implementing CloudKit sync across platforms:

1. **Don't assume notifications fire**: Use multiple detection mechanisms
2. **Observe background context saves**: CloudKit uses background contexts for imports
3. **Call refreshAllObjects()**: Force viewContext to re-read from persistent store
4. **Add UI refresh observers**: Views need to know when to reload data
5. **Test on real devices**: Simulator timing differs from physical devices
6. **Log at integration points**: Add print statements to trace sync flow

## References

- Integration Specialist agent guidance in `.claude/agents/integration-specialist.md`
- Previous learnings in `documentation/learnings/swiftui-list-drag-drop-ordering.md`
- Apple's NSPersistentCloudKitContainer documentation
