---
title: macOS Tab Switch Selection Persistence Bug
date: 2026-01-15
severity: CRITICAL
category: macos
tags: [selection-state, tab-switch, swiftui-state, archived-lists]
symptoms:
  - User switches from Archived to Active Lists view
  - selectedList still holds archived list
  - Detail view shows archived list UI (Restore button, read-only mode)
  - User sees Restore button on what appears to be active list
  - Cannot add items to selected list
root_cause: Selection state not cleared when switching showingArchivedLists tabs
solution: Clear selectedList, selectedLists, and isInSelectionMode when showingArchivedLists changes
files_affected:
  - ListAll/ListAllMac/Views/MacMainView.swift
  - ListAll/ListAllMacTests/ReadOnlyArchivedListsTests.swift
related: [macos-archived-lists-read-only.md, macos-archived-lists-empty-view-fix.md, macos-bulk-list-archive-delete.md]
---

## The Bug

When switching between "Active Lists" and "Archived Lists" views, `selectedList` was NOT cleared:

```swift
// BUGGY CODE
.onChange(of: showingArchivedLists) { _, newValue in
    if newValue {
        dataManager.loadArchivedData()
    }
    // MISSING: selectedList = nil
}
```

## Solution: Clear ALL Selection State

Fix requires changes in TWO places because selection state is distributed:

### 1. MacMainView (single-list selection)

```swift
.onChange(of: showingArchivedLists) { _, newValue in
    selectedList = nil  // Clear single-list selection
    if newValue {
        dataManager.loadArchivedData()
    }
}
```

### 2. MacSidebarView (multi-select state)

```swift
.onChange(of: showingArchivedLists) { _, _ in
    selectedLists.removeAll()
    isInSelectionMode = false
}
```

## Additional Bugs Found

### Bug 2: Restore Handler Missing Selection Clear

After restoring list via confirmation dialog, `selectedList` wasn't cleared:

```swift
// FIX: Add selectedList = nil after restore
Button("Restore") {
    if let list = listToRestore {
        dataManager.restoreList(withId: list.id)
        dataManager.loadArchivedData()
        dataManager.loadData()
    }
    listToRestore = nil
    selectedList = nil  // ADDED
}
```

### Bug 3: isCurrentListArchived Used Stale Data

Computed property checked stale `list` parameter instead of fresh data:

```swift
// FIX: Check fresh data from dataManager
private var isCurrentListArchived: Bool {
    if let current = currentList {
        return current.isArchived  // Fresh from dataManager.lists
    }
    if let archived = dataManager.archivedLists.first(where: { $0.id == list.id }) {
        return archived.isArchived
    }
    return list.isArchived  // Fallback
}
```

## Design Principles

### Selection State Must Match Display Context

When switching between data domains (active vs archived):
- Clear selection to prevent stale references
- Selected item should always exist in currently displayed list

### SwiftUI @State Persistence

`@State` variables persist across view updates unless explicitly cleared. When using `@State` for selection:
- Consider what happens when context changes
- Add clearing logic in `onChange` handlers for related state

## Prevention

- When adding tab/section switching, always consider selection state
- Write tests for state transitions, not just static property values
- Ensure invariant: `selectedItem` should always be in `displayedItems`

## Tests Added

New `TabSwitchSelectionTests` suite verifies:
- Switching from archived to active view clears archived list selection
- Switching from active to archived view clears active list selection
- Selected list must belong to current displayedLists domain
- Active list detail view must not show Restore button
- Active list should allow adding new items
