# macOS Item Drag-Drop Between Lists Regression (January 2026)

## Problem

The ability to drag items from one list to another on macOS stopped working when the target list already contained items. Items could only be dropped onto:
1. Empty lists (empty state view)
2. Sidebar list cells

## Root Cause

The `.dropDestination(for: ItemTransferData.self)` modifier was accidentally removed from `itemsListView` in `MacListDetailView` during subsequent development after the initial implementation in commit d32902d.

## Original Implementation (commit d32902d)

```swift
// itemsListView had .dropDestination after .listStyle(.inset)
.listStyle(.inset)
.dropDestination(for: ItemTransferData.self) { droppedItems, _ in
    handleItemDrop(droppedItems)
}
```

## What Was Missing

The `itemsListView` (SwiftUI.List containing ForEach of items) was missing the `.dropDestination` modifier, meaning:
- Dragging items FROM a list worked (`.draggable(item)` was present)
- Dropping items ONTO a list with items did NOT work (modifier was missing)
- Dropping onto empty lists worked (empty state view had the modifier)
- Dropping onto sidebar list cells worked (sidebar had the modifier)

## Fix Applied

Added back the `.dropDestination(for: ItemTransferData.self)` modifier to `itemsListView`:

```swift
.listStyle(.inset)
// MARK: - Drop Destination for Cross-List Item Moves
// Enable dropping items from other lists onto this list
.dropDestination(for: ItemTransferData.self) { droppedItems, _ in
    handleItemDrop(droppedItems)
}
.accessibilityIdentifier("ItemsList")
```

## Three Drop Destinations Required

MacMainView.swift requires THREE `.dropDestination` modifiers for complete drag-drop support:

1. **Sidebar list cells** (~line 553) - Drop items onto a list in sidebar
2. **Empty list state view** (~line 1395) - Drop items onto empty lists
3. **itemsListView** (~line 1257) - Drop items onto lists with items

## Prevention

When modifying MacMainView.swift, ensure all three dropDestination locations remain:
- Search for `dropDestination` and verify there are 3 occurrences
- Test drag-drop manually between lists with items

## Files Changed

- `ListAll/ListAllMac/Views/MacMainView.swift` - Restored `.dropDestination` to itemsListView

## Related Files

- `ListAll/ListAll/Models/Item+Transferable.swift` - ItemTransferData type
- `ListAll/ListAll/Models/List+Transferable.swift` - ListTransferData type

## Test Coverage Gap

Note: There are no automated UI tests that verify cross-list drag-drop specifically. Consider adding UI tests to prevent future regressions.
