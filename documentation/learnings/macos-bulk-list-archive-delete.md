---
title: macOS Bulk List Archive/Delete Implementation
date: 2026-01-15
severity: HIGH
category: macos
tags: [archive, delete, multi-select, type-checker, viewbuilder, semantics]
symptoms: [Type-checker timeout error, Misleading delete action, Confusing archive vs delete behavior]
root_cause: Complex view body caused type-checker timeout; DataManager method names are misleading
solution: Extract complex views into @ViewBuilder properties; Properly distinguish archive vs permanent delete
files_affected: [ListAllMac/Views/MacMainView.swift]
related: [macos-bulk-delete-undo-standardization.md, macos-undo-banners-implementation.md, macos-tab-switch-selection-persistence.md]
---

## Problem

1. Only had "Delete Lists" action which was misleading
2. `deleteList(withId:)` actually archives (not permanent delete)
3. Didn't distinguish between active lists (archive) vs archived lists (permanent delete)

## Solution

### Proper Semantics

**Active Lists View** (`showingArchivedLists = false`):
- Action: "Archive Lists" with archivebox icon
- Method: `archiveSelectedLists()` -> calls `dataManager.deleteList(withId:)`
- Effect: Lists move to archived state (recoverable)

**Archived Lists View** (`showingArchivedLists = true`):
- Action: "Delete Permanently" with trash icon
- Method: `permanentlyDeleteSelectedLists()` -> calls `dataManager.permanentlyDeleteList(withId:)`
- Effect: Permanent removal (irreversible)

### SwiftUI Type-Checker Performance Fix

Complex inline code causes:
```
error: the compiler is unable to type-check this expression in reasonable time
```

**Solution**: Extract into @ViewBuilder properties:

```swift
@ViewBuilder
private var bulkActionButton: some View {
    if showingArchivedLists {
        Button(role: .destructive, ...) { Label("Delete Permanently", ...) }
    } else {
        Button(role: .destructive, ...) { Label("Archive Lists", ...) }
    }
}

@ViewBuilder
private func selectionModeRow(for list: List) -> some View { ... }

@ViewBuilder
private func normalModeRow(for list: List) -> some View { ... }
```

### Keyboard Handler

```swift
.onKeyPress(.delete) {
    if isInSelectionMode && !selectedLists.isEmpty {
        if showingArchivedLists {
            showingPermanentDeleteConfirmation = true
        } else {
            showingArchiveConfirmation = true
        }
        return .handled
    }
    return .ignored
}
```

## Key Learnings

1. **DataManager Method Names Are Misleading**
   - `deleteList(withId:)` actually archives
   - `permanentlyDeleteList(withId:)` actually deletes
   - Always check implementation, not just names

2. **SwiftUI Type-Checker Has Limits**
   - Extract into @ViewBuilder properties
   - Break up complex expressions
   - Use helper computed properties

3. **Confirmation Messages Should Reflect Action**
   - Archive: "You can restore them later"
   - Permanent delete: "This action cannot be undone"
