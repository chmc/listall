# macOS Archived Lists Read-Only Implementation

**Date**: January 2026
**Task**: 13.2 - Make Archived Lists Read-Only
**Platform**: macOS

## Problem

macOS allowed full editing of archived lists (add items, edit items, edit list name, reorder). This defeated the purpose of archiving, which should preserve list state. iOS uses a dedicated `ArchivedListView` that is completely read-only, but macOS was missing this restriction.

## Solution

Made archived lists read-only at the UI level in MacListDetailView by:

1. Adding `isCurrentListArchived` computed property
2. Conditionally hiding/disabling all editing controls
3. Keeping view-only controls (search, filter, share, Quick Look) active

### Key Changes

#### 1. isCurrentListArchived Property

```swift
/// Check if current list is archived (read-only mode)
/// When true, all editing functionality is disabled - only viewing is allowed
private var isCurrentListArchived: Bool {
    list.isArchived
}
```

#### 2. Header View Controls

Updated `headerView` to show different controls based on archived state:
- Archived: Only search, filter/sort, share button, and archived badge
- Active: Full controls including selection mode and edit list button

```swift
if !isCurrentListArchived {
    // Full editing controls
    selectionModeButton
    editListButton
} else {
    // Read-only: only view controls
    searchFieldView
    filterSortControls
    shareButton
}
```

#### 3. Toolbar Add Item Button

Conditionally hidden for archived lists:
```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        if !isCurrentListArchived {
            Button(action: { showingAddItemSheet = true }) {
                Label("Add Item", systemImage: "plus")
            }
        }
    }
}
```

#### 4. MacItemRowView Updates

Added `isArchivedList` parameter to control:
- Completion checkbox: Shows read-only visual state instead of button
- Hover actions: Only Quick Look button visible (no edit/delete)
- Double-click: Disabled (does nothing)
- Context menu: Only Quick Look option (if item has images)

```swift
MacItemRowView(
    item: item,
    isInSelectionMode: viewModel.isInSelectionMode,
    isSelected: viewModel.selectedItems.contains(item.id),
    isArchivedList: isCurrentListArchived,  // New parameter
    ...
)
```

#### 5. Drag-to-Reorder Disabled

```swift
// onMove disabled for archived lists
.onMove(perform: isCurrentListArchived ? nil : handleMoveItem)

// Conditional draggable modifier
.modifier(ConditionalDraggable(item: item, isEnabled: !isCurrentListArchived))
```

#### 6. Keyboard Shortcuts Disabled

All editing shortcuts check `isCurrentListArchived`:
- Space: Only triggers Quick Look for items with images
- Enter: Does not open edit sheet
- Delete: Does not delete items
- Cmd+Option+Up/Down: Does not reorder
- C key: Does not toggle completion

```swift
.onKeyPress(.return) {
    guard !isCurrentListArchived else { return .ignored }
    // ... edit logic
}
```

#### 7. Visual Archived Badge

Added badge in header for visual indication:
```swift
@ViewBuilder
private var archivedBadge: some View {
    HStack(spacing: 4) {
        Image(systemName: "archivebox")
            .font(.caption)
        Text(String(localized: "Archived"))
            .font(.caption)
    }
    .foregroundColor(.secondary)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.secondary.opacity(0.15))
    .cornerRadius(4)
}
```

## Design Decisions

### UI-Level Restriction Only

The read-only restriction is enforced at the UI level, NOT the DataManager level. This is intentional because:
1. DataManager needs to modify archived lists for restore functionality
2. UI restriction is sufficient to prevent accidental user modifications
3. Simpler implementation without backend changes

### What Remains Enabled for Archived Lists

- Search field (searching is viewing)
- Filter/Sort controls (filtering is viewing)
- Share button (sharing is viewing)
- Quick Look for images (viewing images is allowed)
- Navigation and scrolling

### What Is Disabled for Archived Lists

- Add Item button and Cmd+N shortcut
- Edit List button
- Selection mode button
- All item editing (toggle, edit, delete)
- Drag-and-drop reordering
- Keyboard shortcuts for editing (Space toggle, Enter edit, Delete)
- Cmd+Click/Shift+Click multi-select

## Files Modified

- `/ListAll/ListAllMac/Views/MacMainView.swift`
  - Added `isCurrentListArchived` property
  - Updated `headerView` with conditional controls
  - Added `archivedBadge` view
  - Updated `MacItemRowView` with `isArchivedList` parameter
  - Added `ConditionalDraggable` modifier
  - Disabled keyboard shortcuts for archived lists
  - Blocked CreateNewItem notification for archived lists

## Tests Added

19 new tests in `ReadOnlyArchivedListsTests.swift`:
- `testIsCurrentListArchivedReturnsTrue`
- `testIsCurrentListArchivedReturnsFalse`
- `testAddItemButtonHiddenForArchivedList`
- `testEditListButtonHiddenForArchivedList`
- `testSelectionModeButtonHiddenForArchivedList`
- `testItemRowReadOnlyForArchivedList`
- `testItemEditButtonHiddenForArchivedList`
- `testItemDeleteButtonHiddenForArchivedList`
- `testQuickLookButtonVisibleForArchivedList`
- `testDragReorderDisabledForArchivedList`
- `testContextMenuReadOnlyForArchivedList`
- `testSpaceKeyBehaviorForArchivedList`
- `testEnterKeyBehaviorForArchivedList`
- `testDeleteKeyBehaviorForArchivedList`
- `testKeyboardReorderingDisabledForArchivedList`
- `testShareButtonVisibleForArchivedList`
- `testFilterSortVisibleForArchivedList`
- `testArchivedBadgeDisplayed`
- `testArchivedListItemsNotModifiableViaUI` (integration test)

## Verification

- All 210 ListAllMacTests pass
- macOS build succeeds without errors
- Feature parity with iOS ArchivedListView achieved

## Related Tasks

- Task 13.1: Add Restore Functionality (completed) - enables restoring archived lists
- Task 13.3: Update Documentation Status - next step
