# macOS Item Drag-Drop Between Lists Regression (January 2026)

## Problem

The ability to drag items from one list to another on macOS stopped working. Two separate issues caused this:
1. Initially, items could only be dropped onto empty lists or sidebar cells (missing `.dropDestination`)
2. After fixing the drop destination, drag still didn't START at all - clicking down on an item did nothing

## Root Causes

### Root Cause 1: Missing Drop Destination
The `.dropDestination(for: ItemTransferData.self)` modifier was accidentally removed from `itemsListView` in `MacMainView` during subsequent development.

### Root Cause 2: Focus Captures Mouse Clicks (THE REAL ISSUE)
The `.focusable()` modifier added for keyboard navigation (Task 11.1) was capturing all mouse clicks on macOS Sonoma+, preventing drag gestures from starting.

**Key Finding**: In macOS Sonoma (14.0+), the default `.focusable()` modifier supports ALL focus interactions (edit + activate). This means it captures the initial mouse-down event to potentially start text editing, which blocks SwiftUI's drag gesture recognizer from detecting the drag intent.

From Apple's WWDC23: "Prior to macOS Sonoma, the focusable modifier only supported activation semantics. In macOS Sonoma+, it defaults to all interactions."

## Fixes Applied

### Fix 1: Restore Drop Destination
```swift
.listStyle(.inset)
// MARK: - Drop Destination for Cross-List Item Moves
.dropDestination(for: ItemTransferData.self) { droppedItems, _ in
    handleItemDrop(droppedItems)
}
```

### Fix 2: Use `.focusable(interactions: .activate)`
Changed from:
```swift
.draggable(item)
.focusable()  // ❌ Captures mouse clicks, blocks drag
.focused($focusedItemID, equals: item.id)
```

To:
```swift
.draggable(item)
// CRITICAL: Use .activate interactions to prevent focus from capturing
// mouse clicks that should initiate drag gestures. Without this,
// .focusable() on macOS Sonoma+ captures all click interactions,
// blocking drag-and-drop from starting.
.focusable(interactions: .activate)  // ✅ Only activate focus, don't capture clicks
.focused($focusedItemID, equals: item.id)
```

## Why `.focusable(interactions: .activate)` Works

- `interactions: .activate` - Focus is used as alternative to direct pointer activation (clicking). The view becomes focusable for keyboard navigation but doesn't capture mouse events.
- `interactions: .edit` - Focus is used for text editing. The view captures mouse clicks to enter edit mode.
- Default (no argument) - Both behaviors, which captures mouse clicks.

By specifying `.activate`, we tell SwiftUI that this view should be focusable for keyboard navigation purposes only, not for text editing. This allows mouse events to pass through to the drag gesture recognizer.

## Three Drop Destinations Required

MacMainView.swift requires THREE `.dropDestination` modifiers for complete drag-drop support:

1. **Sidebar list cells** (~line 553) - Drop items onto a list in sidebar
2. **Empty list state view** (~line 1395) - Drop items onto empty lists
3. **itemsListView** (~line 1272) - Drop items onto lists with items

## Additional Factors That Can Block Drag (Research)

If drag still doesn't work after these fixes, check for:

1. **Buttons inside draggable rows** - In macOS 15+, Button views can capture mouse events before drag starts. Consider using tap gestures on the parent instead.
2. **Custom NSEvent monitors** - Local event monitors for `.leftMouseDown` can intercept drag events.
3. **Multiple tap gestures** - Even `.simultaneousGesture(TapGesture())` can delay drag recognition.
4. **Order of modifiers** - `.contentShape(Rectangle())` should come before gesture modifiers.

## Prevention Checklist

When modifying MacMainView.swift:
- [ ] Verify 3 `.dropDestination` occurrences exist (search for `dropDestination`)
- [ ] Ensure `.focusable(interactions: .activate)` is used, NOT `.focusable()`
- [ ] Test drag-drop manually between lists with items
- [ ] Test both starting a drag AND completing a drop

## Files Changed

- `ListAll/ListAllMac/Views/MacMainView.swift`
  - Restored `.dropDestination` to itemsListView (~line 1276)
  - Changed `.focusable()` to `.focusable(interactions: .activate)` in THREE places:
    1. **itemsListView** (line 1266) - For item rows in detail view
    2. **selectionModeRow** (line 528) - For sidebar rows in selection mode
    3. **normalModeRow** (line 550) - For sidebar rows in normal mode (has `.draggable(list)`)

## Related Files

- `ListAll/ListAll/Models/Item+Transferable.swift` - ItemTransferData type
- `ListAll/ListAll/Models/List+Transferable.swift` - ListTransferData type

## References

- [WWDC23: The SwiftUI cookbook for focus](https://developer.apple.com/videos/play/wwdc2023/10162/)
- [Apple: focusable(_:interactions:)](https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:))
- [Hacking with Swift: SwiftUI draggable and onTapGesture](https://www.hackingwithswift.com/forums/swiftui/how-to-use-both-draggable-and-ontapgesture/26285)

## Test Coverage Gap

Note: There are no automated UI tests that verify cross-list drag-drop specifically. Consider adding UI tests to prevent future regressions.
