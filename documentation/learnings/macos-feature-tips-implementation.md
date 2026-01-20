---
title: macOS Feature Tips System Implementation
date: 2026-01-15
severity: MEDIUM
category: macos
tags: [tooltips, feature-tips, settings, userdefaults, scrollview-lazyvstack]
symptoms: [macOS missing iOS Feature Tips System, No way to view/reset tips on macOS]
root_cause: macOS app lacked tooltip manager and tips UI
solution: Create MacTooltipManager and MacAllFeatureTipsView with macOS-specific tip types
files_affected: [ListAllMac/Utils/MacTooltipManager.swift, ListAllMac/Views/Components/MacAllFeatureTipsView.swift, ListAllMac/Views/MacSettingsView.swift]
related: [macos-proactive-feature-tips.md]
---

## Problem

macOS missing Feature Tips System that iOS had. Users couldn't view/reset tips.

## Solution

### MacTooltipManager

```swift
enum MacTooltipType: String, CaseIterable, Identifiable {
    case addListButton = "tooltip_add_list"
    case itemSuggestions = "tooltip_item_suggestions"
    case searchFunctionality = "tooltip_search"
    case sortFilterOptions = "tooltip_sort_filter"
    case contextMenuActions = "tooltip_context_menu"  // macOS-specific
    case archiveFunctionality = "tooltip_archive"
    case keyboardShortcuts = "tooltip_keyboard_shortcuts"  // macOS-specific
}

class MacTooltipManager: ObservableObject {
    static let shared = MacTooltipManager()
    private let shownTooltipsKey = "shownTooltips"  // Shared with iOS

    func hasShown(_ type: MacTooltipType) -> Bool
    func markAsShown(_ type: MacTooltipType)
    func resetAllTooltips()
    func shownTooltipCount() -> Int
    func totalTooltipCount() -> Int
    func markAllAsViewed()
}
```

### macOS-Specific Tips

iOS has swipe actions tip -> macOS has **context menu** tip (right-click)
macOS adds **keyboard shortcuts** tip (Cmd+N, Cmd+F, etc.)

Message adaptations:
- "Tap +" -> "Click + or press Cmd+Shift+N"
- "Swipe left" -> "Right-click on items"

### MacAllFeatureTipsView

- ScrollView with LazyVStack (avoids `List` conflict with ListAll.List model)
- Shows all tips with viewed status
- Header with "X/Y viewed" count
- Done button to dismiss

### Settings Integration

Added to GeneralSettingsTab:
- Feature Tips status (X of Y tips viewed)
- "View All Feature Tips" button
- "Show All Tips Again" button with confirmation

## Key Learnings

1. **SwiftUI List Type Conflict**: Codebase has `List` model conflicting with SwiftUI's `List`. Use `ScrollView` + `LazyVStack` instead.

2. **UserDefaults Sharing**: Both iOS and macOS use same key `"shownTooltips"` for cross-platform consistency.

3. **Platform-Specific Messages**: iOS patterns ("swipe left") don't apply on macOS. Create macOS-specific messages.
