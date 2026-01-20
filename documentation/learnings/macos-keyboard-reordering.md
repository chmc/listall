---
title: macOS Keyboard Reordering with Arrow Keys
date: 2026-01-15
severity: HIGH
category: macos
tags: [keyboard, accessibility, onKeyPress, arrow-keys, reordering, wcag]
symptoms: [Compilation error with onKeyPress modifiers parameter, Arrow key handlers not working]
root_cause: SwiftUI onKeyPress with arrow keys does NOT support modifiers parameter like character-based handlers
solution: Check modifiers inside the closure using keyPress.modifiers.contains()
files_affected: [ListAll/ViewModels/ListViewModel.swift, ListAllMac/Views/MacMainView.swift, ListAllMacTests/TestHelpers.swift]
related: [macos-global-cmdf-search.md, macos-filter-ui-redesign.md, macos-voiceover-accessibility.md]
---

## Problem

Items could only be reordered via drag-and-drop. Keyboard-first users couldn't reorder without mouse.

## Critical Learning: Arrow Key Modifier Handling

**WRONG** (causes compilation error):
```swift
.onKeyPress(.upArrow, modifiers: [.command, .option]) {
    // This does NOT work for arrow keys!
}
```

**CORRECT**:
```swift
.onKeyPress(keys: [.upArrow]) { keyPress in
    guard keyPress.modifiers.contains(.command),
          keyPress.modifiers.contains(.option) else {
        return .ignored
    }
    // Handle the key press
    return .handled
}
```

## ViewModel Methods

```swift
var canReorderWithKeyboard: Bool {
    return currentSortOption == .orderNumber
}

func moveItemUp(_ id: UUID) {
    guard canReorderWithKeyboard else { return }
    guard let currentIndex = items.firstIndex(where: { $0.id == id }) else { return }
    guard currentIndex > 0 else { return }
    reorderItems(from: currentIndex, to: currentIndex - 1)
}

func moveItemDown(_ id: UUID) {
    guard canReorderWithKeyboard else { return }
    guard let currentIndex = items.firstIndex(where: { $0.id == id }) else { return }
    guard currentIndex < items.count - 1 else { return }
    reorderItems(from: currentIndex, to: currentIndex + 1)
}
```

## Constraints

- Only works when sorted by "Order" (orderNumber)
- Disabled when sorted by title, date, quantity, etc.

## Core Data Test Setup

List entity must exist in data manager BEFORE creating items:
```swift
let testList = ListModel(name: "Test List")
testDataManager.addList(testList)  // CRITICAL: list must exist first!
let viewModel = TestListViewModel(list: testList, dataManager: testDataManager)
```

## Accessibility Benefits

- Allows keyboard-only users to reorder items
- Supports VoiceOver users who cannot use drag-and-drop
- Follows WCAG 2.1 Guideline 2.1.1
