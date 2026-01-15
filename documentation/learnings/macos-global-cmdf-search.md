# macOS Global Cmd+F Search Scope Implementation

**Date**: January 15, 2026
**Task**: Task 12.2 - Fix Cmd+F Global Search Scope

## Problem

Cmd+F only worked when focus was already in the detail pane. If focus was in the sidebar, Cmd+F did nothing - even though the Feature Tips claimed "Press Cmd+F to search across all items." This violated macOS conventions where keyboard shortcuts should work globally within the window regardless of focus location.

## Root Cause

The existing Cmd+F handler was placed inside `MacListDetailView` using `.onKeyPress`:

```swift
// MacListDetailView (line ~1623)
.onKeyPress(characters: CharacterSet(charactersIn: "f")) { keyPress in
    guard keyPress.modifiers.contains(.command) else { return .ignored }
    isSearchFieldFocused = true
    return .handled
}
```

Since `.onKeyPress` only triggers when the view or its descendants have focus, Cmd+F was captured only when the detail view was focused. When focus was in the sidebar (another branch of the `NavigationSplitView`), the event was never caught.

## Solution

Used a notification pattern consistent with existing patterns in the codebase (e.g., "ItemEditingStarted"):

### 1. Global Handler in MacMainView

Added a global Cmd+F handler at the `NavigationSplitView` level that posts a notification:

```swift
// MacMainView body, after NavigationSplitView
.onKeyPress(characters: CharacterSet(charactersIn: "f")) { keyPress in
    guard keyPress.modifiers.contains(.command) else { return .ignored }

    // If no list selected, select the first one (if available)
    if selectedList == nil, let firstList = dataManager.lists.first {
        selectedList = firstList
        // Slight delay to allow detail view to appear before focusing search
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
        }
    } else if selectedList != nil {
        // List already selected, just focus search
        NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
    }
    return .handled
}
```

### 2. Notification Receiver in MacListDetailView

Added a receiver that sets the `@FocusState` when the notification is received:

```swift
// MacListDetailView, after .onAppear
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusSearchField"))) { _ in
    isSearchFieldFocused = true
}
```

### 3. Kept Existing Handler

The existing `.onKeyPress` handler in MacListDetailView was kept for redundancy - it provides a more direct path when focus is already in the detail view.

## Key Design Decisions

1. **Notification Pattern**: Used `NotificationCenter.default` for decoupled communication between parent (MacMainView) and child (MacListDetailView), consistent with existing patterns like "ItemEditingStarted" and "ItemEditingEnded".

2. **No List Selected Edge Case**: When Cmd+F is pressed with no list selected, the implementation automatically selects the first available list and posts the notification with a 100ms delay to allow the detail view to render.

3. **Empty State Handling**: If no lists exist at all, the handler gracefully does nothing (returns `.handled` to prevent the key event from bubbling).

## Files Modified

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift`:
  - Added global Cmd+F handler after `.frame(minWidth: 800, minHeight: 600)` (lines 146-166)
  - Added notification receiver in MacListDetailView after `.onAppear` (lines 1656-1661)

## Tests

14 tests in `CmdFGlobalSearchTests` class verify:
- Notification name exists
- Notification can be posted and received
- Focus state tracking works correctly
- Edge cases (no list selected, no lists available)
- Multiple observers receive notification
- Observer cleanup (no memory leaks)
- Consistency with existing notification patterns

## Lessons Learned

1. **Use View Hierarchy for Scope**: SwiftUI's `.onKeyPress` captures events only within that view's focus scope. For window-global shortcuts, place the handler at the top-level view.

2. **Notification Pattern for Focus Management**: When you need to control focus across view boundaries in SwiftUI, notifications provide a clean solution. The parent posts the notification, and the child (which owns the `@FocusState`) responds.

3. **Edge Case Handling**: Always handle the case where the target view may not exist yet (no list selected). Use a brief delay when transitioning states before posting the notification.

4. **Redundancy for Better UX**: Keeping both the global handler (via notification) and the local handler (direct) provides faster response when focus is already in the right place.

## References

- Existing pattern: "ItemEditingStarted" / "ItemEditingEnded" notifications
- Apple HIG: Keyboard shortcuts for macOS
- SwiftUI FocusState documentation
