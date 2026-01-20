---
title: macOS Undo Banners Implementation
date: 2026-01-15
severity: MEDIUM
category: macos
tags: [undo, swiftui, animation, zstack, material-background]
symptoms: [macOS missing undo functionality for complete/delete, iOS has undo banners but macOS does not]
root_cause: macOS app lacked platform-specific undo UI components
solution: Create MacUndoBanner and MacDeleteUndoBanner views with ZStack overlay pattern
files_affected: [ListAllMac/Views/MacMainView.swift]
related: [macos-bulk-delete-undo-standardization.md, macos-bulk-list-archive-delete.md, macos-move-copy-items-implementation.md]
---

## Problem

macOS app missing undo functionality that iOS has for completing/deleting items.

## Solution

### Components Created

1. **MacUndoBanner** - Green checkmark, "Completed" text, blue "Undo" button
2. **MacDeleteUndoBanner** - Red trash icon, "Deleted" text, red "Undo" button

### macOS-Specific Styling

```swift
.padding(12)
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 10))
.shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
```

### ZStack Overlay Pattern

```swift
ZStack(alignment: .bottom) {
    VStack(spacing: 0) { /* Main content */ }

    if viewModel.showUndoButton, let item = viewModel.recentlyCompletedItem {
        MacUndoBanner(...)
    }
    if viewModel.showDeleteUndoButton, let item = viewModel.recentlyDeletedItem {
        MacDeleteUndoBanner(...)
    }
}
```

### Animation

```swift
.transition(.move(edge: .bottom).combined(with: .opacity))
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showUndoButton)
```

## DRY Principle

- Reuses shared `ListViewModel` with existing undo logic
- Timer-based auto-hide (5 seconds) in shared ViewModel
- Only macOS-specific UI components created
