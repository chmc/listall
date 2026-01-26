# ListAll macOS App - Completed Phases 15-16 (Feature Parity)

> **Navigation**: [Phases 1-4](./TODO.DONE.PHASES-1-4.md) | [Phases 5-7](./TODO.DONE.PHASES-5-7.md) | [Phases 8-11](./TODO.DONE.PHASES-8-11.md) | [Phases 12-14](./TODO.DONE.PHASES-12-14.md) | [Active Tasks](./TODO.md)

This document contains the completed Feature Parity tasks (Phases 15-16) ensuring iOS, iPadOS, macOS, and watchOS platforms have consistent functionality. Tasks were generated from `/documentation/FEATURE_PARITY.md` verification (January 2026).

**Tags**: feature-parity, macOS, iOS, iPad, SwiftUI, CSV-export, keyboard-shortcuts, sync-status, templates, bulk-delete, hover-effects, swipe-actions
**Completion Date**: January 26, 2026
**Total Tasks**: 24/24 completed

---

## Table of Contents

### Phase 15: Feature Parity - High & Medium Priority
1. [Phase 15 Overview](#phase-15-overview)
2. [Task 15.1: macOS Active/Archived Toggle](#task-151-macos-activearchived-toggle)
3. [Task 15.2: iPad Split View Layout](#task-152-ipad-split-view-layout)
4. [Task 15.4: macOS Bulk Delete Lists](#task-154-macos-bulk-delete-lists)
5. [Task 15.5: macOS Export CSV](#task-155-macos-export-csv)
6. [Task 15.6: macOS Manual Sync Button](#task-156-macos-manual-sync-button)
7. [Task 15.7: iOS Default Sort Order in Settings](#task-157-ios-default-sort-order-in-settings)
8. [Task 15.8: iPad Keyboard Shortcuts](#task-158-ipad-keyboard-shortcuts)

### Phase 16: Feature Parity - Low Priority & Polish
9. [Phase 16 Overview](#phase-16-overview)
10. [Task 16.1: macOS Filter: Has Description](#task-161-macos-filter-has-description)
11. [Task 16.2: macOS Filter: Has Images](#task-162-macos-filter-has-images)
12. [Task 16.3: macOS Duplicate Item Action](#task-163-macos-duplicate-item-action)
13. [Task 16.4: macOS Include Images in Share List](#task-164-macos-include-images-in-share-list)
14. [Task 16.5: macOS Collapse/Expand Suggestions Toggle](#task-165-macos-collapseexpand-suggestions-toggle)
15. [Task 16.6: macOS Live Sync Status Indicator](#task-166-macos-live-sync-status-indicator)
16. [Task 16.7: macOS Feature Tips Reset Button](#task-167-macos-feature-tips-reset-button)
17. [Task 16.8: macOS Auth Timeout Duration](#task-168-macos-auth-timeout-duration)
18. [Task 16.9: macOS Duplicate List Visibility](#task-169-macos-duplicate-list-visibility)
19. [Task 16.10: macOS Sample List Templates](#task-1610-macos-sample-list-templates)
20. [Task 16.11: iOS Live Sync Status Indicator](#task-1611-ios-live-sync-status-indicator)
21. [Task 16.12: iOS Clear All Filters Button](#task-1612-ios-clear-all-filters-button)
22. [Task 16.13: iOS Explicit 10 Image Limit UI](#task-1613-ios-explicit-10-image-limit-ui)
23. [Task 16.14: iOS Left Swipe Actions on Items](#task-1614-ios-left-swipe-actions-on-items)
24. [Task 16.15: iPad Multi-Column Layout](#task-1615-ipad-multi-column-layout)
25. [Task 16.16: iPad Pointer/Trackpad Hover Effects](#task-1616-ipad-pointertrackpad-hover-effects)
26. [Task 16.17: All Platforms - Test Data Images](#task-1617-all-platforms---test-data-images)

---

# Phase 15: Feature Parity - High & Medium Priority

## Phase 15 Overview

**Source**: Generated from `/documentation/FEATURE_PARITY.md` verification (2026-01-23)

**Priority Levels**:
- High: Critical feature gaps between platforms
- Medium: Important functionality differences

**Completion Date**: January 2026
**Total Tasks**: 7/7 completed

---

## Task 15.1: macOS Active/Archived Toggle

**Platform**: macOS | **Severity**: High

**Problem**: Feature was incorrectly flagged as missing. The collapsible "Archived" sidebar section already existed following macOS HIG pattern (superior to iOS toggle button). However, UITEST_MODE had no archived sample data, and the archive menu command handler was missing.

**Solution**:
1. Added archived list to UITestDataService.swift (English: "Old Shopping List", Finnish: "Vanha ostoslista")
2. Added missing `ArchiveSelectedList` notification handler in MacMainView.swift
3. Fixed CoreDataManager.addList() to preserve `isArchived` property
4. Fixed SwiftUI Section rendering by keeping ForEach always in view hierarchy

**Files Modified**:
- `ListAll/Services/UITestDataService.swift`
- `ListAllMac/Views/MacMainView.swift`
- `ListAll/Models/CoreData/CoreDataManager.swift`

---

## Task 15.2: iPad Split View Layout

**Platform**: iPad | **Severity**: High

**Problem**: iPad navigation style needed conditional handling for UITEST_MODE screenshots vs normal use.

**Solution**: Created `NavigationStyleModifier` that conditionally applies `.navigationViewStyle(.stack)`:
- iPhone: Always stack navigation (standard iOS pattern)
- iPad + UITEST_MODE: Stack for consistent App Store screenshots
- iPad normally: Default style (enables split view for better multitasking)

**Files Modified**:
- `ListAll/Views/MainView.swift`

---

## Task 15.4: macOS Bulk Delete Lists

**Platform**: macOS | **Severity**: Medium

**Problem**: Multi-select in sidebar had no delete option for multiple lists at once.

**Solution**: Added "Delete Lists" option to SelectionActionsMenu in ListsToolbarView with bulk delete functionality.

**Files Modified**:
- `ListAllMac/Views/Components/ListsToolbarView.swift`

---

## Task 15.5: macOS Export CSV

**Platform**: macOS | **Severity**: Medium

**Problem**: No CSV format option for spreadsheet compatibility.

**Solution**: Added CSV export option to ShareListView and ExportAllListsView dialogs with proper escaping and formatting.

**Files Modified**:
- `ListAllMac/Views/Components/MacShareFormatPickerView.swift`
- `ListAll/Services/ExportService.swift`

---

## Task 15.6: macOS Manual Sync Button

**Platform**: macOS | **Severity**: Medium

**Problem**: No manual sync trigger in toolbar.

**Status**: Already implemented in Task 12.6 (Sync Status Indicator):
- SyncStatusButton exists in NavigationSplitView toolbar
- Uses animated syncButtonImage with rotation effect during sync
- Calls cloudKitService.sync() when clicked
- Shows tooltip with sync status

---

## Task 15.7: iOS Default Sort Order in Settings

**Platform**: iOS | **Severity**: Medium

**Problem**: iOS Settings lacked default sort order picker that macOS has.

**Solution**: Added sort order picker to iOS SettingsView matching macOS implementation.

**Files Modified**:
- `ListAll/Views/SettingsView.swift`

---

## Task 15.8: iPad Keyboard Shortcuts

**Platform**: iPad | **Severity**: Medium

**Problem**: iPad with hardware keyboard had no keyboard shortcuts like macOS.

**Solution**: Added `.keyboardShortcut()` modifiers for common actions:
- Cmd+N: New item
- Cmd+F: Search
- Cmd+,: Settings

**Files Modified**:
- `ListAll/Views/MainView.swift`
- `ListAll/Views/ListView.swift`

---

# Phase 16: Feature Parity - Low Priority & Polish

## Phase 16 Overview

**Source**: Generated from `/documentation/FEATURE_PARITY.md` verification (2026-01-23)

**Priority Level**: Low - Polish items and minor feature gaps

**Completion Date**: January 2026
**Total Tasks**: 17/17 completed

---

## Task 16.1: macOS Filter: Has Description

**Platform**: macOS | **Severity**: Low

**Status**: Already implemented. Filter option `hasDescription` exists in `ItemFilterOption` enum (`Models/Item.swift` line 49) and is rendered in `MacItemOrganizationView.swift` via `ItemFilterOption.allCases`.

---

## Task 16.2: macOS Filter: Has Images

**Platform**: macOS | **Severity**: Low

**Status**: Already implemented. Filter option `hasImages` exists in `ItemFilterOption` enum (`Models/Item.swift` line 50) and is rendered in `MacItemOrganizationView.swift` via `ItemFilterOption.allCases`.

---

## Task 16.3: macOS Duplicate Item Action

**Platform**: macOS | **Severity**: Low

**Problem**: No duplicate option in item context menu.

**Solution**: Added "Duplicate" action to item context menu in MacMainView:
- Added `onDuplicate` callback parameter to `MacItemRowView` struct
- Added "Duplicate" button between Edit and Mark as Complete in context menu
- Calls `viewModel.duplicateItem(item)` to create a copy

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift`

---

## Task 16.4: macOS Include Images in Share List

**Platform**: macOS | **Severity**: Low

**Status**: Already implemented. "Include images" toggle exists in `MacShareFormatPickerView.swift` for JSON format. Images are base64 encoded when enabled, matching iOS behavior.

---

## Task 16.5: macOS Collapse/Expand Suggestions Toggle

**Platform**: macOS | **Severity**: Low

**Status**: Already implemented. `MacSuggestionListView.swift` has "Show All" / "Show Top 3" toggle that expands/collapses the suggestions list beyond the default 3 items.

---

## Task 16.6: macOS Live Sync Status Indicator

**Platform**: macOS | **Severity**: Low

**Status**: Already implemented in Task 12.6. `MacMainView.swift` has:
- `syncButtonImage` with rotation animation during sync
- `syncTooltipText` showing "Last synced X ago" or error state
- Toolbar button that triggers manual sync

---

## Task 16.7: macOS Feature Tips Reset Button

**Platform**: macOS | **Severity**: Low

**Status**: Already implemented. `MacSettingsView.swift` shows:
- Tip count: "X of Y feature tips viewed"
- "View All Feature Tips" button
- "Show All Tips Again" button that calls `tooltipManager.resetAllTooltips()`

---

## Task 16.8: macOS Auth Timeout Duration

**Platform**: macOS | **Severity**: Low

**Status**: Already implemented. `MacSettingsView.swift` has "Require Authentication" picker with all `AuthTimeoutDuration` options: Immediately, After 1 minute, After 5 minutes, After 15 minutes, After 1 hour.

---

## Task 16.9: macOS Duplicate List Visibility

**Platform**: macOS | **Severity**: Low

**Problem**: The "DuplicateSelectedList" notification was posted from AppCommands.swift (Cmd+D) but never handled.

**Solution**: Added notification handler and duplicateList() function to MacMainView:
- Handler for NSNotification.Name("DuplicateSelectedList")
- duplicateList() creates a copy with unique name "(Copy)" or "(Copy N)"
- Copies all items from original list
- Auto-selects the newly duplicated list

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift`

---

## Task 16.10: macOS Sample List Templates

**Platform**: macOS | **Severity**: Low

**Problem**: No template picker when creating new lists.

**Solution**: Added template picker in CreateListView with options:
- Grocery
- Travel
- Project
- Custom (blank)

**Files Modified**:
- `ListAllMac/Views/Components/MacCreateListView.swift`
- `ListAll/Models/ListTemplate.swift` (NEW)

---

## Task 16.11: iOS Live Sync Status Indicator

**Platform**: iOS | **Severity**: Low

**Problem**: No visual sync animation on iOS like macOS.

**Solution**: Enhanced iOS sync button with visual feedback:
- Added `syncButtonImage` computed property with rotation animation
- iOS 18+: Uses `.symbolEffect(.rotate)` for smooth animation
- iOS 17: Fallback using `.rotationEffect()` with linear animation
- Red color when `syncError != nil`
- Dynamic accessibility label showing sync state

**Files Modified**:
- `ListAll/Views/MainView.swift`

---

## Task 16.12: iOS Clear All Filters Button

**Platform**: iOS | **Severity**: Low

**Problem**: No quick way to reset all filters on iOS.

**Solution**:
- Added "Reset" button to toolbar in ItemOrganizationView.swift
- Button only appears when `viewModel.hasActiveFilters` is true
- Calls `viewModel.clearAllFilters()` with animation
- Button styled in red to indicate destructive action
- Added Finnish localization for accessibility string

**Files Modified**:
- `ListAll/Views/Components/ItemOrganizationView.swift`
- `ListAll/Localizable.xcstrings`

---

## Task 16.13: iOS Explicit 10 Image Limit UI

**Platform**: iOS | **Severity**: Low

**Problem**: Image limit not visible until reached.

**Solution**: Added clear visual feedback for image limit in ItemEditView:
- Display count/limit indicator (e.g., "3/10") on Add Photo button
- Orange color warning when approaching limit (8+ images)
- Disable Add Photo button at 10 images
- Change text to "Image Limit Reached" when at limit
- Change plus icon to exclamationmark when at limit

**Files Modified**:
- `ListAll/Views/ItemEditView.swift`

---

## Task 16.14: iOS Left Swipe Actions on Items

**Platform**: iOS | **Severity**: Low

**Problem**: No edit/duplicate actions on left swipe.

**Solution**: Added leading edge swipe actions to ItemRowView:
- Left swipe reveals Edit (blue) and Duplicate (green) buttons
- Follows Apple HIG: non-destructive actions on leading edge
- Right swipe Delete action unchanged (trailing edge, full swipe enabled)
- Actions hidden during selection mode

**Files Modified**:
- `ListAll/Views/Components/ItemRowView.swift`

---

## Task 16.15: iPad Multi-Column Layout

**Platform**: iPad | **Severity**: Low

**Status**: Already implemented. `MainView.swift` uses `NavigationStyleModifier` that:
- Uses `.stack` navigation on iPhone (always)
- Uses default (automatic/split) navigation on iPad (enables multi-column)
- Only forces stack on iPad during UITEST_MODE for consistent screenshots

iPad already displays split view with Lists sidebar and Items content side-by-side.

---

## Task 16.16: iPad Pointer/Trackpad Hover Effects

**Platform**: iPad | **Severity**: Low

**Problem**: No hover effects for Magic Keyboard/trackpad users.

**Solution**: Added `.hoverEffect()` modifiers to interactive elements:
- `ItemRowView.swift`: `.lift` effect for list rows
- `ListRowView.swift`: `.lift` effect for list rows
- `MainView.swift`: `.highlight` effect for toolbar buttons
- `ListView.swift`: `.highlight` effect for toolbar buttons, `.lift` for FAB
- `SettingsView.swift`: `.highlight` effect for action buttons

**Note**: Hover effects provide visual feedback on iPad with Magic Keyboard/trackpad. No-op on iPhone and macOS. Not visually testable via screenshots - requires physical trackpad.

**Files Modified**:
- `ListAll/Views/Components/ItemRowView.swift`
- `ListAll/Views/Components/ListRowView.swift`
- `ListAll/Views/MainView.swift`
- `ListAll/Views/ListView.swift`
- `ListAll/Views/SettingsView.swift`

---

## Task 16.17: All Platforms - Test Data Images

**Platform**: All | **Severity**: Low

**Problem**: UITEST_MODE had no test images to verify image gallery functionality.

**Solution**: Added programmatic test image generation to UITestDataService.swift:
- Created `generateTestImages()` method that generates 3 colored rectangle images
- Uses platform-specific APIs: `UIGraphicsImageRenderer` for iOS/iPad, `NSImage` drawing for macOS
- watchOS returns empty array (no images on watch)
- Added images to "Eggs" item in English test data and "Kananmunat" in Finnish
- Images are JPEG compressed at 0.7 quality (100x100 pixels each)

**Files Modified**:
- `ListAll/Services/UITestDataService.swift`

---

> **Navigation**: [Phases 1-4](./TODO.DONE.PHASES-1-4.md) | [Phases 5-7](./TODO.DONE.PHASES-5-7.md) | [Phases 8-11](./TODO.DONE.PHASES-8-11.md) | [Phases 12-14](./TODO.DONE.PHASES-12-14.md) | [Active Tasks](./TODO.md)
