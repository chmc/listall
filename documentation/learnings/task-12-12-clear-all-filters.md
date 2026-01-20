---
title: Clear All Filters Shortcut
date: 2026-01-15
severity: MEDIUM
category: macos
tags: [swiftui, keyboard-shortcuts, filters, search, onkeypress, ux]
symptoms: [no keyboard shortcut to clear filters, must click X on each badge individually]
root_cause: Missing clearAllFilters() method and keyboard shortcut for power users
solution: Added Cmd+Shift+Delete shortcut, Clear All button, and enhanced Escape behavior
files_affected: [ListAll/ViewModels/ListViewModel.swift, ListAllMac/Views/MacMainView.swift, ListAllMacTests/TestHelpers.swift]
related: [macos-filter-ui-redesign.md, macos-global-cmdf-search.md, macos-consistent-empty-states.md]
---

## Problem

Active filter badges required individual clicks to clear. No keyboard shortcut existed for power users.

## Solution

### 1. ViewModel Methods

```swift
var hasActiveFilters: Bool {
    currentFilterOption != .all ||
    currentSortOption != .orderNumber ||
    currentSortDirection != .ascending ||
    !searchText.isEmpty
}

func clearAllFilters() {
    searchText = ""
    currentFilterOption = .all
    currentSortOption = .orderNumber
    currentSortDirection = .ascending
    showCrossedOutItems = true  // Sync with .all filter
    saveUserPreferences()
}
```

### 2. Keyboard Handler (Cmd+Shift+Delete)

```swift
.onKeyPress(keys: [.delete]) { keyPress in
    guard keyPress.modifiers.contains(.command),
          keyPress.modifiers.contains(.shift) else {
        return .ignored
    }
    viewModel.clearAllFilters()
    return .handled
}
```

### 3. Clear All Button (visible when 2+ filters active)

```swift
if activeFilterCount > 1 {
    Button(action: { viewModel.clearAllFilters() }) {
        Text("Clear All")
            .font(.caption)
    }
    .help("Clear all filters (Cmd+Shift+Delete)")
}
```

### 4. Enhanced Escape Key Behavior

Two-stage escape in search field:
1. First Escape: Clear search text (if not empty)
2. Second Escape: Clear all filters (if search was already empty but filters active)

```swift
.onExitCommand {
    if !viewModel.searchText.isEmpty {
        viewModel.searchText = ""
    } else if viewModel.hasActiveFilters {
        viewModel.clearAllFilters()
    }
    isSearchFieldFocused = false
}
```

## Key Pattern

### SwiftUI onKeyPress API

For special keys with modifiers:
```swift
.onKeyPress(keys: [.delete]) { keyPress in
    guard keyPress.modifiers.contains(.command) else { return .ignored }
    return .handled
}
```

For character keys:
```swift
.onKeyPress(characters: CharacterSet(charactersIn: "a")) { keyPress in
    guard keyPress.modifiers.contains(.command) else { return .ignored }
    return .handled
}
```

## Test Data Isolation

When writing tests with pre-populated ViewModel, use SAME data manager instance:

```swift
// WRONG - items won't be visible
viewModel = TestHelpers.createTestListViewModel(with: testList)

// CORRECT - uses same data manager
viewModel = TestListViewModel(list: testList, dataManager: testDataManager)
```

## Test Coverage

19 tests: clearAllFilters() method, property resets, hasActiveFilters computed property, keyboard shortcut config, escape key behavior, Clear All button visibility, integration tests.
