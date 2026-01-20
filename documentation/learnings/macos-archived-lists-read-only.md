---
title: macOS Archived Lists Read-Only Implementation
date: 2026-01-20
severity: HIGH
category: macos
tags: [swiftui, read-only, archived-lists, conditional-modifiers, keyboard-shortcuts]
symptoms: [archived lists fully editable, add/edit/delete/reorder all allowed]
root_cause: macOS used same view for active and archived lists without disabling edits
solution: Added isCurrentListArchived property and conditionally disabled all editing controls
files_affected: [ListAllMac/Views/MacMainView.swift]
related: [macos-archived-lists-empty-view-fix.md, macos-restore-archived-lists.md]
---

## Problem

Archived lists were fully editable (add, edit, delete, reorder), defeating the purpose of archiving. iOS uses dedicated `ArchivedListView` that is completely read-only.

## Solution

UI-level read-only enforcement via `isCurrentListArchived` computed property.

### Central Property

```swift
private var isCurrentListArchived: Bool {
    list.isArchived
}
```

### What Gets Disabled

| Control | Implementation |
|---------|----------------|
| Add Item button | `if !isCurrentListArchived { ... }` |
| Edit List button | Hidden in header |
| Selection mode | Hidden in header |
| Item checkbox | Read-only visual instead of button |
| Edit/Delete hover buttons | Only Quick Look visible |
| Double-click edit | Returns early |
| Drag-to-reorder | `.onMove(perform: nil)` |
| Keyboard shortcuts | Guard checks property |

### Conditional Draggable Modifier

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

### Keyboard Shortcuts Guard

```swift
.onKeyPress(.return) {
    guard !isCurrentListArchived else { return .ignored }
    // ... edit logic
}
```

### MacItemRowView Parameter

```swift
MacItemRowView(
    item: item,
    isArchivedList: isCurrentListArchived,  // New parameter
    ...
)
```

Controls:
- Completion checkbox shows read-only state
- Hover actions only show Quick Look
- Context menu only Quick Look option
- Double-click disabled

### Visual Restore Button (UX Improvement)

Initial passive "Archived" badge was poor UX - replaced with actionable Restore button:

```swift
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

Uses callback closure since nested struct cannot access parent `@State`.

### What Remains Enabled

- Search field (searching is viewing)
- Filter/Sort controls (filtering is viewing)
- Share button (sharing is viewing)
- Quick Look for images
- Navigation and scrolling

## Design Decision

Read-only at UI level, not DataManager level:
- DataManager needs to modify for restore functionality
- UI restriction sufficient for user protection
- Simpler implementation

## Test Coverage

19 tests: isCurrentListArchived property, hidden buttons, read-only rows, disabled drag, context menu, keyboard shortcuts, visible view controls, archived badge/restore button.
