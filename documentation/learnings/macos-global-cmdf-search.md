---
title: macOS Global Cmd+F Search Scope
date: 2026-01-15
severity: HIGH
category: macos
tags: [keyboard-shortcuts, cmd-f, search, focus, notification-pattern, onKeyPress]
symptoms: [Cmd+F only works when detail pane focused, Cmd+F ignored when sidebar focused]
root_cause: onKeyPress handler in MacListDetailView only triggers when that view has focus
solution: Add global Cmd+F handler at NavigationSplitView level using notification pattern
files_affected: [ListAllMac/Views/MacMainView.swift]
related: [macos-filter-ui-redesign.md, task-12-12-clear-all-filters.md, macos-keyboard-reordering.md]
---

## Problem

Cmd+F only worked when focus was in detail pane. If sidebar focused, Cmd+F did nothing.

## Root Cause

The handler was in `MacListDetailView`:
```swift
// Only triggers when detail view has focus
.onKeyPress(characters: CharacterSet(charactersIn: "f")) { keyPress in
    guard keyPress.modifiers.contains(.command) else { return .ignored }
    isSearchFieldFocused = true
    return .handled
}
```

## Solution

Use notification pattern for decoupled communication.

### Global Handler in MacMainView

```swift
// At NavigationSplitView level
.onKeyPress(characters: CharacterSet(charactersIn: "f")) { keyPress in
    guard keyPress.modifiers.contains(.command) else { return .ignored }

    if selectedList == nil, let firstList = dataManager.lists.first {
        selectedList = firstList
        // Delay allows detail view to render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
        }
    } else if selectedList != nil {
        NotificationCenter.default.post(name: NSNotification.Name("FocusSearchField"), object: nil)
    }
    return .handled
}
```

### Notification Receiver in MacListDetailView

```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FocusSearchField"))) { _ in
    isSearchFieldFocused = true
}
```

## Key Design Decisions

1. **Notification Pattern**: Decoupled communication between parent and child, consistent with existing patterns ("ItemEditingStarted", "ItemEditingEnded")

2. **No List Selected**: Auto-select first list with 100ms delay to allow detail view to render

3. **Kept Existing Handler**: Provides faster direct path when focus already in detail view

## Key Learnings

1. **View Hierarchy for Scope**: `.onKeyPress` captures events only within that view's focus scope. For window-global shortcuts, place at top-level.

2. **Notification for Focus Management**: When controlling focus across view boundaries, notifications let parent post and child (with `@FocusState`) respond.

3. **Edge Cases**: Handle when target view may not exist yet (delay after state transition).

4. **Redundancy for UX**: Both global and local handlers provide best responsiveness.
