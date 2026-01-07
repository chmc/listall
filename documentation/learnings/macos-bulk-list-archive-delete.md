# macOS Bulk List Archive/Delete Implementation

## Problem

The macOS app had multi-select mode for lists but was missing proper bulk archive/delete functionality. The existing implementation:

1. Only had "Delete Lists" action which was misleading
2. Called `dataManager.deleteList(withId:)` which actually archives (not permanent delete)
3. Didn't distinguish between active lists (archive) vs archived lists (permanent delete)

## Solution

### 1. Proper Semantics for Archive vs Delete

- **Active Lists View** (`showingArchivedLists = false`):
  - Action: "Archive Lists" with archivebox icon
  - Method: `archiveSelectedLists()` → calls `dataManager.deleteList(withId:)`
  - Effect: Lists move to archived state (recoverable)

- **Archived Lists View** (`showingArchivedLists = true`):
  - Action: "Delete Permanently" with trash icon
  - Method: `permanentlyDeleteSelectedLists()` → calls `dataManager.permanentlyDeleteList(withId:)`
  - Effect: Lists are permanently removed (irreversible)

### 2. SwiftUI Type-Checker Performance Fix

The MacSidebarView body was too complex for Swift's type-checker, causing compilation errors:
```
error: the compiler is unable to type-check this expression in reasonable time
```

**Solution**: Extract complex view code into @ViewBuilder properties:

```swift
// BEFORE: Complex inline code in body
var body: some View {
    Menu {
        if showingArchivedLists {
            Button(...) { ... }
        } else {
            Button(...) { ... }
        }
    }
}

// AFTER: Extracted into @ViewBuilder
@ViewBuilder
private var bulkActionButton: some View {
    if showingArchivedLists {
        Button(role: .destructive, ...) { Label("Delete Permanently", ...) }
    } else {
        Button(role: .destructive, ...) { Label("Archive Lists", ...) }
    }
}

// Also extracted list row content
@ViewBuilder
private func selectionModeRow(for list: List) -> some View { ... }
@ViewBuilder
private func normalModeRow(for list: List) -> some View { ... }
```

### 3. Keyboard Navigation Update

The Delete key behavior now depends on the current view:

```swift
.onKeyPress(.delete) {
    if isInSelectionMode && !selectedLists.isEmpty {
        if showingArchivedLists {
            showingPermanentDeleteConfirmation = true  // Permanent delete
        } else {
            showingArchiveConfirmation = true  // Archive (recoverable)
        }
        return .handled
    }
    return .ignored
}
```

## Key Learnings

### 1. DataManager Method Names Are Misleading

- `deleteList(withId:)` actually archives (sets `isArchived = true`)
- `permanentlyDeleteList(withId:)` actually deletes from database
- Always check implementation, not just method names

### 2. SwiftUI Type-Checker Has Limits

Large view bodies with many conditionals cause type-checker timeout. Solutions:
- Extract into @ViewBuilder properties
- Extract into helper methods
- Break up complex expressions
- Use helper computed properties (e.g., `itemCountText(for:)`)

### 3. Confirmation Messages Should Reflect Action

- Archive: "You can restore them later from archived lists."
- Permanent delete: "This action cannot be undone."

## Files Modified

- `ListAllMac/Views/MacMainView.swift`:
  - Added `showingArchiveConfirmation` and `showingPermanentDeleteConfirmation` state
  - Added `archiveSelectedLists()` and `permanentlyDeleteSelectedLists()` methods
  - Added `bulkActionButton` @ViewBuilder property
  - Added `selectionModeRow(for:)` and `normalModeRow(for:)` @ViewBuilder methods
  - Added `itemCountText(for:)` helper
  - Updated keyboard handler
  - Added two confirmation alerts

## Tests Added

21 unit tests in `BulkListOperationsMacTests`:
- Platform verification
- Selection mode state tests
- Archive vs delete semantics tests
- Keyboard navigation tests
- UI message tests
- Documentation test
