# SwiftUI List Drag-and-Drop Ordering Bug

## Problem Summary

Lists drag-and-drop reordering showed wrong order after dropping. The dragged list would drop one position off from where expected, and sometimes a nearby list would also move incorrectly. Manual sync operation fixed the order, and Watch showed correct order immediately.

## Root Cause

**The lists drag-and-drop was NOT using the same implementation pattern as items drag-and-drop.**

Key observation from user: Items have a "little freeze" when drag is released, but lists didn't - this indicated fundamentally different implementations.

The working items implementation:
1. Uses `DataRepository.reorderItems()` with remove/insert pattern
2. Converts SwiftUI indices to actual indices via ID-based lookup
3. Calls `loadItems()` after reordering (causes the "freeze")

The broken lists implementation:
1. Used `Array.move(fromOffsets:toOffset:)` directly on ViewModel array
2. Bypassed `DataRepository.reorderLists()`
3. Had timing issues with Core Data persistence

## The Solution: DRY - Use EXACT Same Pattern as Items

The fix makes `MainViewModel.moveList()` match `ListViewModel.moveSingleItem()` exactly:

```swift
func moveList(from source: IndexSet, to destination: Int) {
    // DRY: Use EXACT same pattern as ListViewModel.moveItems()
    guard let sourceIndex = source.first else { return }

    // Get the actual list being dragged
    let movedList = lists[sourceIndex]

    // Calculate destination index using the same logic as items
    let destIndex = destination > sourceIndex ? destination - 1 : destination
    let destinationList = destIndex < lists.count ? lists[destIndex] : lists.last

    // Find the actual indices using ID-based lookup (matches moveSingleItem)
    guard let actualSourceIndex = lists.firstIndex(where: { $0.id == movedList.id }) else { return }

    let actualDestIndex: Int
    if let destList = destinationList,
       let destIdx = lists.firstIndex(where: { $0.id == destList.id }) {
        actualDestIndex = destIdx
    } else {
        actualDestIndex = lists.count - 1
    }

    // Use DataRepository.reorderLists() - matches items using reorderItems()
    dataRepository.reorderLists(from: actualSourceIndex, to: actualDestIndex)

    // Refresh the list (causes the "freeze" effect that confirms persistence)
    loadLists()

    hapticManager.dragDropped()
}
```

## Why This Works

### 1. ID-Based Index Lookup
Using `firstIndex(where: { $0.id == item.id })` ensures we're working with actual array positions, not SwiftUI's complex destination semantics.

### 2. DataRepository Handles Persistence
`DataRepository.reorderLists()` and `reorderItems()` both:
- Fetch fresh data from Core Data
- Use `remove(at:)` and `insert(at:)` pattern
- Update all order numbers
- Sync to Watch

### 3. Refresh After Reorder
Calling `loadLists()` / `loadItems()` after reordering:
- Ensures UI matches persisted state
- Causes the "freeze" effect that confirms the operation completed
- Prevents race conditions with SwiftUI's animation

## Key Learnings

### 1. DRY Principle Prevents Bugs
When two features should behave identically, they MUST use identical implementation patterns. Different implementations = different bugs.

### 2. Visual Cues Indicate Implementation Differences
The "freeze" on items vs no freeze on lists was a critical debugging clue that the implementations were different.

### 3. Watch Sync as Debugging Tool
When Watch shows correct data but iOS doesn't, the data layer is correct. Look for UI/ViewModel handling issues.

### 4. SwiftUI onMove Destination Semantics
The `destination` parameter has complex "insert before" semantics:
- Moving UP: `destination` IS the final position
- Moving DOWN: `destination` is one PAST the final position

Using ID-based lookup sidesteps this complexity.

## Files Changed

- `ListAll/ListAll/ViewModels/MainViewModel.swift` - Rewrote `moveList()` to match items pattern
- `ListAll/ListAll/Services/DataRepository.swift` - `reorderLists()` already had correct remove/insert pattern

## References

- [Apple: move(fromOffsets:toOffset:)](https://developer.apple.com/documentation/swift/mutablecollection/move(fromoffsets:tooffset:))
- [How to let users move rows in a list - Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-let-users-move-rows-in-a-list)
