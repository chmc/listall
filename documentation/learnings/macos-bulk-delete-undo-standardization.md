# Learning: Standardizing Bulk Delete with Undo Banners (Task 12.8)

## Problem

The ListAll macOS app had inconsistent delete behavior:
- **Individual delete**: Used undo banner with 5-second timeout (good macOS pattern)
- **Bulk delete**: Used confirmation dialog "This action cannot be undone" (inconsistent)

This violated the macOS design principle that recoverable actions should use undo instead of confirmation dialogs.

## Solution

Replaced the bulk delete confirmation dialog with an undo banner pattern, matching individual delete behavior.

### Key Implementation Details

1. **Extended ListViewModel with bulk delete undo support**:
   ```swift
   // Undo Bulk Delete Properties (Multiple Items)
   @Published var recentlyDeletedItems: [Item]?
   @Published var showBulkDeleteUndoBanner = false
   private var bulkDeleteUndoTimer: Timer?
   private let bulkDeleteUndoTimeout: TimeInterval = 10.0 // per macOS convention
   ```

2. **Created deleteSelectedItemsWithUndo() method**:
   - Stores all selected items before deletion for undo
   - Deletes items
   - Exits selection mode
   - Shows undo banner with 10-second timeout
   - Triggers haptic feedback

3. **Created MacBulkDeleteUndoBanner component**:
   - Red trash icon (consistent with delete actions)
   - Shows item count ("X items")
   - Undo button and dismiss button
   - Material background for modern macOS appearance
   - Proper accessibility labels

4. **Removed confirmation dialog**:
   - Removed `showingDeleteConfirmation` state variable
   - Removed `.alert("Delete Items")` modifier
   - Updated button actions to call `deleteSelectedItemsWithUndo()`
   - Updated keyboard shortcut handler

## Timeout Duration

- Individual delete: 5 seconds (existing)
- Bulk delete: 10 seconds (per TODO.md specification)

The longer timeout for bulk delete gives users more time to realize they made a mistake when deleting multiple items.

## Testing Strategy

Created `DestructiveActionHandlingTests` with 14 tests covering:

1. **Individual delete undo** (existing behavior verification):
   - `testIndividualDeleteShowsUndoBanner`
   - `testIndividualDeleteUndoRestoresItem`

2. **Bulk delete undo** (new behavior):
   - `testBulkDeleteShowsUndoBanner`
   - `testBulkDeleteUndoRestoresAllItems`
   - `testBulkDeleteUndoBannerShowsCorrectCount`
   - `testBulkDeleteExitsSelectionMode`
   - `testBulkDeleteUndoBannerAutoHides`
   - `testHideBulkDeleteUndoClearsState`

3. **Consistency tests**:
   - `testDeletesAreConsistentlyUndoable`
   - `testBulkDeleteUndoBannerMessageFormat`

4. **Edge cases**:
   - `testBulkDeleteWithSingleItem`
   - `testBulkDeleteWithEmptySelection`
   - `testConsecutiveBulkDeletesReplaceUndoState`

## Files Modified

1. `/Users/aleksi/source/listall/ListAll/ListAll/ViewModels/ListViewModel.swift`:
   - Added bulk delete undo properties
   - Added `deleteSelectedItemsWithUndo()`, `undoBulkDelete()`, `hideBulkDeleteUndoBanner()`

2. `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift`:
   - Removed confirmation dialog
   - Added `MacBulkDeleteUndoBanner` component
   - Updated delete button and keyboard handler

3. `/Users/aleksi/source/listall/ListAll/ListAllMacTests/TestHelpers.swift`:
   - Added matching properties and methods to `TestListViewModel`

4. `/Users/aleksi/source/listall/ListAll/ListAllMacTests/ListAllMacTests.swift`:
   - Added `DestructiveActionHandlingTests` test class

## Key Learnings

1. **Consistency is critical**: Users expect delete operations to behave the same way regardless of how many items are affected.

2. **Undo over confirmation**: macOS users prefer undo for recoverable actions rather than confirmation dialogs that interrupt workflow.

3. **Reservation for truly destructive**: Confirmation dialogs should only be used for truly destructive operations like permanent delete from archive.

4. **Test setup matters**: Use `TestHelpers.createTestDataManager()` for proper Core Data test setup, not direct instantiation.

5. **Timeout considerations**: Longer timeout for bulk delete (10s vs 5s) gives users more time to recover from larger mistakes.
