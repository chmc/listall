---
title: Standardizing Bulk Delete with Undo Banners
date: 2026-01-15
severity: HIGH
category: macos
tags: [swiftui, undo, delete, ux, consistency, haptics]
symptoms: [bulk delete uses confirmation dialog, individual delete uses undo banner, inconsistent patterns]
root_cause: Bulk delete used "cannot be undone" dialog while individual delete used undo banner
solution: Replaced bulk delete dialog with undo banner pattern matching individual delete
files_affected: [ListAll/ViewModels/ListViewModel.swift, ListAllMac/Views/MacMainView.swift, ListAllMacTests/TestHelpers.swift]
related: [macos-undo-banners-implementation.md, macos-bulk-list-archive-delete.md, macos-move-copy-items-implementation.md]
---

## Problem

Inconsistent delete behavior violated macOS design principle:
- **Individual delete**: Undo banner with 5-second timeout (good)
- **Bulk delete**: Confirmation dialog "cannot be undone" (bad)

Recoverable actions should use undo, not confirmation dialogs.

## Solution

Extended ListViewModel with bulk delete undo support:

```swift
// Undo Bulk Delete Properties
@Published var recentlyDeletedItems: [Item]?
@Published var showBulkDeleteUndoBanner = false
private var bulkDeleteUndoTimer: Timer?
private let bulkDeleteUndoTimeout: TimeInterval = 10.0  // Longer for bulk
```

### Timeout Duration

| Action | Timeout | Rationale |
|--------|---------|-----------|
| Individual delete | 5 seconds | Quick recovery for single item |
| Bulk delete | 10 seconds | More time to realize multi-item mistake |

### Bulk Delete Method

```swift
func deleteSelectedItemsWithUndo() {
    recentlyDeletedItems = Array(selectedItems)  // Store for undo
    // Delete items
    // Exit selection mode
    // Show undo banner with 10-second timeout
    // Trigger haptic feedback
}
```

### Undo Banner Component

```swift
struct MacBulkDeleteUndoBanner: View {
    // Red trash icon (consistent with delete)
    // Shows item count ("X items")
    // Undo button and dismiss button
    // Material background
    // Proper accessibility labels
}
```

## Key Learnings

1. **Consistency is critical**: Delete operations should behave the same regardless of count
2. **Undo over confirmation**: macOS users prefer undo for recoverable actions
3. **Reserve confirmation**: Only for truly destructive operations (permanent delete from archive)
4. **Test setup matters**: Use `TestHelpers.createTestDataManager()` for proper Core Data test setup

## Test Coverage

14 tests: individual/bulk undo banners, restore functionality, count display, selection mode exit, auto-hide, state clearing, consistency, message format, edge cases (single item, empty selection, consecutive deletes).
