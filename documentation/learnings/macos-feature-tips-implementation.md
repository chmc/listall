# macOS Feature Tips System Implementation

## Problem

The macOS app was missing the Feature Tips System that iOS had. iOS uses TooltipOverlay to show contextual tips, and users can:
- View all tips in Settings
- See which tips they've viewed
- Reset all tips to see them again

## Solution

### 1. Created MacTooltipManager

File: `ListAllMac/Utils/MacTooltipManager.swift`

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

### 2. macOS-Specific Tips

iOS has swipe actions tip → macOS has **context menu** tip (right-click)
macOS adds **keyboard shortcuts** tip (Cmd+N, Cmd+F, etc.)

Message adaptations:
- "Tap +" → "Click + or press Cmd+Shift+N"
- "Swipe left" → "Right-click on items"
- "Press Cmd+F to search"

### 3. Created MacAllFeatureTipsView

File: `ListAllMac/Views/Components/MacAllFeatureTipsView.swift`

- ScrollView with LazyVStack (avoids `List` conflict with ListAll.List model)
- Shows all tips with viewed status
- Header with "X/Y viewed" count
- Done button to dismiss

### 4. Added Help & Tips to MacSettingsView

Added to GeneralSettingsTab:
- Feature Tips status (X of Y tips viewed)
- "View All Feature Tips" button → opens sheet
- "Show All Tips Again" button → reset with confirmation

## Key Learnings

### 1. SwiftUI `List` Type Conflict

The codebase has a `List` model which conflicts with SwiftUI's `List`.
**Solution**: Use `ScrollView` + `LazyVStack` instead of `List`.

### 2. UserDefaults Sharing

Both iOS and macOS use the same UserDefaults key: `"shownTooltips"`.
This provides cross-platform consistency if the user syncs their device.

### 3. Platform-Specific Tip Messages

iOS-specific patterns like "swipe left" don't make sense on macOS.
Created macOS-specific tip types with appropriate messages:
- Context menus instead of swipe actions
- Keyboard shortcuts (Cmd+key patterns)

### 4. Settings Tab Structure

MacSettingsView uses TabView with 5 tabs. Added Help & Tips section to
the General tab to keep settings organized.

## Files Created/Modified

**New Files:**
- `ListAllMac/Utils/MacTooltipManager.swift` - Manager and types
- `ListAllMac/Views/Components/MacAllFeatureTipsView.swift` - Tips list view

**Modified Files:**
- `ListAllMac/Views/MacSettingsView.swift` - Added Help & Tips section
- `ListAllMacTests/ListAllMacTests.swift` - Added 18 tests

## Tests Added

18 unit tests in `FeatureTipsMacTests`:
- MacTooltipType tests (all cases, titles, icons, messages)
- MacTooltipManager tests (singleton, marking, reset)
- Settings integration tests
- Platform compatibility tests
- Documentation test
