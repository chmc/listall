# SwiftUI List Drag-and-Drop Ordering Bug

## Problem Summary

Lists drag-and-drop reordering showed wrong order after dropping, while Items drag-and-drop worked perfectly. The list would appear to drop in the correct position, but then jump to the wrong position.

**Key observation**: Watch app showed the correct order immediately after drag-drop, proving the data was correct. Manual sync operation also fixed the order. The bug was a race condition in the iOS reload logic.

## Symptoms

1. Long press list to drag to another position
2. Drop appears correct momentarily
3. List jumps to wrong position
4. Manual sync shows correct order (Core Data is correct)
5. Watch app shows correct order immediately (data is correct)

## Root Cause

Race condition in `MainViewModel.moveList()`:

```swift
// BROKEN - Race condition
func moveList(from source: IndexSet, to destination: Int) {
    // Step 1: Update Core Data and in-memory lists
    reorderLists(from: sourceIndex, to: actualDestIndex)

    // Step 2: Reload from Core Data - BUG HERE!
    loadLists()  // <-- Calls dataManager.loadData() which reloads from Core Data
                 //     BEFORE persistence is fully complete

    hapticManager.dragDropped()
}

func loadLists() {
    dataManager.loadData()  // <-- This reloads from Core Data, reading STALE data
    lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }
}
```

**The race condition**:
1. `reorderLists()` updates Core Data via `dataManager.updateList()` for each list
2. `dataManager.updateList()` ALSO updates the in-memory `lists` array (line 463-465 in CoreDataManager.swift)
3. `loadLists()` calls `dataManager.loadData()` which reloads EVERYTHING from Core Data
4. If Core Data hasn't fully committed, `loadData()` reads **stale data**
5. UI shows wrong order

**Why Watch worked**: Watch received data via `sendListsData(dataManager.lists)` which reads the **in-memory** `lists` array that was already updated - it doesn't reload from Core Data.

## The Fix

### 1. Add `reorderLists()` to DataRepository (DRY Principle)

Items had `DataRepository.reorderItems()` but Lists bypassed the repository pattern. Added matching method:

```swift
// DataRepository.swift
func reorderLists(from sourceIndex: Int, to destinationIndex: Int) {
    let currentLists = dataManager.lists

    guard sourceIndex >= 0,
          destinationIndex >= 0,
          sourceIndex < currentLists.count,
          destinationIndex < currentLists.count,
          sourceIndex != destinationIndex else {
        return
    }

    var reorderedLists = currentLists
    let movedList = reorderedLists.remove(at: sourceIndex)
    reorderedLists.insert(movedList, at: destinationIndex)

    for (index, var list) in reorderedLists.enumerated() {
        list.orderNumber = index
        list.updateModifiedDate()
        dataManager.updateList(list)  // Updates Core Data AND in-memory array
    }

    watchConnectivityService.sendListsData(dataManager.lists)
}
```

### 2. Update MainViewModel to Avoid Race Condition

```swift
// MainViewModel.swift
private let dataRepository = DataRepository()

func moveList(from source: IndexSet, to destination: Int) {
    guard let sourceIndex = source.first else { return }
    guard sourceIndex < lists.count else { return }

    let actualDestIndex = destination > sourceIndex ? destination - 1 : destination
    guard actualDestIndex >= 0, actualDestIndex < lists.count, sourceIndex != actualDestIndex else {
        return
    }

    // Use DataRepository (DRY - same pattern as items)
    dataRepository.reorderLists(from: sourceIndex, to: actualDestIndex)

    // Read in-memory data directly - DON'T call loadLists() which triggers loadData()
    lists = dataManager.lists.sorted { $0.orderNumber < $1.orderNumber }

    hapticManager.dragDropped()
}
```

**Key insight**: `dataManager.updateList()` updates BOTH Core Data AND the in-memory `lists` array. Reading `dataManager.lists` directly gets the fresh in-memory data without reloading from Core Data.

## Why This Works

1. `dataRepository.reorderLists()` calls `dataManager.updateList()` for each list
2. `updateList()` saves to Core Data AND updates `lists[index] = list` in memory
3. Reading `dataManager.lists.sorted()` gets the fresh in-memory data
4. No `loadData()` call = no Core Data reload = no race condition

## Key Learnings

### 1. In-Memory vs Core Data Reload
`dataManager.updateList()` updates both Core Data AND the in-memory array. Reading the in-memory array directly is safe and avoids race conditions with Core Data persistence.

### 2. loadData() Is Expensive and Risky
`loadData()` reloads everything from Core Data. If called immediately after updates, it may read stale data. Only call it when you need fresh data from disk (e.g., after Watch sync).

### 3. Follow DRY - Use Repository Pattern
Items used `DataRepository.reorderItems()`, Lists bypassed the repository. Both should use the same pattern:
- Repository handles: validation, reordering, Core Data update, Watch sync
- ViewModel handles: index calculation, UI update, haptic feedback

### 4. Watch Sync as Debugging Tool
When Watch shows correct data but iOS doesn't, the data layer is correct - look for UI/reload timing issues.

### 5. Compare Working vs Broken Implementations
The fix was found by comparing Items (working) vs Lists (broken):
- Items: Uses DataRepository, doesn't call `loadData()` after reorder
- Lists: Bypassed repository, called `loadLists()` which triggered `loadData()`

## Files Changed

- `ListAll/ListAll/Services/DataRepository.swift` - Added `reorderLists()` method
- `ListAll/ListAll/ViewModels/MainViewModel.swift` - Use DataRepository, avoid `loadData()` call

## Related Files (Working Reference)

- `ListAll/ListAll/ViewModels/ListViewModel.swift` - Working Items ViewModel with `reorderItems()`
- `ListAll/ListAll/Services/DataRepository.swift` - `reorderItems()` reference implementation
- `ListAll/ListAll/Models/CoreData/CoreDataManager.swift` - `updateList()` updates in-memory array (lines 463-465)
