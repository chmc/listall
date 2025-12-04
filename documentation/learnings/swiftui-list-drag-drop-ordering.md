# SwiftUI List Drag-and-Drop Ordering Bug

## Problem Summary

Lists drag-and-drop reordering showed wrong order after dropping, while Items drag-and-drop worked perfectly. The bug manifested in stages:
1. First: Nearby list would also move incorrectly
2. After partial fix: Dragged list would drop one position off
3. Manual sync operation fixed the order, Watch showed correct order immediately

## Root Causes (Multiple Issues)

The bug had **three** causes that needed fixing to achieve full DRY compliance with items:

### Issue 1: Raw Indices vs ID-Based Lookup
Lists used raw indices from SwiftUI's `onMove` callback directly. Items used ID-based lookup.

### Issue 2: Using Different Arrays
Lists ViewModel used `lists` for UI but passed indices to repository which used `dataManager.lists`. Items uses the same array (`items`) consistently.

### Issue 3: Cached vs Fresh Data in Repository
`reorderLists()` used cached `dataManager.lists`. `reorderItems()` uses fresh `getItems(forListId:)` fetch.

## The Complete Fix (DRY: Exact Same Pattern as Items)

### 1. MainViewModel.moveList() - Same Pattern as moveSingleItem()

```swift
func moveList(from source: IndexSet, to destination: Int) {
    // DRY: Exact same pattern as ListViewModel.moveSingleItem()
    // CRITICAL: Use the same array (lists) for all operations

    guard let uiSourceIndex = source.first else { return }
    guard uiSourceIndex < lists.count else { return }

    // Get the actual list being dragged (from UI array)
    let movedList = lists[uiSourceIndex]

    // Calculate destination in UI array (same as items: filteredDestIndex)
    let uiDestIndex = destination > uiSourceIndex ? destination - 1 : destination

    // Get the destination list (same pattern as items: destinationItem)
    let destinationList = uiDestIndex < lists.count ? lists[uiDestIndex] : lists.last

    // Find actual indices in the SAME array (same as items uses `items`)
    // CRITICAL: Use `lists` not `dataManager.lists`!
    guard let actualSourceIndex = lists.firstIndex(where: { $0.id == movedList.id }) else { return }

    let actualDestIndex: Int
    if let destList = destinationList,
       let destIndex = lists.firstIndex(where: { $0.id == destList.id }) {
        actualDestIndex = destIndex
    } else {
        actualDestIndex = lists.count - 1
    }

    guard actualSourceIndex != actualDestIndex else { return }

    dataRepository.reorderLists(from: actualSourceIndex, to: actualDestIndex)
    lists = dataManager.getLists()
    hapticManager.dragDropped()
}
```

### 2. DataRepository.reorderLists() - Same Pattern as reorderItems()

```swift
func reorderLists(from sourceIndex: Int, to destinationIndex: Int) {
    // DRY: Same pattern as reorderItems() - use fresh fetch
    // CRITICAL: Use getLists() not dataManager.lists
    let currentLists = dataManager.getLists()

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
        dataManager.updateList(list)
    }

    watchConnectivityService.sendListsData(dataManager.lists)
}
```

### 3. DataManager.getLists() - Mirrors getItems()

```swift
func getLists() -> [List] {
    let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
    request.predicate = NSPredicate(format: "isArchived == NO OR isArchived == nil")
    request.sortDescriptors = [NSSortDescriptor(keyPath: \ListEntity.orderNumber, ascending: true)]
    request.relationshipKeyPathsForPrefetching = ["items"]

    do {
        let listEntities = try coreDataManager.viewContext.fetch(request)
        return listEntities.map { $0.toList() }
    } catch {
        print("❌ Failed to fetch lists: \(error)")
        return []
    }
}
```

## Key Learnings

### 1. Use Same Array Consistently
Don't mix UI array (`lists`) with data array (`dataManager.lists`). Use the same array for:
- Getting source/destination items
- Finding actual indices
- All operations in a single drag-drop flow

### 2. Fresh Fetch in Repository
Repository methods should fetch fresh data, not use cached arrays:
- `reorderItems()` uses `getItems(forListId:)` ✓
- `reorderLists()` should use `getLists()` ✓

### 3. ID-Based Lookup
Never trust raw indices from SwiftUI's `onMove` callback:
1. Get SOURCE item by ID from UI array
2. Get DESTINATION item by position from UI array
3. Find both items' indices in data array using `firstIndex(where: { $0.id == item.id })`

### 4. DRY Means EXACT Same Pattern
Items worked because every layer used fresh fetches and consistent arrays. Lists needed the EXACT same pattern at every layer:
- ViewModel: Same index calculation logic
- Repository: Same fresh-fetch pattern
- DataManager: Same `get*()` method pattern

### 5. Watch Sync as Debugging Tool
When Watch shows correct data but iOS doesn't, the data layer is correct. Look for UI/index mapping issues.

## Files Changed

- `ListAll/ListAll/ViewModels/MainViewModel.swift` - ID-based lookup using consistent array
- `ListAll/ListAll/Services/DataRepository.swift` - Fresh fetch in `reorderLists()`
- `ListAll/ListAll/Models/CoreData/CoreDataManager.swift` - Added `getLists()` method

## Related Files (Working Reference)

- `ListAll/ListAll/ViewModels/ListViewModel.swift` - Working `moveSingleItem()` (lines 287-309)
- `ListAll/ListAll/Services/DataRepository.swift` - Working `reorderItems()` (lines 223-250)
