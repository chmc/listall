# macOS Cmd+Click Multi-Select Implementation

**Date**: January 15, 2026
**Task**: Task 12.1 - Implement Cmd+Click Multi-Select

## Problem

macOS users expect Cmd+Click to select multiple items without entering a special mode. The ListAll macOS app previously required clicking a toolbar button to enter "selection mode" first - this violated fundamental macOS conventions where Cmd+Click and Shift+Click should work immediately.

## Challenge

The existing codebase explicitly warned against using `.onTapGesture` or `.simultaneousGesture(TapGesture())` because they block drag-and-drop functionality (documented in `macos-item-drag-drop-regression.md`). The challenge was implementing Cmd+Click and Shift+Click selection WITHOUT breaking drag-and-drop.

## Solution

Used NSEvent local monitoring (same pattern as existing `.onDoubleClick` modifier) to detect modifier clicks on mouseUp rather than mouseDown.

### Key Insights

1. **NSEvent monitoring does NOT block events** - The local event monitor returns the event to continue processing, allowing drag-and-drop to work normally.

2. **Use mouseUp detection, not mouseDown** - Detecting clicks on mouseUp avoids interfering with drag initiation which starts on mouseDown.

3. **Distance and time thresholds distinguish clicks from drags**:
   - Time threshold: 300ms (0.3 seconds)
   - Distance threshold: 5 points
   - A "click" is: short duration AND minimal mouse movement

4. **Anchor point tracking for range selection** - `lastSelectedItemID` stores the anchor point for Shift+Click range selection.

## Implementation

### ListViewModel Changes

```swift
// New property for anchor point
@Published var lastSelectedItemID: UUID?

// Range selection method
func selectRange(to targetId: UUID) {
    guard let anchorId = lastSelectedItemID,
          let anchorIndex = filteredItems.firstIndex(where: { $0.id == anchorId }),
          let targetIndex = filteredItems.firstIndex(where: { $0.id == targetId }) else {
        // No anchor - single selection
        selectedItems = [targetId]
        lastSelectedItemID = targetId
        return
    }

    // Select range using min/max (handles both directions)
    let startIndex = min(anchorIndex, targetIndex)
    let endIndex = max(anchorIndex, targetIndex)
    selectedItems = Set(filteredItems[startIndex...endIndex].map { $0.id })
}
```

### ModifierClickHandler View Modifier

```swift
private class ModifierClickMonitorNSView: NSView {
    // Track mouseDown location and time
    private var mouseDownLocation: NSPoint?
    private var mouseDownTime: Date?

    // Event monitor for both mouseDown and mouseUp
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
        if event.type == .leftMouseDown && event.clickCount == 1 {
            // Record mouseDown state
            self.mouseDownLocation = locationInView
            self.mouseDownTime = Date()
        } else if event.type == .leftMouseUp {
            // Check if this was a click (not a drag)
            let timeDelta = Date().timeIntervalSince(mouseDownTime)
            let distance = hypot(locationInView.x - mouseDownLocation.x,
                                locationInView.y - mouseDownLocation.y)

            let isClick = timeDelta < 0.3 && distance < 5

            if isClick && event.clickCount == 1 {
                if event.modifierFlags.contains(.command) {
                    // Cmd+Click
                } else if event.modifierFlags.contains(.shift) {
                    // Shift+Click
                }
            }
        }
        return event  // CRITICAL: Let event continue to other handlers
    }
}
```

### Usage in Item Row

```swift
makeItemRow(item: item)
    .draggable(item)
    .onModifierClick(
        command: { viewModel.toggleSelection(for: item.id) },
        shift: { viewModel.selectRange(to: item.id) }
    )
```

## Key Files Modified

- `ListAll/ViewModels/ListViewModel.swift` - Added `lastSelectedItemID`, `selectRange(to:)`, `handleClick(for:commandKey:shiftKey:)`
- `ListAllMac/Views/MacMainView.swift` - Added `ModifierClickHandler`, `ModifierClickMonitorView`, `ModifierClickMonitorNSView`
- `ListAllMacTests/TestHelpers.swift` - Updated `TestListViewModel` with matching API

## Lessons Learned

1. **Follow existing patterns** - The codebase already had `.onDoubleClick` using NSEvent monitoring. Extending this pattern was safer than inventing new approaches.

2. **Test double synchronization** - When adding methods to production code, remember to update test doubles (TestListViewModel) to maintain API consistency.

3. **mouseUp vs mouseDown** - For detecting clicks without blocking drags, monitor mouseUp and verify the mouse didn't move significantly from mouseDown.

4. **Range selection uses filtered items** - The `selectRange(to:)` method correctly uses `filteredItems` order, respecting any active filters.

5. **Anchor point management** - Only update anchor when SELECTING (not when deselecting via Cmd+Click).

## References

- Apple HIG: Selection patterns
- NSEvent.addLocalMonitorForEvents documentation
- Finder, Mail, Notes selection behavior
