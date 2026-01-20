---
title: macOS Restore Archived Lists Implementation
date: 2026-01-20
severity: HIGH
category: macos
tags: [swiftui, context-menu, keyboard-shortcut, notifications, restore, archived-lists]
symptoms: [no UI to restore archived lists, backend method exists but not exposed]
root_cause: macOS missing restore UI that iOS has in ListRowView and ArchivedListView
solution: Added context menu restore option, confirmation alert, and Cmd+Shift+R keyboard shortcut
files_affected: [ListAllMac/Views/MacMainView.swift, ListAllMac/Commands/AppCommands.swift]
related: [macos-archived-lists-empty-view-fix.md, macos-archived-lists-read-only.md]
---

## Problem

Backend `restoreList(withId:)` existed but macOS had no UI to invoke it. iOS provides restore in ListRowView and ArchivedListView.

## Solution

### 1. State Variables

```swift
@State private var showingRestoreConfirmation = false
@State private var listToRestore: List? = nil
```

### 2. Context Menu (conditional)

```swift
.contextMenu {
    if showingArchivedLists {
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
        Button("Share...") { shareListFromSidebar(list) }
        Divider()
        Button("Delete") { onDeleteList(list) }
    }
}
```

### 3. Confirmation Alert

```swift
.alert("Restore List", isPresented: $showingRestoreConfirmation) {
    Button("Cancel", role: .cancel) { listToRestore = nil }
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
    }
}
```

### 4. Keyboard Shortcut (Cmd+Shift+R)

```swift
// AppCommands.swift
Button("Restore List") {
    NotificationCenter.default.post(
        name: NSNotification.Name("RestoreSelectedList"),
        object: nil
    )
}
.keyboardShortcut("r", modifiers: [.command, .shift])
```

### 5. Notification Handler

```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RestoreSelectedList"))) { _ in
    guard showingArchivedLists, let list = selectedList else { return }
    guard list.isArchived else { return }
    listToRestore = list
    showingRestoreConfirmation = true
}
```

## Key Patterns

| Pattern | Implementation |
|---------|----------------|
| Icon consistency | `arrow.uturn.backward` matches iOS |
| Confirmation before action | Prevents accidental restores |
| State reset | Always set `listToRestore = nil` after action |
| Data refresh | Call both `loadArchivedData()` and `loadData()` |

## Test Coverage

4 tests: state management, context menu availability, restore action, confirmation message format.
