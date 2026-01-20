---
title: macOS Cmd+Click Multi-Select Implementation
date: 2026-01-15
severity: CRITICAL
category: macos
tags: [cmd-click, shift-click, nsevent, multi-select, drag-and-drop, mouseup]
symptoms: [Cannot use Cmd+Click without entering selection mode, onTapGesture blocks drag-and-drop]
root_cause: onTapGesture and simultaneousGesture(TapGesture()) block drag-and-drop functionality
solution: Use NSEvent local monitoring on mouseUp to detect modifier clicks without blocking drags
files_affected: [ListAll/ViewModels/ListViewModel.swift, ListAllMac/Views/MacMainView.swift, ListAllMacTests/TestHelpers.swift]
related: [macos-item-drag-drop-regression.md]
---

## Problem

macOS users expect Cmd+Click for multi-select without entering a special mode. However:
- `.onTapGesture` blocks drag-and-drop
- `.simultaneousGesture(TapGesture())` also blocks drag-and-drop

## Solution

Use NSEvent local monitoring (same pattern as `.onDoubleClick`).

### Key Insights

1. **NSEvent monitoring does NOT block events** - returns event to continue processing
2. **Use mouseUp, not mouseDown** - avoids interfering with drag initiation
3. **Distance/time thresholds distinguish clicks from drags**:
   - Time threshold: 300ms
   - Distance threshold: 5 points

### ModifierClickHandler

```swift
private class ModifierClickMonitorNSView: NSView {
    private var mouseDownLocation: NSPoint?
    private var mouseDownTime: Date?

    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
        if event.type == .leftMouseDown && event.clickCount == 1 {
            self.mouseDownLocation = locationInView
            self.mouseDownTime = Date()
        } else if event.type == .leftMouseUp {
            let timeDelta = Date().timeIntervalSince(mouseDownTime)
            let distance = hypot(locationInView.x - mouseDownLocation.x,
                                locationInView.y - mouseDownLocation.y)

            let isClick = timeDelta < 0.3 && distance < 5

            if isClick && event.clickCount == 1 {
                if event.modifierFlags.contains(.command) {
                    // Cmd+Click handler
                } else if event.modifierFlags.contains(.shift) {
                    // Shift+Click handler
                }
            }
        }
        return event  // CRITICAL: Let event continue
    }
}
```

### ViewModel Range Selection

```swift
@Published var lastSelectedItemID: UUID?

func selectRange(to targetId: UUID) {
    guard let anchorId = lastSelectedItemID,
          let anchorIndex = filteredItems.firstIndex(where: { $0.id == anchorId }),
          let targetIndex = filteredItems.firstIndex(where: { $0.id == targetId }) else {
        selectedItems = [targetId]
        lastSelectedItemID = targetId
        return
    }

    let startIndex = min(anchorIndex, targetIndex)
    let endIndex = max(anchorIndex, targetIndex)
    selectedItems = Set(filteredItems[startIndex...endIndex].map { $0.id })
}
```

### Usage

```swift
makeItemRow(item: item)
    .draggable(item)
    .onModifierClick(
        command: { viewModel.toggleSelection(for: item.id) },
        shift: { viewModel.selectRange(to: item.id) }
    )
```

## Key Learnings

1. **Follow existing patterns** - codebase had `.onDoubleClick` using NSEvent; extend it
2. **Update test doubles** - when adding methods, update TestListViewModel
3. **Range selection uses filteredItems** - respects active filters
4. **Anchor point management** - only update anchor when SELECTING (not deselecting)
