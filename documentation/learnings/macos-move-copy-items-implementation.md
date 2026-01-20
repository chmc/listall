---
title: macOS Move/Copy Items Between Lists
date: 2026-01-15
severity: MEDIUM
category: macos
tags: [move-items, copy-items, selection-mode, sheet, confirmation-alert]
symptoms: [macOS missing iOS feature parity for move/copy items]
root_cause: macOS lacked destination list picker UI
solution: Create MacDestinationListPickerSheet with action enum for move vs copy
files_affected: [ListAllMac/Views/MacMainView.swift, ListAllMac/Views/Components/MacDestinationListPickerSheet.swift]
related: [macos-bulk-delete-undo-standardization.md, macos-cmd-click-multi-select.md, macos-item-drag-drop-regression.md]
---

## Problem

macOS needed move/copy items between lists functionality to match iOS.

## Solution

### MacDestinationListPickerSheet

- Sheet view for selecting destination list
- Excludes current list and archived lists
- Displays list name and item count
- Supports creating new list inline
- Uses `MacDestinationListAction` enum for move vs copy

### Flow

1. Enter selection mode (checkmark button)
2. Select items
3. Ellipsis menu -> "Move Items..." or "Copy Items..."
4. MacDestinationListPickerSheet appears
5. Select destination list
6. Confirmation alert shows
7. Confirm -> `viewModel.moveSelectedItems(to:)` or `viewModel.copySelectedItems(to:)`
8. Exit selection mode

### Available Lists Filtering

```swift
private var availableLists: [List] {
    dataManager.lists.filter { $0.id != currentListId && !$0.isArchived }
        .sorted { $0.orderNumber < $1.orderNumber }
}
```

### State Variables

```swift
@State private var showingMoveItemsPicker = false
@State private var showingCopyItemsPicker = false
@State private var selectedDestinationList: List?
@State private var showingMoveConfirmation = false
@State private var showingCopyConfirmation = false
```

## Key Patterns

- SwiftUI `.sheet()` works correctly within NavigationStack
- Used `.alert()` with `isPresented` binding for confirmation
- Reused shared `ListViewModel` methods from iOS implementation
