# ListAll macOS App Implementation Plan

This document provides a comprehensive, task-by-task plan for creating the ListAll macOS app with full feature parity to iOS, automated CI/CD release pipeline, and TDD principles.

## Task Execution Rules

**IMPORTANT**: Work on ONE task at a time. When start task, mark it in-progress. When a task is completed:
1. Mark it as `[COMPLETED]`
2. Stop and wait for user instructions
3. Do NOT proceed to the next task without explicit permission

## Task Status Convention

Mark task titles with status indicators:
- **In Progress**: `### Task X.X: [IN PROGRESS] Task Title`
- **Completed**: `### Task X.X: [COMPLETED] Task Title`
- **Not Started**: No prefix (default)

---

## Completed Phases (1-11)

> **Full implementation details**: See [TODO.DONE.md](./TODO.DONE.md)

All phases 1-11 have been completed with full TDD, code examples, and documentation.
The detailed implementation records are preserved in [TODO.DONE.md](./TODO.DONE.md) for reference.

| Phase | Description | Tasks | Details |
|-------|-------------|-------|---------|
| 1 | Project Setup & Architecture | 5/5 ✅ | [View](./TODO.DONE.md#phase-1-project-setup--architecture) |
| 2 | Core Data & Models | 3/3 ✅ | [View](./TODO.DONE.md#phase-2-core-data--models) |
| 3 | Services Layer | 7/7 ✅ | [View](./TODO.DONE.md#phase-3-services-layer) |
| 4 | ViewModels | 5/5 ✅ | [View](./TODO.DONE.md#phase-4-viewmodels) |
| 5 | macOS-Specific Views | 11/11 ✅ | [View](./TODO.DONE.md#phase-5-macos-specific-views) |
| 6 | Advanced Features | 4/4 ✅ | [View](./TODO.DONE.md#phase-6-advanced-features) |
| 7 | Testing Infrastructure | 4/4 ✅ | [View](./TODO.DONE.md#phase-7-testing-infrastructure) |
| 8 | Feature Parity with iOS | 4/4 ✅ | [View](./TODO.DONE.md#phase-8-feature-parity-with-ios) |
| 9 | CI/CD Pipeline | 7/7 ✅ | [View](./TODO.DONE.md#phase-9-cicd-pipeline) |
| 10 | App Store Preparation | 5/5 ✅ | [View](./TODO.DONE.md#phase-10-app-store-preparation) |
| 11 | Polish & Launch | 9/9 ✅ | [View](./TODO.DONE.md#phase-11-polish--launch) |

**Total Completed**: 64 tasks across 11 phases

---

## Phase 12: macOS UX Polish & Best Practices

> **Research basis**: Agent swarm analysis (January 2026) including Apple HIG review, industry best practices research, critical UX audit, and code analysis.

### Overview

This phase addresses UX issues identified through comprehensive analysis of macOS Human Interface Guidelines, best-in-class apps (Things 3, Fantastical, Bear, OmniFocus), and critical review of current ListAll macOS implementation.

**Priority Levels**:
- 🔴 **CRITICAL**: Platform convention violations that break user expectations
- 🟠 **IMPORTANT**: Significant UX friction or inconsistencies
- 🟡 **MINOR**: Polish items and power user conveniences

---

### Task 12.1: [COMPLETED] Implement Cmd+Click Multi-Select (CRITICAL)

**TDD**: Write tests for Cmd+Click and Shift+Click selection behavior

**Problem**: macOS users expect Cmd+Click to select multiple items without entering a special mode. Currently, users must click a toolbar button to enter "selection mode" first - this violates fundamental macOS conventions.

**Current behavior** (MacMainView.swift ~line 1929):
- Selection only works after entering selection mode via toolbar button
- No support for Cmd+Click or Shift+Click

**Expected macOS behavior**:
- Cmd+Click: Toggle selection of individual items
- Shift+Click: Select range from last selected item
- Click (no modifier): Single select, clear others
- Selection mode toolbar button: Optional bulk operation UI

**Implementation**:
```swift
// Item row modifier
.simultaneousGesture(TapGesture().modifiers(.command).onEnded {
    viewModel.toggleSelection(item.id)
})
.simultaneousGesture(TapGesture().modifiers(.shift).onEnded {
    viewModel.selectRange(to: item.id)
})
```

**Test criteria**:
```swift
func testCmdClickTogglesSelection() {
    // Cmd+Click on item adds to selection
    // Cmd+Click again removes from selection
}

func testShiftClickSelectsRange() {
    // Click item 1, Shift+Click item 5
    // Items 1-5 should be selected
}

func testRegularClickClearsSelection() {
    // With items selected, regular click clears and selects only clicked item
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Add gesture modifiers to item rows
- `ListAll/ViewModels/ListViewModel.swift` - Add `selectRange(to:)` method

**References**:
- Apple HIG: Selection patterns
- Finder, Mail, Notes selection behavior

**Completed** (January 15, 2026):

**Implementation Summary**:
1. **ListViewModel Changes**:
   - Added `@Published var lastSelectedItemID: UUID?` for anchor point tracking
   - Added `selectRange(to targetId: UUID)` method for Shift+Click range selection
   - Added `handleClick(for:commandKey:shiftKey:)` method for handling clicks with modifiers
   - Updated `toggleSelection(for:)` to update `lastSelectedItemID` on selection
   - Updated `exitSelectionMode()` to clear `lastSelectedItemID`

2. **MacMainView Changes**:
   - Added `ModifierClickHandler` view modifier using NSEvent local monitoring
   - Uses mouseUp detection with distance threshold (5 points) and time threshold (300ms)
   - Does NOT block drag-and-drop (returns event to continue processing)
   - Added `.onModifierClick(command:shift:)` to item rows in `itemsListView`

3. **TestListViewModel Updated**:
   - Added matching `lastSelectedItemID`, `selectRange(to:)`, and `handleClick()` methods

**Files Modified**:
- `ListAll/ViewModels/ListViewModel.swift` - Added selection methods
- `ListAllMac/Views/MacMainView.swift` - Added ModifierClickHandler (~170 lines)
- `ListAllMacTests/TestHelpers.swift` - Updated TestListViewModel
- `ListAllMacTests/ListAllMacTests.swift` - Added CmdClickMultiSelectTests (16 tests)

**Test Results**: All 16 CmdClickMultiSelectTests passed

---

### Task 12.2: Fix Cmd+F Global Search Scope (CRITICAL)

**TDD**: Write tests for Cmd+F focus behavior from any view state

**Problem**: Cmd+F only works when focus is already in the detail pane. If focus is in sidebar, Cmd+F does nothing - but Feature Tips claim "Press Cmd+F to search across all items."

**Current behavior** (MacMainView.swift ~line 1611-1618):
- `.onKeyPress(characters: "f")` only on detail view
- Does not work when sidebar has focus

**Expected behavior**:
- Cmd+F works from ANY focus location
- Always focuses the search field in detail view
- If no list selected, shows helpful message

**Implementation**:
```swift
// At MacMainView level (not nested in detail)
.onKeyPress(characters: "f", modifiers: .command) {
    isSearchFieldFocused = true
    return .handled
}
```

**Test criteria**:
```swift
func testCmdFFromSidebar() {
    // Focus sidebar, press Cmd+F
    // Search field in detail should be focused
}

func testCmdFFromDetailView() {
    // Focus detail view, press Cmd+F
    // Search field should be focused
}

func testCmdFWithNoListSelected() {
    // No list selected, press Cmd+F
    // Should show empty state or select first list
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Move Cmd+F handler to top level

---

### Task 12.3: Improve Selection Mode Discoverability (CRITICAL)

**TDD**: Write tests for selection mode visual indicators

**Problem**: Selection mode is activated by a "pencil" icon that suggests "edit" not "multi-select." Users cannot discover this feature intuitively.

**Current issues**:
- Sidebar uses "pencil" icon for selection mode
- Detail view uses "checkmark.circle" icon
- No tooltip explains the functionality
- No onboarding explains multi-select

**Recommendations**:
1. Change icons to be more descriptive
2. Add proper tooltips
3. Show selection count badge when items selected
4. Consider contextual hint on first use

**Implementation**:
```swift
// Sidebar selection button
Button(action: { isInSelectionMode.toggle() }) {
    Label(isInSelectionMode ? "Done" : "Select",
          systemImage: isInSelectionMode ? "checkmark" : "checklist")
}
.help(isInSelectionMode ? "Exit selection mode" : "Select multiple lists")

// Selection count indicator
if !selectedListIDs.isEmpty {
    Text("\(selectedListIDs.count) selected")
        .font(.caption)
        .foregroundColor(.secondary)
}
```

**Test criteria**:
```swift
func testSelectionModeButtonHasTooltip() {
    // Verify help tooltip is present
}

func testSelectionCountDisplayed() {
    // Select 3 items
    // Verify "3 selected" is visible
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Update toolbar buttons and add selection count

---

### Task 12.4: Redesign Filter UI from iOS Popover to Native macOS Pattern (CRITICAL)

**TDD**: Write tests for always-visible filter controls and keyboard shortcuts

**Problem**: Current filter UI uses iOS-style popover pattern (click button → popover opens → select filter → popover closes). This violates macOS conventions and feels clumsy to users.

**Agent Swarm Research Findings** (January 2026):
- **None of 7 best-in-class macOS apps** (Finder, Mail, Notes, Reminders, Things 3, Bear, OmniFocus) use popovers for primary filtering
- All use **always-visible controls**: sidebar sections, toolbar buttons, or segmented controls
- Apple HIG explicitly discourages popovers for "frequently used filters"

**Current implementation** (MacMainView.swift ~lines 1120-1132):
```swift
// iOS-ism: Button → Popover → Select → Dismiss
Button(action: { showingOrganizationPopover.toggle() }) {
    Image(systemName: "arrow.up.arrow.down")
}
.popover(isPresented: $showingOrganizationPopover) {
    MacItemOrganizationView(viewModel: viewModel)
}
```

**Problems**:
1. Filter state hidden until clicked (no discoverability)
2. Requires 2 clicks + animation wait to change filter
3. No keyboard shortcuts for filters
4. No View menu integration (macOS convention)
5. Badge dismissal pattern is iOS-native, not macOS-native

**Recommended Solution: Segmented Control + View Menu + Keyboard Shortcuts**

**Phase 1: Toolbar Segmented Control**
```swift
// Replace popover button with segmented control
Picker("Filter", selection: $viewModel.currentFilterOption) {
    Text("All").tag(ItemFilterOption.all)
    Text("Active").tag(ItemFilterOption.active)
    Text("Done").tag(ItemFilterOption.completed)
}
.pickerStyle(.segmented)
.frame(width: 200)
```

**Phase 2: View Menu Integration**
```swift
// In AppCommands.swift
CommandMenu("View") {
    Button("All Items") { viewModel.updateFilterOption(.all) }
        .keyboardShortcut("1", modifiers: .command)
    Button("Active Only") { viewModel.updateFilterOption(.active) }
        .keyboardShortcut("2", modifiers: .command)
    Button("Completed Only") { viewModel.updateFilterOption(.completed) }
        .keyboardShortcut("3", modifiers: .command)
    Divider()
    // Sort options submenu
}
```

**Phase 3 (Optional): Sidebar Smart Lists**
```
┌─────────────────┐
│ MY LISTS        │
│ • Shopping      │
│ • Work Tasks    │
│                 │
│ SMART FILTERS   │
│ ⚙ All Active    │
│ ⚙ Completed     │
│ ⚙ Has Images    │
└─────────────────┘
```

**Best-in-class app patterns analyzed**:
| App | Filter Pattern |
|-----|----------------|
| Finder | Sidebar Smart Folders + Search tokens |
| Mail | Toolbar Focus button (changes color when active) |
| Reminders | Sidebar Smart Lists |
| Things 3 | Sidebar + Type-anywhere Quick Find |
| Bear | Sidebar tag hierarchy with pinning |
| OmniFocus | Sidebar Perspectives (saved filters) |

**Implementation priority**:
1. ⭐ Segmented control in toolbar (simplest, high impact)
2. ⭐ View menu with Cmd+1/2/3 shortcuts (macOS convention)
3. 🔄 Keep sort options in popover (less frequent)
4. 🔮 Sidebar Smart Lists (future enhancement)

**Test criteria**:
```swift
func testSegmentedControlChangesFilter() {
    // Click "Active" segment
    // Verify filter changes immediately (no popover)
}

func testKeyboardShortcutChangesFilter() {
    // Press Cmd+2
    // Verify filter changes to Active
}

func testViewMenuShowsFilterOptions() {
    // Open View menu
    // Verify All Items, Active Only, Completed Only present
    // Verify keyboard shortcuts shown
}

func testCurrentFilterVisibleInToolbar() {
    // Set filter to Active
    // Verify "Active" segment is selected (visible without clicking)
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Replace popover with segmented control
- `ListAllMac/Commands/AppCommands.swift` - Add View menu with filter options
- `ListAllMac/Views/Components/MacItemOrganizationView.swift` - Keep for sort options only

**Research documents**:
- Agent: Apple Development Researcher - macOS filter patterns research
- Agent: Explore - Current implementation analysis
- Agent: Critical Reviewer - iOS-ism critique and alternatives ranking

---

### Task 12.5: Add Proactive Feature Tips (IMPORTANT)

**TDD**: Write tests for contextual tip display

**Problem**: MacTooltipManager tracks tip view state but tips are only visible via Settings > General > View All Feature Tips. Users must navigate to settings to learn features.

**Current state**:
- 12 tips defined in MacTooltipManager
- Tips never appear proactively
- Only accessible via settings

**Expected behavior**:
- Show tips contextually when users first encounter features
- First launch onboarding flow
- "What's New" after updates
- Tip popovers anchored to relevant UI elements

**Implementation approach**:
```swift
// Contextual tip modifier
.popover(isPresented: $showKeyboardTip) {
    FeatureTipView(tip: .keyboardNavigation)
}
.onAppear {
    if !MacTooltipManager.shared.hasViewedTip(.keyboardNavigation) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showKeyboardTip = true
        }
    }
}
```

**Test criteria**:
```swift
func testFirstLaunchShowsOnboarding() {
    // Fresh install
    // Verify welcome/onboarding sheet appears
}

func testTipAppearsOnFirstFeatureUse() {
    // First time using keyboard navigation
    // Tip should appear after 2 seconds
}

func testTipDoesNotRepeat() {
    // Mark tip as viewed
    // Verify it doesn't appear again
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Add tip popovers
- `ListAllMac/Utils/MacTooltipManager.swift` - Add `shouldShowTip()` logic

---

### Task 12.6: Add Sync Status Indicator in Toolbar (IMPORTANT)

**TDD**: Write tests for sync status visibility and animation

**Problem**: Last sync time is hidden in a tiny footer at the bottom of sidebar. Users have no visual indication when sync is happening or if there are conflicts.

**Current state** (MacMainView.swift ~lines 601-610):
- Sync status only in sidebar footer
- No animation during sync
- Errors not prominently displayed

**Expected behavior**:
- Sync icon in toolbar that animates during sync
- Last sync time in tooltip
- Error indicator when sync fails
- Click to trigger manual sync

**Implementation**:
```swift
// Toolbar sync indicator
ToolbarItem(placement: .automatic) {
    Button(action: { cloudKitService.sync() }) {
        Image(systemName: "arrow.triangle.2.circlepath")
            .symbolEffect(.rotate, isActive: cloudKitService.isSyncing)
    }
    .help(lastSyncDescription)
    .foregroundColor(syncHasError ? .red : .primary)
}
```

**Test criteria**:
```swift
func testSyncIconAnimatesDuringSync() {
    // Trigger sync
    // Verify animation is active
}

func testSyncTooltipShowsLastSyncTime() {
    // Verify tooltip contains "Last synced X ago"
}

func testSyncErrorShowsRedIndicator() {
    // Simulate sync error
    // Verify icon turns red
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Add toolbar sync indicator

---

### Task 12.7: Consistent Empty State Components (IMPORTANT)

**TDD**: Write tests for empty state consistency

**Problem**: Two different empty list views exist:
- `MacItemsEmptyStateView` - Comprehensive with tips (MacEmptyStateView.swift)
- Inline `emptyListView` - Simple "No items in this list" (MacMainView.swift ~line 1202)

MacListDetailView uses the simple inline view instead of the comprehensive component.

**Expected behavior**:
- Use `MacItemsEmptyStateView` consistently
- Empty search results get dedicated messaging
- Archived lists empty state has proper guidance

**Implementation**:
```swift
// Replace inline emptyListView with component
if viewModel.filteredItems.isEmpty {
    if !searchText.isEmpty {
        MacSearchEmptyStateView(
            searchText: searchText,
            onClear: { searchText = "" }
        )
    } else {
        MacItemsEmptyStateView(listName: selectedList.name)
    }
}
```

**Test criteria**:
```swift
func testEmptyListShowsComprehensiveView() {
    // Empty list displays MacItemsEmptyStateView
}

func testEmptySearchShowsSearchEmptyState() {
    // Search with no results shows search-specific empty state
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Replace inline empty views
- `ListAllMac/Views/Components/MacEmptyStateView.swift` - Add `MacSearchEmptyStateView`

---

### Task 12.8: Standardize Destructive Action Handling (IMPORTANT)

**TDD**: Write tests for consistent undo/confirmation behavior

**Problem**: Delete confirmation behavior is inconsistent:
- Bulk delete: Shows confirmation dialog "This action cannot be undone"
- Individual delete: Uses undo banner without confirmation

**Expected macOS behavior**:
- Undo banners for all deletes with 10-second window
- No confirmation dialogs for recoverable actions
- Confirmation only for truly destructive operations (like permanent delete from archive)

**Implementation**:
```swift
// Individual delete with undo
func deleteItem(_ item: Item) {
    let deletedItem = item
    viewModel.deleteItem(item)
    showUndoBanner(
        message: "Item deleted",
        action: { viewModel.restoreItem(deletedItem) }
    )
}

// Bulk delete also uses undo (not confirmation)
func deleteSelectedItems() {
    let deletedItems = selectedItems
    viewModel.deleteItems(selectedItems)
    showUndoBanner(
        message: "\(deletedItems.count) items deleted",
        action: { viewModel.restoreItems(deletedItems) }
    )
}
```

**Test criteria**:
```swift
func testIndividualDeleteShowsUndo() {
    // Delete item
    // Verify undo banner appears
}

func testBulkDeleteShowsUndo() {
    // Delete 5 items
    // Verify undo banner with count appears
}

func testUndoRestoresItems() {
    // Delete, then undo
    // Verify items restored
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Standardize delete handling

---

### Task 12.9: Make Settings Window Resizable (IMPORTANT)

**TDD**: Write tests for settings window size constraints

**Problem**: Settings window has fixed 500x350 size. Users with large text or different languages may have clipped content.

**Current state** (MacSettingsView.swift line 58):
```swift
.frame(width: 500, height: 350)
```

**Expected behavior**:
- Minimum size ensures layout integrity
- Window can expand for accessibility
- Remembers user-adjusted size

**Implementation**:
```swift
.frame(minWidth: 500, idealWidth: 550, minHeight: 350, idealHeight: 400)
```

**Test criteria**:
```swift
func testSettingsWindowHasMinimumSize() {
    // Cannot resize below 500x350
}

func testSettingsWindowCanExpand() {
    // Can resize larger than minimum
}
```

**Files to modify**:
- `ListAllMac/Views/MacSettingsView.swift` - Update frame constraints

---

### Task 12.10: Add Quick Entry Window (MINOR)

**TDD**: Write tests for Quick Entry functionality

**Problem**: No way to quickly add items from anywhere in macOS without switching to the app. Power users expect a Things 3-style Quick Entry feature.

**Expected behavior**:
- Global keyboard shortcut (configurable, default Cmd+Option+Space)
- Small floating window appears
- Type item title, optionally select list
- Press Enter to save, Escape to dismiss
- Returns focus to previous app

**Implementation**:
```swift
// In ListAllMacApp.swift
Window("Quick Entry", id: "quickEntry") {
    QuickEntryView()
        .frame(width: 500, height: 150)
}
.windowStyle(.hiddenTitleBar)
.windowLevel(.floating)
.defaultPosition(.center)
.keyboardShortcut("space", modifiers: [.command, .option])
```

**Test criteria**:
```swift
func testQuickEntryOpensWithShortcut() {
    // Press Cmd+Option+Space
    // Quick Entry window appears
}

func testQuickEntryCreatesItem() {
    // Type "Buy groceries", press Enter
    // Item added to selected/default list
}

func testQuickEntryDismissesWithEscape() {
    // Press Escape
    // Window closes without saving
}
```

**Files to create**:
- `ListAllMac/Views/QuickEntryView.swift`

**Files to modify**:
- `ListAllMac/ListAllMacApp.swift` - Add Quick Entry scene

---

### Task 12.11: Add Keyboard Reordering (MINOR)

**TDD**: Write tests for keyboard-based item reordering

**Problem**: Items can only be reordered via drag-and-drop. Users with motor disabilities or keyboard-first workflows cannot reorder without mouse.

**Expected behavior**:
- Cmd+Option+Up/Down moves selected item up/down
- Visual feedback during move
- Works when sorted by "Order"

**Implementation**:
```swift
.onKeyPress(.upArrow, modifiers: [.command, .option]) {
    guard viewModel.currentSortOption == .orderNumber else { return .ignored }
    viewModel.moveItemUp(focusedItemID)
    return .handled
}
```

**Test criteria**:
```swift
func testCmdOptionUpMovesItemUp() {
    // Select item at position 3
    // Press Cmd+Option+Up
    // Item moves to position 2
}

func testReorderOnlyWorksWithOrderSort() {
    // Sort by date
    // Cmd+Option+Up does nothing
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Add keyboard handlers
- `ListAll/ViewModels/ListViewModel.swift` - Add `moveItemUp()/moveItemDown()`

---

### Task 12.12: Add Clear All Filters Shortcut (MINOR)

**TDD**: Write tests for filter clearing

**Problem**: Active filter badges can only be cleared by clicking the X on each badge. No keyboard shortcut to clear all filters quickly.

**Expected behavior**:
- Cmd+Shift+Backspace clears all filters
- Escape while search focused clears search AND filters
- Button to "Clear all" when filters active

**Implementation**:
```swift
.onKeyPress(.delete, modifiers: [.command, .shift]) {
    clearAllFilters()
    return .handled
}

func clearAllFilters() {
    searchText = ""
    activeFilter = nil
    activeSortOption = .orderNumber
}
```

**Test criteria**:
```swift
func testCmdShiftBackspaceClearsFilters() {
    // Set search text and filter
    // Press Cmd+Shift+Backspace
    // All filters cleared
}
```

**Files to modify**:
- `ListAllMac/Views/MacMainView.swift` - Add keyboard handler

---

### Task 12.13: Add Image Gallery Size Presets (MINOR)

**TDD**: Write tests for thumbnail size presets

**Problem**: Thumbnail size slider (80-200px) has no presets. Users must drag to find optimal size.

**Expected behavior**:
- Preset buttons: Small (80), Medium (120), Large (160)
- Slider for fine-tuning
- Remember last used size per list or globally

**Implementation**:
```swift
HStack {
    Button("S") { thumbnailSize = 80 }
    Button("M") { thumbnailSize = 120 }
    Button("L") { thumbnailSize = 160 }
    Slider(value: $thumbnailSize, in: 80...200)
}
```

**Test criteria**:
```swift
func testSmallPresetSets80() {
    // Click Small button
    // Thumbnail size = 80
}

func testSizeIsPersisted() {
    // Set size to 150
    // Reopen gallery
    // Size still 150
}
```

**Files to modify**:
- `ListAllMac/Views/Components/MacImageGalleryView.swift`

---

### Research Documents Created

This phase is based on comprehensive research documented in:

1. **Apple HIG Research** (Agent: Apple Development Expert)
   - macOS navigation patterns, toolbar design, menu structure
   - List app UX patterns from Things 3, OmniFocus, Reminders
   - Anti-patterns: iOS-isms, common macOS mistakes
   - SwiftUI modern conventions

2. **Industry Best Practices** (Agent: Apple Development Researcher)
   - 2025 Liquid Glass design language
   - Quick Entry pattern analysis
   - Accessibility best practices
   - Learning from Things 3, Fantastical, Bear

3. **Code Analysis** (Agent: Explore)
   - Current implementation patterns
   - Navigation structure audit
   - Context menu and toolbar analysis
   - Empty state consistency review

4. **Critical UX Review** (Agent: Critical Reviewer)
   - 3 CRITICAL issues identified
   - 5 IMPORTANT issues identified
   - 4 MINOR issues identified
   - Platform convention violations documented

**Learnings file**: `/documentation/learnings/macos-ux-best-practices-research-2025.md`

---

## Phase 13: App Store Submission

### Task 13.1: Submit to App Store
**TDD**: Submission verification

**Steps**:
1. Run full test suite
2. Build release version
3. Submit for review via:
   ```bash
   bundle exec fastlane release_mac version:1.0.0
   ```

---

## Phase 14: Spotlight Integration (Optional)

### Task 14.1: Implement Spotlight Integration
**TDD**: Write Spotlight indexing tests

**Priority**: Low - Optional feature, disabled by default

**User Setting**:
- Add "Enable Spotlight Indexing" toggle in Settings → General
- Default value: `false` (disabled)
- When enabled, indexes lists and items for Spotlight search
- When disabled, no Spotlight indexing occurs (saves battery/resources)

**Steps**:
1. Add `enableSpotlightIndexing` UserDefaults key (default: false)
2. Add toggle in MacSettingsView General tab
3. Create SpotlightService with conditional indexing:
   ```swift
   class SpotlightService {
       static let shared = SpotlightService()

       var isEnabled: Bool {
           UserDefaults.standard.bool(forKey: "enableSpotlightIndexing")
       }

       func indexItem(_ item: Item) {
           guard isEnabled else { return }
           // Index with Core Spotlight
       }

       func removeItem(_ item: Item) {
           guard isEnabled else { return }
           // Remove from index
       }

       func reindexAll() {
           guard isEnabled else { return }
           // Full reindex
       }

       func clearIndex() {
           // Always allow clearing
       }
   }
   ```
4. Index lists and items with Core Spotlight when enabled
5. Support Spotlight search results
6. Handle Spotlight result activation (deep link to item)
7. Clear index when setting is disabled

**Test criteria**:
```swift
func testSpotlightIndexingDisabledByDefault() {
    XCTAssertFalse(UserDefaults.standard.bool(forKey: "enableSpotlightIndexing"))
}

func testSpotlightIndexingWhenEnabled() {
    UserDefaults.standard.set(true, forKey: "enableSpotlightIndexing")
    // Test items appear in Spotlight
}

func testSpotlightIndexingSkippedWhenDisabled() {
    UserDefaults.standard.set(false, forKey: "enableSpotlightIndexing")
    // Verify no indexing occurs
}
```

## Appendix A: File Structure

```
ListAll/
├── ListAll/                    # iOS app (existing)
├── ListAllWatch Watch App/     # watchOS app (existing)
├── ListAllMac/                 # NEW: macOS app
│   ├── ListAllMacApp.swift
│   ├── Info.plist
│   ├── ListAllMac.entitlements
│   ├── Views/
│   │   ├── MacMainView.swift
│   │   ├── MacListDetailView.swift
│   │   ├── MacItemDetailView.swift
│   │   ├── MacSettingsView.swift
│   │   └── Components/
│   │       ├── MacSidebarView.swift
│   │       ├── MacItemRowView.swift
│   │       ├── MacImageGalleryView.swift
│   │       ├── MacEmptyStateView.swift
│   │       ├── MacCreateListView.swift
│   │       └── MacEditListView.swift
│   ├── Services/
│   │   └── MacBiometricAuthService.swift
│   └── Commands/
│       └── AppCommands.swift
├── ListAllMacTests/            # NEW: macOS unit tests
└── ListAllMacUITests/          # NEW: macOS UI tests
```

## Appendix B: Bundle Identifiers

| Platform | Bundle ID |
|----------|-----------|
| iOS | `io.github.chmc.ListAll` |
| watchOS | `io.github.chmc.ListAll.watchkitapp` |
| macOS | `io.github.chmc.ListAllMac` |

## Appendix C: Deployment Targets

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 17.0 |
| watchOS | 10.0 |
| macOS | 14.0 |

## Appendix D: CI/CD Workflow Updates

### Architecture: Parallel Jobs (Not Sequential)

Based on swarm analysis, all workflows use **parallel jobs** for platform isolation:

**Benefits**:
- ~35% faster CI (15 min vs 23 min)
- Failure isolation (macOS failure doesn't block iOS)
- Easier debugging (per-platform logs)
- Cost increase of ~43% justified by speed gains and developer productivity

### ci.yml Changes
- Refactor single job → 3 parallel jobs:
  - `build-and-test-ios` (timeout: 30 min)
  - `build-and-test-watchos` (timeout: 25 min)
  - `build-and-test-macos` (timeout: 20 min, no simulator)
- Per-platform cache keys
- Per-platform artifact uploads

### release.yml Changes
- Add `version-bump` job (runs first, outputs version)
- Split beta into parallel jobs:
  - `beta-ios` (depends on version-bump)
  - `beta-macos` (depends on version-bump, parallel with beta-ios)
- Add platform selection input (`ios`, `macos`, or both)
- Version bump applies to all platforms

### prepare-appstore.yml Changes
- Add `screenshots-macos` job (parallel with iPhone/iPad/Watch)
- macOS screenshots: 2880x1800 (16:10 aspect ratio)
- No simulator management (runs natively)

### publish-to-appstore.yml Changes
- Add macOS app delivery
- Coordinate iOS/watchOS/macOS release
- Platform-specific deliver configurations

---

## Progress Tracking

| Phase | Status | Tasks Completed |
|-------|--------|-----------------|
| Phase 1: Project Setup | Completed | 5/5 |
| Phase 2: Core Data & Models | Completed | 3/3 |
| Phase 3: Services Layer | Completed | 7/7 |
| Phase 4: ViewModels | Completed | 5/5 |
| Phase 5: macOS Views | Completed | 11/11 |
| Phase 6: Advanced Features | Completed | 4/4 |
| Phase 7: Testing | Completed | 4/4 |
| Phase 8: Feature Parity | Completed | 4/4 |
| Phase 9: CI/CD | Completed | 7/7 |
| Phase 10: App Store Preparation | Completed | 5/5 |
| Phase 11: Polish & Launch | Completed | 9/9 |
| Phase 12: UX Polish & Best Practices | Not Started | 0/13 |
| Phase 13: App Store Submission | Not Started | 0/1 |
| Phase 14: Spotlight Integration | Optional | 0/1 |

**Total Tasks: 80** (64 completed, 16 remaining)

**Phase 11 Status** (Completed):
- Task 11.1: [COMPLETED] Keyboard Navigation
- Task 11.2: [COMPLETED] VoiceOver Support
- Task 11.3: [COMPLETED] Dark Mode Support
- Task 11.4: [COMPLETED] Performance Optimization
- Task 11.5: [COMPLETED] Memory Leak Testing
- Task 11.6: [COMPLETED] Final Integration Testing
- Task 11.7: [COMPLETED] iOS/macOS Feature Parity Implementation
- Task 11.8: [COMPLETED] Fix macOS CloudKit Sync Not Receiving iOS Changes
- Task 11.9: [COMPLETED] Test Isolation with Dependency Injection

**Phase 12 Status** (UX Polish - Agent Swarm Research):
- Task 12.1: 🔴 Implement Cmd+Click Multi-Select (CRITICAL)
- Task 12.2: 🔴 Fix Cmd+F Global Search Scope (CRITICAL)
- Task 12.3: 🔴 Improve Selection Mode Discoverability (CRITICAL)
- Task 12.4: 🔴 Redesign Filter UI to Native macOS Pattern (CRITICAL)
- Task 12.5: 🟠 Add Proactive Feature Tips (IMPORTANT)
- Task 12.6: 🟠 Add Sync Status Indicator in Toolbar (IMPORTANT)
- Task 12.7: 🟠 Consistent Empty State Components (IMPORTANT)
- Task 12.8: 🟠 Standardize Destructive Action Handling (IMPORTANT)
- Task 12.9: 🟠 Make Settings Window Resizable (IMPORTANT)
- Task 12.10: 🟡 Add Quick Entry Window (MINOR)
- Task 12.11: 🟡 Add Keyboard Reordering (MINOR)
- Task 12.12: 🟡 Add Clear All Filters Shortcut (MINOR)
- Task 12.13: 🟡 Add Image Gallery Size Presets (MINOR)

**Phase 13 Status**:
- Task 13.1: Submit to App Store

**Phase 14 Status** (Optional):
- Task 14.1: Implement Spotlight Integration

**Notes**:
- Phase 12 added based on agent swarm UX research (January 2026)
- Task 6.4 (Spotlight Integration) moved to Phase 14 as optional feature (disabled by default)
- Phase 9 revised based on swarm analysis: uses parallel jobs architecture (Task 9.0 added as blocking pre-requisite)
- Task 11.7 added comprehensive feature parity analysis with `/documentation/FEATURES.md`
