# macOS Move/Copy Items Between Lists Implementation

## Problem
Need to implement Move and Copy Items Between Lists functionality for macOS to achieve feature parity with iOS.

## Solution

### Key Components Created

1. **MacDestinationListPickerSheet** (`/Users/aleksi/source/listall/ListAll/ListAllMac/Views/Components/MacDestinationListPickerSheet.swift`)
   - Sheet view for selecting destination list
   - Shows available lists (excluding current list and archived lists)
   - Displays list name and item count
   - Supports creating new list inline
   - Uses `MacDestinationListAction` enum for move vs copy

2. **MacDestinationListAction Enum**
   - `.move`: Removes items from source, adds to destination
   - `.copy`: Keeps items in source, adds copies to destination
   - Provides localized title, verb, and system image

### Integration in MacListDetailView

Added state variables:
```swift
@State private var showingMoveItemsPicker = false
@State private var showingCopyItemsPicker = false
@State private var selectedDestinationList: List?
@State private var showingMoveConfirmation = false
@State private var showingCopyConfirmation = false
```

Flow:
1. User enters selection mode (checkmark button)
2. Selects items
3. Opens ellipsis menu -> "Move Items..." or "Copy Items..."
4. `MacDestinationListPickerSheet` appears
5. User selects destination list
6. Sheet dismisses, confirmation alert shows
7. User confirms -> `viewModel.moveSelectedItems(to:)` or `viewModel.copySelectedItems(to:)`
8. Selection mode exits

### Shared Code (ListViewModel)

Used existing iOS implementation:
- `moveSelectedItems(to:)` - Move selected items to destination
- `copySelectedItems(to:)` - Copy selected items to destination
- `enterSelectionMode()` - Enable selection mode
- `exitSelectionMode()` - Disable and clear selection
- `toggleSelection(for:)` - Toggle item selection
- `selectAll()` / `deselectAll()` - Bulk selection

## Key Patterns

### Sheet Presentation
SwiftUI `.sheet()` modifier works correctly within MacListDetailView because it's inside a NavigationStack with animation fix. No need for native AppKit sheet presenter.

### Confirmation Alerts
Used SwiftUI `.alert()` with `isPresented` binding and conditional message based on selected destination list.

### Available Lists Filtering
```swift
private var availableLists: [List] {
    dataManager.lists.filter { $0.id != currentListId && !$0.isArchived }
        .sorted { $0.orderNumber < $1.orderNumber }
}
```

## Tests Added

9 unit tests in `MoveCopyItemsMacTests`:
- `testMoveActionProperties` - Verify move action enum
- `testCopyActionProperties` - Verify copy action enum
- `testEnterSelectionMode` - Entering selection mode
- `testExitSelectionMode` - Exiting clears state
- `testToggleSelection` - Toggle selection on/off
- `testSelectAll` - Select all filtered items
- `testDeselectAll` - Clear selection
- `testRunningOnMacOS` - Platform verification
- `testMoveCopyItemsDocumentation` - Documentation test

## Files Modified

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/MacMainView.swift` - Added state, sheets, alerts
- `/Users/aleksi/source/listall/ListAll/ListAllMacTests/ListAllMacTests.swift` - Added test class

## Files Created

- `/Users/aleksi/source/listall/ListAll/ListAllMac/Views/Components/MacDestinationListPickerSheet.swift`

## Documentation Updated

- `documentation/features/SUMMARY.md` - Updated Item Management to 17/17, marked Move/Copy as complete
- `documentation/features/ITEM_MANAGEMENT.md` - Updated status, added macOS patterns, added implementation file
