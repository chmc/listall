# macOS Tab Switch Selection Persistence Bug

**Date**: January 2026
**Task**: 13.4 - Fix Selection Persistence Bug When Switching Tabs
**Severity**: CRITICAL

## Problem

When switching between "Active Lists" and "Archived Lists" views in the macOS sidebar, the `selectedList` state variable was NOT cleared. This caused a critical bug:

1. User selects an archived list in "Archived Lists" view
2. User switches to "Active Lists" view
3. `selectedList` STILL holds the archived list
4. Detail view shows archived list UI (Restore button, read-only mode)
5. User sees "Restore" button and cannot add items to what appears to be an active list

## Root Cause

In `MacMainView.swift`, the `.onChange(of: showingArchivedLists)` handler only loaded archived data but didn't clear the selection:

```swift
// BUGGY CODE
.onChange(of: showingArchivedLists) { _, newValue in
    if newValue {
        dataManager.loadArchivedData()
    }
    // MISSING: selectedList = nil
}
```

## Solution

Clear ALL selection state when `showingArchivedLists` changes. The fix requires changes in TWO places because selection state is distributed across views:

### 1. MacMainView (single-list selection)

```swift
// In MacMainView body
.onChange(of: showingArchivedLists) { _, newValue in
    // Clear single-list selection when switching between active/archived views
    selectedList = nil

    if newValue {
        dataManager.loadArchivedData()
    }
}
```

### 2. MacSidebarView (multi-select state)

```swift
// In MacSidebarView body
.onChange(of: showingArchivedLists) { _, _ in
    // Exit selection mode and clear selections when switching tabs
    selectedLists.removeAll()
    isInSelectionMode = false
}
```

**Why two places?** `selectedList` lives in `MacMainView`, while `selectedLists` and `isInSelectionMode` are `@State` in `MacSidebarView`. Both need to be cleared for complete state cleanup.

## Design Principles Learned

### 1. Selection State Must Match Display Context

When switching between different "domains" of data (active vs archived):
- Clear selection to prevent stale references
- A selected item should always exist in the currently displayed list

### 2. UI State vs Data State

This bug arose from confusing two different concepts:
- `showingArchivedLists`: UI state indicating which section user is viewing
- `list.isArchived`: Data property indicating if a specific list is archived

The detail view correctly checks `list.isArchived`, but the sidebar state allowed an archived list to remain selected while viewing active lists.

### 3. SwiftUI @State Persistence

SwiftUI `@State` variables persist across view updates unless explicitly cleared. When using `@State` for selection:
- Consider what should happen when the context changes
- Add clearing logic in `onChange` handlers for related state

## Tests Added

New `TabSwitchSelectionTests` suite verifies:
- Switching from archived to active view clears archived list selection
- Switching from active to archived view clears active list selection
- Selected list must belong to current displayedLists domain
- Active list detail view must not show Restore button
- Active list should allow adding new items

## Prevention

For future similar features:
1. When adding tab/section switching, always consider selection state
2. Write tests for state transitions, not just static property values
3. Ensure invariant: `selectedItem` should always be in `displayedItems`

## Additional Fixes Required

The initial fix (clearing selection on tab switch) was insufficient. Two more bugs persisted:

### Bug 2: Restore Handler Didn't Clear Selection

After restoring a list via the confirmation dialog, `selectedList` wasn't cleared:

```swift
// BUGGY CODE - after restore, stale struct remains selected
Button("Restore") {
    if let list = listToRestore {
        dataManager.restoreList(withId: list.id)
        dataManager.loadArchivedData()
        dataManager.loadData()
    }
    listToRestore = nil
    // MISSING: selectedList = nil
}
```

### Bug 3: `isCurrentListArchived` Used Stale Data

The computed property checked the stale `list` parameter instead of fresh data:

```swift
// BUGGY CODE
private var isCurrentListArchived: Bool {
    list.isArchived  // Stale struct copy, never updates!
}

// FIXED CODE
private var isCurrentListArchived: Bool {
    // Check currentList first (fresh data from dataManager.lists)
    if let current = currentList {
        return current.isArchived
    }
    // If not in active lists, check archivedLists
    if let archived = dataManager.archivedLists.first(where: { $0.id == list.id }) {
        return archived.isArchived
    }
    return list.isArchived  // Fallback
}
```

## Files Modified

- `ListAll/ListAllMac/Views/MacMainView.swift:306-320` - Tab switch selection clearing
- `ListAll/ListAllMac/Views/MacMainView.swift:1034-1039` - Multi-select clearing in MacSidebarView
- `ListAll/ListAllMac/Views/MacMainView.swift:1008` - Restore handler clears selection
- `ListAll/ListAllMac/Views/MacMainView.swift:1210-1222` - `isCurrentListArchived` uses fresh data
- `ListAll/ListAllMacTests/ReadOnlyArchivedListsTests.swift` - Added TabSwitchSelectionTests suite (5 tests)
