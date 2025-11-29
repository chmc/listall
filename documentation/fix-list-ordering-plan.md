# Fix List Ordering Bug - Implementation Plan

## Problem Summary

Users report that drag-and-drop list reordering "gets messed up" - the order doesn't persist correctly after app restart or becomes random.

## Root Cause Analysis

### Critical Bug #1: All New Lists Get `orderNumber = 0`

**Location:** `ListAll/ListAll/Models/List.swift:16`

```swift
init(name: String) {
    self.id = UUID()
    self.name = name
    self.orderNumber = 0  // BUG: Always hardcoded to 0!
    // ...
}
```

**Impact:** Every new list gets `orderNumber = 0`, creating duplicates. When Core Data sorts by `orderNumber`, multiple lists with the same value produce non-deterministic ordering.

**Example:**
1. Create List A → orderNumber = 0
2. Create List B → orderNumber = 0 (DUPLICATE!)
3. Create List C → orderNumber = 0 (DUPLICATE!)
4. Core Data sorts → order is undefined/random

### Critical Bug #2: `addList()` Doesn't Assign Unique orderNumber

**Location:** `ListAll/ListAll/Models/CoreData/CoreDataManager.swift:399-413`

```swift
func addList(_ list: List) {
    // ...
    listEntity.orderNumber = Int32(list.orderNumber)  // Always 0!
    // ...
    lists.append(list)
    lists.sort { $0.orderNumber < $1.orderNumber }  // Sort does nothing useful
}
```

The method saves the list with whatever `orderNumber` was passed (always 0) and doesn't calculate the next sequential number.

### Additional Issues Found

| Severity | Issue | Location |
|----------|-------|----------|
| High | `modifiedAt` not updated during drag | `MainViewModel.moveList()` |
| High | Race condition: reload immediately after save | `MainViewModel.moveList():458` |
| Medium | O(n) fetches in loop for order updates | `DataManager.updateListsOrder()` |
| Medium | Watch sync propagates duplicate orderNumbers | `MainViewModel.updateCoreDataWithLists()` |

## Recommended Fix

### Fix 1: Assign Sequential orderNumber in DataManager.addList()

**File:** `ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

**Current code (lines 399-413):**
```swift
func addList(_ list: List) {
    let context = coreDataManager.viewContext
    let listEntity = ListEntity(context: context)
    listEntity.id = list.id
    listEntity.name = list.name
    listEntity.orderNumber = Int32(list.orderNumber)  // BUG: Always 0
    listEntity.createdAt = list.createdAt
    listEntity.modifiedAt = list.modifiedAt
    listEntity.isArchived = false

    saveData()
    lists.append(list)
    lists.sort { $0.orderNumber < $1.orderNumber }
}
```

**Fixed code:**
```swift
func addList(_ list: List) {
    let context = coreDataManager.viewContext
    let listEntity = ListEntity(context: context)
    listEntity.id = list.id
    listEntity.name = list.name

    // FIX: Calculate next orderNumber (new lists go to bottom)
    let maxOrderNumber = lists.map { $0.orderNumber }.max() ?? -1
    let nextOrderNumber = maxOrderNumber + 1
    listEntity.orderNumber = Int32(nextOrderNumber)

    listEntity.createdAt = list.createdAt
    listEntity.modifiedAt = list.modifiedAt
    listEntity.isArchived = false

    saveData()

    // Update the list struct with the assigned orderNumber
    var updatedList = list
    updatedList.orderNumber = nextOrderNumber
    lists.append(updatedList)
    // No need to sort - new list goes to end
}
```

### Fix 2: Update modifiedAt During Drag Operations

**File:** `ListAll/ListAll/ViewModels/MainViewModel.swift`

**Current code (lines 441-465):**
```swift
func moveList(from source: IndexSet, to destination: Int) {
    lists.move(fromOffsets: source, toOffset: destination)

    for (index, list) in lists.enumerated() {
        var updatedList = list
        updatedList.orderNumber = Int(index)
        lists[index] = updatedList
    }

    dataManager.updateListsOrder(lists)
    lists = dataManager.lists  // Potential race condition

    WatchConnectivityService.shared.sendListsData(dataManager.lists)
    hapticManager.dragDropped()
}
```

**Fixed code:**
```swift
func moveList(from source: IndexSet, to destination: Int) {
    lists.move(fromOffsets: source, toOffset: destination)

    // Update order numbers AND modifiedAt for proper sync
    for (index, list) in lists.enumerated() {
        var updatedList = list
        updatedList.orderNumber = index
        updatedList.updateModifiedDate()  // FIX: Update timestamp for sync
        lists[index] = updatedList
    }

    // Persist to Core Data
    dataManager.updateListsOrder(lists)

    // FIX: Don't reload - we already have the correct order in lists
    // The reload was causing a race condition

    // Send updated data to paired device
    WatchConnectivityService.shared.sendListsData(lists)

    hapticManager.dragDropped()
}
```

### Fix 3: Ensure updateListsOrder Uses Correct Data

**File:** `ListAll/ListAll/Models/CoreData/CoreDataManager.swift`

The current `updateListsOrder()` implementation is mostly correct, but ensure it properly updates `modifiedAt`:

```swift
func updateListsOrder(_ newOrder: [List]) {
    let context = coreDataManager.viewContext

    for list in newOrder {
        let request: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", list.id as CVarArg)

        do {
            let results = try context.fetch(request)
            if let listEntity = results.first {
                listEntity.orderNumber = Int32(list.orderNumber)
                listEntity.modifiedAt = list.modifiedAt  // Use the updated timestamp
            }
        } catch {
            print("Failed to update list order for \(list.name): \(error)")
        }
    }

    saveData()
    context.processPendingChanges()
    lists = newOrder
}
```

## Files to Modify

1. **`ListAll/ListAll/Models/CoreData/CoreDataManager.swift`**
   - `addList()` - Calculate next sequential orderNumber
   - `updateListsOrder()` - Ensure modifiedAt is properly saved

2. **`ListAll/ListAll/ViewModels/MainViewModel.swift`**
   - `moveList()` - Call `updateModifiedDate()` and remove race condition reload

## Testing Plan

### Manual Testing Steps

1. **Fresh Install Test:**
   - Create 3 lists (A, B, C)
   - Drag C to top
   - Force-quit app
   - Relaunch → Order should be C, A, B

2. **Delete + Reorder Test:**
   - Create 4 lists (A, B, C, D)
   - Delete B
   - Drag D to top
   - Force-quit and relaunch
   - Order should be D, A, C

3. **Watch Sync Test:**
   - Create lists on iPhone, reorder
   - Verify order matches on Watch
   - Create list on Watch
   - Verify it appears at bottom on both devices

### Unit Test Assertions

```swift
// Test: New lists get unique sequential orderNumbers
func testCreateList_assignsSequentialOrderNumbers() {
    let repo = DataManager.shared
    _ = repo.addList(List(name: "First"))
    _ = repo.addList(List(name: "Second"))
    _ = repo.addList(List(name: "Third"))

    let lists = repo.lists
    XCTAssertEqual(lists[0].orderNumber, 0)
    XCTAssertEqual(lists[1].orderNumber, 1)
    XCTAssertEqual(lists[2].orderNumber, 2)
}

// Test: Reorder persists after reload
func testReorder_persistsAfterReload() {
    let viewModel = MainViewModel()
    _ = try! viewModel.addList(name: "A")
    _ = try! viewModel.addList(name: "B")
    _ = try! viewModel.addList(name: "C")

    viewModel.moveList(from: IndexSet(integer: 2), to: 0)

    // Simulate restart
    let newViewModel = MainViewModel()
    let order = newViewModel.lists.map { $0.name }

    XCTAssertEqual(order, ["C", "A", "B"])
}
```

## Implementation Order

1. **Fix `addList()` in DataManager** - This fixes 80% of the issue
2. **Fix `moveList()` in MainViewModel** - Update modifiedAt, remove reload race condition
3. **Test manually** - Verify ordering works correctly
4. **Run existing tests** - Ensure no regressions
5. **Test Watch sync** - Verify cross-device ordering works

## Design Decision: New Lists at Top or Bottom?

**Recommendation: Bottom (append)**

Reasons:
- Only requires updating 1 list (the new one) vs N lists if inserting at top
- Less Core Data writes
- Less Watch sync traffic
- Standard industry behavior (most apps add new items at bottom of lists)
- Better performance for users with many lists

If users prefer new lists at top, this can be a future settings option.
