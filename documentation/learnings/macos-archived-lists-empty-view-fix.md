# macOS Archived Lists Empty View Fix

## Problem

The macOS archived lists view showed empty even when archived lists existed. Users could see the "Archived Lists" header but no lists appeared.

## Root Cause

`MacSidebarView.displayedLists` computed property filtered `dataManager.lists` for archived items:

```swift
// MacMainView.swift line 515-523 (BEFORE FIX)
private var displayedLists: [List] {
    if showingArchivedLists {
        return dataManager.lists.filter { $0.isArchived }  // ALWAYS EMPTY!
            .sorted { $0.orderNumber < $1.orderNumber }
    } else {
        return dataManager.lists.filter { !$0.isArchived }
            .sorted { $0.orderNumber < $1.orderNumber }
    }
}
```

**The bug:** `dataManager.lists` is populated by `loadData()` which uses predicate `"isArchived == NO OR isArchived == nil"` - it **never** contains archived lists. Therefore filtering for `isArchived == true` always returns an empty array.

## iOS vs macOS Implementation Difference

| Aspect | iOS (Working) | macOS (Broken) |
|--------|---------------|----------------|
| Data source | `MainViewModel.archivedLists` (separate `@Published` array) | `dataManager.lists.filter { $0.isArchived }` |
| Load method | Calls `loadArchivedLists()` to populate separate array | Filters from cached lists (which excludes archived) |
| Architecture | ViewModel with dedicated archived state | Direct DataManager observation without archived state |

## Solution

### 1. Added `@Published var archivedLists` to DataManager

```swift
// CoreDataManager.swift
class DataManager: ObservableObject {
    @Published var lists: [List] = []
    @Published var archivedLists: [List] = []  // NEW
```

### 2. Added `loadArchivedData()` method

```swift
/// Loads archived lists into the @Published archivedLists property for SwiftUI observation.
func loadArchivedData() {
    let fetchedArchived = loadArchivedLists()

    let updateArchivedLists = { [self] in
        self.objectWillChange.send()
        self.archivedLists = fetchedArchived
    }

    if Thread.isMainThread {
        updateArchivedLists()
    } else {
        DispatchQueue.main.sync {
            updateArchivedLists()
        }
    }
}
```

### 3. Updated MacSidebarView.displayedLists

```swift
// MacMainView.swift (AFTER FIX)
private var displayedLists: [List] {
    if showingArchivedLists {
        // Use cached archivedLists property - sorted by modifiedAt descending
        return dataManager.archivedLists
    } else {
        return dataManager.lists.filter { !$0.isArchived }
            .sorted { $0.orderNumber < $1.orderNumber }
    }
}
```

### 4. Trigger load when toggling to archived view

```swift
.onChange(of: showingArchivedLists) { _, newValue in
    if newValue {
        dataManager.loadArchivedData()
    }
}
```

### 5. Refresh cache after mutations

Updated `deleteList()`, `restoreList()`, and `permanentlyDeleteList()` to call `loadArchivedData()` after operations.

## Key Learnings

1. **Separate data sources need separate loading**: When active and archived lists are loaded with different predicates, they must be stored in separate properties with separate load methods.

2. **SwiftUI observation requires @Published**: Filtering a `@Published` array doesn't create a new observable - the view only updates when the source property changes. Using a dedicated `@Published var archivedLists` ensures proper SwiftUI reactivity.

3. **Consistency across platforms**: iOS used `MainViewModel.archivedLists` while macOS tried to filter `dataManager.lists`. Aligning data layer patterns prevents such bugs.

4. **Cache invalidation matters**: When data can change via multiple paths (archive, restore, permanent delete), all mutation methods must refresh the relevant caches.

## Files Modified

- `ListAll/Models/CoreData/CoreDataManager.swift` - Added property and methods to DataManager
- `ListAllMac/Views/MacMainView.swift` - Updated displayedLists and added onChange trigger
- `ListAllMacTests/TestHelpers.swift` - Updated TestDataManager for test compatibility

## Test Coverage

Added `ArchivedListsTests` class with 11 tests covering:
- Property existence and initial state
- Loading populates archivedLists correctly
- Active vs archived list separation
- Restore updates both lists and archivedLists
- Permanent delete removes from archivedLists
- Sort order (modifiedAt descending)
- Multiple archive/restore operations
- Item preservation during archive
- Cascade delete of items
- Empty state handling

## Date

January 19, 2026
