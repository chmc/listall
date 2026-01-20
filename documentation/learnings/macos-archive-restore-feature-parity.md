---
title: macOS Archive/Restore Feature Parity
date: 2026-01-20
severity: CRITICAL
category: macos
tags: [swiftui, archived-lists, feature-parity, ios-macos, context-menu, read-only]
symptoms: [no restore UI, archived lists editable, feature parity broken with iOS]
root_cause: macOS missing two critical features iOS has - restore UI and read-only enforcement
solution: Added restore context menu/shortcut and comprehensive read-only mode for archived lists
files_affected: [ListAllMac/Views/MacMainView.swift, ListAllMac/Commands/AppCommands.swift]
related: [macos-archived-lists-empty-view-fix.md, macos-restore-archived-lists.md, macos-archived-lists-read-only.md]
---

## Problem

macOS had two critical bugs breaking feature parity with iOS:
1. **No Restore UI**: Backend existed but no way to invoke it
2. **Archived Lists Editable**: Should be read-only

## Solution Summary

### Task 13.1: Restore Functionality

**Context Menu Differentiation:**
```swift
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

**Keyboard Shortcut:** Cmd+Shift+R via NotificationCenter

### Task 13.2: Read-Only Mode

**Central Property:**
```swift
private var isCurrentListArchived: Bool {
    list.isArchived
}
```

**Multi-Level Enforcement:**
- Toolbar buttons hidden
- Row interaction disabled
- Keyboard shortcuts guarded
- Drag-drop handlers nil
- Context menus filtered
- Double-click ignored
- Empty state shows different message (no "Add Item" button)

**Callback Pattern for Nested Structs:**
```swift
// Nested struct cannot access parent @State
init(list: List, onRestore: @escaping () -> Void = {}) { ... }
```

**Conditional Draggable Modifier:**
```swift
struct ConditionalDraggable: ViewModifier {
    let item: Item
    let isDisabled: Bool
    func body(content: Content) -> some View {
        isDisabled ? content : content.draggable(item)
    }
}
```

## Key Learnings

1. **UI State Differentiation**: Use computed properties like `isCurrentListArchived`
2. **Context Menu Patterns**: SwiftUI context menus support conditional content
3. **Read-Only at Multiple Levels**: Disable toolbar, rows, keyboard, drag-drop, context menus, empty states
4. **Actions Over Badges**: Replace passive status badges with actionable buttons (Restore)
5. **Nested Struct Communication**: Use callback closures for state changes
6. **iOS Reference**: iOS uses dedicated `ArchivedListView` (cleaner separation, more duplication); macOS uses conditional rendering (less duplication, more conditionals)

## Test Coverage

- 14 tests for restore functionality
- 19 tests for read-only behavior
- 4 additional integration tests
