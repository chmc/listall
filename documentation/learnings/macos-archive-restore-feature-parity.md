# macOS Archive/Restore Feature Parity

## Problem

The macOS app had two critical bugs breaking feature parity with iOS for archived lists:

1. **No Restore UI**: Backend `restoreList(withId:)` existed but macOS had no UI to invoke it
2. **Archived Lists Editable**: Archived lists were fully editable (should be read-only)

## Solution

### Task 13.1: Add Restore Functionality

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift` - Added restore state, context menu, alert, notification handler
- `ListAllMac/Commands/AppCommands.swift` - Added Cmd+Shift+R keyboard shortcut

**Implementation**:
1. Added `showingRestoreConfirmation` and `listToRestore` state variables
2. Updated context menu in `normalModeRow()` to show different options based on `showingArchivedLists`:
   - Archived: "Restore" (arrow.uturn.backward icon), "Delete Permanently" (destructive)
   - Active: "Share...", "Delete" (existing)
3. Added notification handler for "RestoreSelectedList" keyboard command
4. Added restore confirmation alert following iOS pattern (includes list name)

**Pattern**:
```swift
// Context menu differentiation
.contextMenu {
    if showingArchivedLists {
        Button { /* restore */ } label: { Label("Restore", systemImage: "arrow.uturn.backward") }
        Divider()
        Button(role: .destructive) { /* permanent delete */ } label: { Label("Delete Permanently", systemImage: "trash") }
    } else {
        Button("Share...") { /* share */ }
        Divider()
        Button("Delete") { /* archive */ }
    }
}
```

### Task 13.2: Make Archived Lists Read-Only

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift` - Extensive changes to MacListDetailView and MacItemRowView

**Implementation**:
1. Added `isCurrentListArchived` computed property
2. Conditionally hidden editing controls in header (Edit List, Selection Mode)
3. Hidden Add Item button in toolbar for archived lists
4. Updated MacItemRowView with `isArchivedList` parameter:
   - Read-only completion indicator (no button)
   - Hidden edit/delete hover buttons
   - Only Quick Look button visible (read-only operation)
   - Read-only context menu (only Quick Look)
   - Disabled double-click editing
5. Disabled drag-to-reorder via `ConditionalDraggable` modifier
6. Disabled keyboard shortcuts: Space (toggle), Enter (edit), Delete, Cmd+Opt+Up/Down
7. Replaced "Archived" badge with "Restore" button in header (UX improvement)
8. Blocked CreateNewItem notification for archived lists
9. Disabled Cmd+Click/Shift+Click multi-select
10. Updated empty state (`MacItemsEmptyStateView`) with `isArchived` parameter:
    - Shows "Empty Archived List" message instead of "Add Your First Item" button
    - Prevents mutation through empty state UI

**UX Improvement - Restore Button in Header**:
The initial implementation used a passive "Archived" badge. User feedback indicated this was poor UX - Restore functionality was only discoverable via context menu. The solution replaced the badge with an actionable "Restore" button using:

```swift
// MacListDetailView init with callback
let onRestore: () -> Void

init(list: List, onEditItem: @escaping (Item) -> Void, onRestore: @escaping () -> Void = {}) {
    // ...
}

// Restore button (replaces Archived badge)
@ViewBuilder
private var restoreButton: some View {
    Button(action: onRestore) {
        HStack(spacing: 4) {
            Image(systemName: "arrow.uturn.backward")
            Text(String(localized: "Restore"))
        }
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.small)
}
```

The callback pattern is required because `MacListDetailView` is a private nested struct that cannot directly access parent state variables.

**Key Pattern - Conditional Draggable**:
```swift
struct ConditionalDraggable: ViewModifier {
    let item: Item
    let isDisabled: Bool

    func body(content: Content) -> some View {
        if isDisabled {
            content
        } else {
            content.draggable(item)
        }
    }
}
```

## Key Learnings

1. **UI State Differentiation**: Use computed properties like `isCurrentListArchived` to centralize archive status checks

2. **Context Menu Patterns**: SwiftUI context menus can use conditional content based on parent state

3. **Read-Only Enforcement**: For read-only modes, disable at multiple levels:
   - Toolbar buttons
   - Row interaction buttons
   - Keyboard shortcuts
   - Drag-drop handlers
   - Context menus
   - Double-click handlers
   - **Empty state views** (don't show "Add Item" buttons)

4. **Visual Feedback vs Actions**: Initially used passive badge for archived status. Better UX is actionable - replace status badge with Restore button. Users can discover restore via button, not just context menu.

5. **Nested Struct State Access**: Private structs in same file cannot directly access parent `@State` variables. Use callback closures (`onRestore: () -> Void`) to communicate state changes back to parent.

6. **iOS Reference**: iOS uses dedicated `ArchivedListView` with `ArchivedItemRowView` - cleaner separation but more code duplication. macOS approach uses same view with conditional rendering - less duplication but more conditionals.

## Tests Added

- `RestoreArchivedListsTests.swift` - 14 tests for restore functionality
- `ReadOnlyArchivedListsTests.swift` - 19 tests for read-only behavior
- `ArchivedListsTests` (in ListAllMacTests.swift) - 4 additional integration tests

## Date

January 20, 2026
