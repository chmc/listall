---
title: macOS Filter UI Redesign - Popover to Native Pattern
date: 2026-01-15
severity: HIGH
category: macos
tags: [filter-ui, segmented-control, view-menu, keyboard-shortcuts, hig, popover]
symptoms: [Filter state hidden until clicked, Two clicks required to change filter, No keyboard shortcuts, No View menu integration]
root_cause: iOS-style popover pattern violates macOS conventions
solution: Replace popover with always-visible segmented control and View menu shortcuts
files_affected: [ListAllMac/Views/MacMainView.swift, ListAllMac/Commands/AppCommands.swift, ListAllMac/Views/Components/MacSortOnlyView.swift]
related: [task-12-12-clear-all-filters.md, macos-global-cmdf-search.md, macos-keyboard-reordering.md]
---

## Problem

iOS-style popover pattern violated macOS conventions:
- Filter state hidden until clicked (no discoverability)
- 2 clicks + animation wait to change filter
- No keyboard shortcuts
- No View menu integration

## Research Findings

**None of 7 best-in-class macOS apps** (Finder, Mail, Notes, Reminders, Things 3, Bear, OmniFocus) use popovers for primary filtering. All use always-visible controls.

## Solution

### Toolbar Segmented Control

```swift
@ViewBuilder
private var filterSortControls: some View {
    HStack(spacing: 8) {
        Picker("Filter", selection: $viewModel.currentFilterOption) {
            Text("All").tag(ItemFilterOption.all)
            Text("Active").tag(ItemFilterOption.active)
            Text("Done").tag(ItemFilterOption.completed)
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
        .help("Filter items by status (Cmd+1/2/3)")

        Button(action: { showingOrganizationPopover.toggle() }) {
            Image(systemName: "arrow.up.arrow.down")
        }
        .popover(isPresented: $showingOrganizationPopover) {
            MacSortOnlyView(viewModel: viewModel)
        }
    }
}
```

### View Menu Shortcuts (AppCommands.swift)

```swift
Button("All Items") {
    NotificationCenter.default.post(name: NSNotification.Name("SetFilterAll"), object: nil)
}
.keyboardShortcut("1", modifiers: .command)

Button("Active Only") {
    NotificationCenter.default.post(name: NSNotification.Name("SetFilterActive"), object: nil)
}
.keyboardShortcut("2", modifiers: .command)

Button("Completed Only") {
    NotificationCenter.default.post(name: NSNotification.Name("SetFilterCompleted"), object: nil)
}
.keyboardShortcut("3", modifiers: .command)
```

### Notification Receivers

```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetFilterAll"))) { _ in
    viewModel.updateFilterOption(.all)
}
```

## Key Design Decisions

1. **Segmented Control**: Immediate visual feedback, single click changes filter
2. **Cmd+1/2/3**: Standard macOS pattern (like Finder's View menu)
3. **View Menu**: Native macOS apps expose filters in View menu
4. **Sort in Popover**: Sort is used less frequently, popover acceptable

## Key Learnings

1. **iOS-isms in macOS**: Popover-for-everything is iOS pattern. macOS expects always-visible controls.
2. **HIG Research**: Studying best-in-class apps provides design direction.
3. **Separate Frequent from Infrequent**: Filters (frequent) get direct access; sort (infrequent) stays in popover.
4. **Notification Pattern Consistency**: Same pattern as CreateNewList, FocusSearchField.
