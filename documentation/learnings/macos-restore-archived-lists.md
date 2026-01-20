# macOS Restore Archived Lists Implementation

**Date**: January 2026
**Task**: 13.1 - Add Restore Functionality for Archived Lists
**Platform**: macOS

## Problem

macOS had no UI to restore archived lists back to active lists. The backend `restoreList(withId:)` method existed in CoreDataManager, but there was no way for users to invoke it on macOS.

iOS provides restore functionality in:
- `ListRowView` - inline restore button for archived lists
- `ArchivedListView` - toolbar restore button with confirmation

macOS was missing this entirely, breaking feature parity with iOS.

## Solution

### 1. State Variables (MacSidebarView)

Added state for restore confirmation dialog:

```swift
// MARK: - Restore Confirmation State (Task 13.1)
@State private var showingRestoreConfirmation = false
@State private var listToRestore: List? = nil
```

### 2. Context Menu (normalModeRow)

Updated context menu to show different options based on `showingArchivedLists`:

```swift
.contextMenu {
    if showingArchivedLists {
        // Archived list context menu: Restore and Delete Permanently
        Button {
            listToRestore = list
            showingRestoreConfirmation = true
        } label: {
            Label("Restore", systemImage: "arrow.uturn.backward")
        }

        Divider()

        Button(role: .destructive) {
            onDeleteList(list)
        } label: {
            Label("Delete Permanently", systemImage: "trash")
        }
    } else {
        // Active list context menu: Share and Delete (archive)
        Button("Share...") {
            shareListFromSidebar(list)
        }
        Divider()
        Button("Delete") {
            onDeleteList(list)
        }
    }
}
```

### 3. Confirmation Alert

Added alert following iOS pattern (includes list name in message):

```swift
.alert("Restore List", isPresented: $showingRestoreConfirmation) {
    Button("Cancel", role: .cancel) {
        listToRestore = nil
    }
    Button("Restore") {
        if let list = listToRestore {
            dataManager.restoreList(withId: list.id)
            dataManager.loadArchivedData()
            dataManager.loadData()
        }
        listToRestore = nil
    }
} message: {
    if let list = listToRestore {
        Text("Do you want to restore \"\(list.name)\" to your active lists?")
    } else {
        Text("Do you want to restore this list to your active lists?")
    }
}
```

### 4. Keyboard Shortcut (AppCommands.swift)

Added Cmd+Shift+R shortcut in Lists menu:

```swift
Button("Restore List") {
    NotificationCenter.default.post(
        name: NSNotification.Name("RestoreSelectedList"),
        object: nil
    )
}
.keyboardShortcut("r", modifiers: [.command, .shift])
```

### 5. Notification Handler (MacSidebarView)

Added handler to respond to keyboard shortcut:

```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestoreSelectedList"))) { _ in
    guard showingArchivedLists, let list = selectedList else { return }
    guard list.isArchived else { return }
    listToRestore = list
    showingRestoreConfirmation = true
}
```

## Key Patterns

### Icon Consistency
Used `arrow.uturn.backward` SF Symbol for restore action, matching iOS.

### Confirmation Before Action
Always show confirmation dialog before restore to prevent accidental actions.

### State Reset
Always reset `listToRestore = nil` after action completes (both confirm and cancel paths).

### Data Refresh Pattern
After restore, refresh both archived and active lists:
```swift
dataManager.restoreList(withId: list.id)
dataManager.loadArchivedData()  // Refresh archived list
dataManager.loadData()          // Refresh active lists
```

## Files Modified

- `/ListAll/ListAllMac/Views/MacMainView.swift`
  - Added restore state variables in MacSidebarView
  - Updated normalModeRow context menu
  - Added restore confirmation alert
  - Added notification handler for keyboard shortcut

- `/ListAll/ListAllMac/Commands/AppCommands.swift`
  - Added "Restore List" menu item with Cmd+Shift+R shortcut

## Tests Added

Four new tests in `ArchivedListsTests`:
1. `testRestoreConfirmationStateManagement` - Tests state variable behavior
2. `testRestoreContextMenuAvailability` - Tests context menu availability logic
3. `testMainViewModelRestoreList` - Tests restore action via data manager
4. `testRestoreConfirmationMessageIncludesListName` - Tests confirmation message format

## Verification

- All 15 ArchivedListsTests pass
- All 21 ListAllMacTests pass
- macOS build succeeds without errors

## Related Tasks

- Task 13.2 will make archived lists read-only (disable editing, drag-drop)
- Task 13.3 will update documentation status
