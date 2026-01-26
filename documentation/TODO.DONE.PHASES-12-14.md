# ListAll macOS App - Completed Phases 12-14 (UX Polish, Archived Lists & Visual Verification)

> **Navigation**: [Phases 1-4](./TODO.DONE.PHASES-1-4.md) | [Phases 5-7](./TODO.DONE.PHASES-5-7.md) | [Phases 8-11](./TODO.DONE.PHASES-8-11.md) | [Phases 15-16](./TODO.DONE.PHASES-15-16.md) | [Active Tasks](./TODO.md)

This document contains the completed UX Polish (Phase 12), Archived Lists Bug Fixes (Phase 13), and Visual Verification MCP Server (Phase 14) implementations with details preserved for LLM reference.

**Tags**: macOS, SwiftUI, UX, Apple HIG, Accessibility, Keyboard Shortcuts, archived lists, restore, read-only, selection state, bug fix, feature parity, MCP, visual verification, XCUITest, ScreenCaptureKit, Accessibility API

**Research basis**: Agent swarm analysis (January 2026) including Apple HIG review, industry best practices research (Things 3, Fantastical, Bear, OmniFocus), critical UX audit, and code analysis.

---

## Table of Contents

### Phase 12: UX Polish
1. [Phase 12 Overview](#phase-12-overview)
2. [Task 12.1: Cmd+Click Multi-Select](#task-121-cmdclick-multi-select-critical) (CRITICAL)
3. [Task 12.2: Cmd+F Global Search](#task-122-cmdf-global-search-critical) (CRITICAL)
4. [Task 12.3: Selection Mode Discoverability](#task-123-selection-mode-discoverability-critical) (CRITICAL)
5. [Task 12.4: Filter UI Redesign](#task-124-filter-ui-redesign-critical) (CRITICAL)
6. [Task 12.5: Proactive Feature Tips](#task-125-proactive-feature-tips-important) (IMPORTANT)
7. [Task 12.6: Sync Status Indicator](#task-126-sync-status-indicator-important) (IMPORTANT)
8. [Task 12.7: Consistent Empty States](#task-127-consistent-empty-states-important) (IMPORTANT)
9. [Task 12.8: Destructive Action Handling](#task-128-destructive-action-handling-important) (IMPORTANT)
10. [Task 12.9: Settings Window Resizable](#task-129-settings-window-resizable-important) (IMPORTANT)
11. [Task 12.10: Quick Entry Window](#task-1210-quick-entry-window-minor) (MINOR)
12. [Task 12.11: Keyboard Reordering](#task-1211-keyboard-reordering-minor) (MINOR)
13. [Task 12.12: Clear All Filters Shortcut](#task-1212-clear-all-filters-shortcut-minor) (MINOR)
14. [Task 12.13: Image Gallery Size Presets](#task-1213-image-gallery-size-presets-minor) (MINOR)

### Phase 13: Archived Lists Bug Fixes
15. [Phase 13 Overview](#phase-13-overview)
16. [Task 13.1: Add Restore Functionality](#task-131-add-restore-functionality-critical) (CRITICAL)
17. [Task 13.2: Make Archived Lists Read-Only](#task-132-make-archived-lists-read-only-critical) (CRITICAL)
18. [Task 13.3: Update Documentation Status](#task-133-update-documentation-status-important) (IMPORTANT)
19. [Task 13.4: Fix Selection Persistence Bug](#task-134-fix-selection-persistence-bug-critical) (CRITICAL)

### Phase 14: Visual Verification MCP Server
20. [Phase 14 Overview](#phase-14-overview)
21. [Task 14.0: Prototype Validation](#task-140-prototype-validation)
22. [Task 14.1: Simulator Screenshot & Launch](#task-141-simulator-screenshot--launch)
23. [Task 14.2: macOS Screenshot & Launch](#task-142-macos-screenshot--launch)
24. [Task 14.3: macOS Interaction Tools](#task-143-macos-interaction-tools)
25. [Task 14.4: Simulator Interaction Tools](#task-144-simulator-interaction-tools)
26. [Task 14.5: Diagnostics & Error Handling](#task-145-diagnostics--error-handling)
27. [Task 14.6: Integration & Documentation](#task-146-integration--documentation)
28. [Task 14.7: Visual Verification Skill](#task-147-visual-verification-skill)
29. [Task 14.8: Update CLAUDE.md](#task-148-update-claudemd)
30. [Task 14.9: Update Agent Definitions](#task-149-update-agent-definitions)

---

# Phase 12: UX Polish

## Phase 12 Overview

**Priority Levels**:
- CRITICAL: Platform convention violations that break user expectations
- IMPORTANT: Significant UX friction or inconsistencies
- MINOR: Polish items and power user conveniences

**Completion Date**: January 15, 2026
**Total Tasks**: 13/13 completed
**Total Tests Added**: ~200 tests

---

## Task 12.1: Cmd+Click Multi-Select (CRITICAL)

**Problem**: macOS users expect Cmd+Click to select multiple items without entering a special mode. Users had to click a toolbar button to enter "selection mode" first.

**Solution**:
1. **ListViewModel** - Added `lastSelectedItemID`, `selectRange(to:)`, `handleClick(for:commandKey:shiftKey:)`
2. **MacMainView** - Added `ModifierClickHandler` using NSEvent local monitoring (~170 lines)
3. Does NOT block drag-and-drop (returns event to continue processing)

**Files Modified**:
- `ListAll/ViewModels/ListViewModel.swift`
- `ListAllMac/Views/MacMainView.swift`
- `ListAllMacTests/TestHelpers.swift`

**Tests**: 16 tests in `CmdClickMultiSelectTests`

---

## Task 12.2: Cmd+F Global Search (CRITICAL)

**Problem**: Cmd+F only worked when focus was in detail pane. Feature Tips claimed "Press Cmd+F to search" but it failed from sidebar.

**Solution**:
1. **MacMainView** - Added global Cmd+F handler at NavigationSplitView level
2. Uses notification pattern to communicate with MacListDetailView
3. If no list selected, auto-selects first list

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift`

**Tests**: 14 tests in `CmdFGlobalSearchTests`

**Learning**: `/documentation/learnings/macos-global-cmdf-search.md`

---

## Task 12.3: Selection Mode Discoverability (CRITICAL)

**Problem**: Selection mode used "pencil" icon suggesting "edit" not "multi-select". No tooltips.

**Solution**:
1. Changed sidebar icon from "pencil" to "checklist"
2. Changed detail view icon from "checkmark.circle" to "checklist"
3. Added `.help()` tooltips to both buttons
4. Selection count already displayed as "\(count) selected"

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift`

**Tests**: 17 tests in `SelectionModeDiscoverabilityTests`

---

## Task 12.4: Filter UI Redesign (CRITICAL)

**Problem**: iOS-style popover pattern violated macOS conventions. None of 7 best-in-class macOS apps use popovers for primary filtering.

**Solution**:
1. **Segmented control** for filters (All/Active/Done) - always visible, single click
2. **View menu shortcuts** - Cmd+1/2/3 for filter options
3. **MacSortOnlyView** - Extracted sort-only popover for less-frequent options
4. Notification pattern for menu commands

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift`
- `ListAllMac/Commands/AppCommands.swift`
- `ListAllMac/Views/Components/MacSortOnlyView.swift` (NEW)

**Tests**: 21 tests in `FilterUIRedesignTests`

**Learning**: `/documentation/learnings/macos-filter-ui-redesign.md`

---

## Task 12.5: Proactive Feature Tips (IMPORTANT)

**Problem**: Tips only visible via Settings > General > View All Feature Tips. Never appeared proactively.

**Solution**:
1. **MacTooltipManager** - Added `currentTooltip`, `isShowingTooltip`, `showIfNeeded()`, `dismissCurrentTooltip()`
2. **MacTooltipNotificationView** - Toast-style notification in top-right corner
3. **Proactive triggers**:
   - 0.8s: Keyboard shortcuts tip for new users
   - 1.2s: Add list tip if no lists
   - 1.5s: Archive tip if 3+ lists
   - Item-related tips (search at 5+ items, sort/filter at 7+ items)

**Files Modified**:
- `ListAllMac/Utils/MacTooltipManager.swift`
- `ListAllMac/Views/MacMainView.swift`
- `ListAllMac/Views/Components/MacTooltipNotificationView.swift` (NEW)

**Tests**: 21 tests in `ProactiveFeatureTipsTests`

**Learning**: `/documentation/learnings/macos-proactive-feature-tips.md`

---

## Task 12.6: Sync Status Indicator (IMPORTANT)

**Problem**: Sync status hidden in tiny sidebar footer. No animation during sync, errors not prominent.

**Solution**:
1. **CloudKitService** - Added `static let shared` singleton
2. **Toolbar sync button** with:
   - `arrow.triangle.2.circlepath` icon
   - Rotating animation during sync (`.symbolEffect` on macOS 15+, `.rotationEffect` fallback)
   - Tooltip with last sync time or error
   - Red color when syncError present
   - Click triggers manual sync

**Files Modified**:
- `ListAll/Services/CloudKitService.swift`
- `ListAllMac/Views/MacMainView.swift`

**Tests**: 25 tests in `SyncStatusIndicatorTests`

---

## Task 12.7: Consistent Empty States (IMPORTANT)

**Problem**: Two different empty views existed - comprehensive `MacItemsEmptyStateView` and simple inline `emptyListView`.

**Solution**:
1. **MacSearchEmptyStateView** (NEW) - Search-specific empty state with tips
2. **emptyListView** - Now uses `MacItemsEmptyStateView`
3. **Three-way decision logic**:
   - `items.isEmpty` -> `MacItemsEmptyStateView`
   - `!searchText.isEmpty` -> `MacSearchEmptyStateView`
   - Filter removed all -> `noMatchingItemsView`

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift`
- `ListAllMac/Views/Components/MacEmptyStateView.swift`

**Tests**: 17 tests in `ConsistentEmptyStateTests`

**Learning**: `/documentation/learnings/macos-consistent-empty-states.md`

---

## Task 12.8: Destructive Action Handling (IMPORTANT)

**Problem**: Inconsistent delete behavior - bulk delete showed confirmation dialog, individual delete used undo banner.

**Solution**:
1. **ListViewModel** - Added `recentlyDeletedItems`, `showBulkDeleteUndoBanner`, `deleteSelectedItemsWithUndo()`, `undoBulkDelete()`
2. **MacBulkDeleteUndoBanner** - Red trash icon, item count, Undo/Dismiss buttons
3. Removed confirmation dialog for bulk delete
4. All deletes now use 10-second undo window (macOS convention)

**Files Modified**:
- `ListAll/ViewModels/ListViewModel.swift`
- `ListAllMac/Views/MacMainView.swift`

**Tests**: 14 tests in `DestructiveActionHandlingTests`

**Learning**: `/documentation/learnings/macos-bulk-delete-undo-standardization.md`

---

## Task 12.9: Settings Window Resizable (IMPORTANT)

**Problem**: Fixed 500x350 size. Content clipped with large text or long localized strings.

**Solution**:
Changed `.frame(width: 500, height: 350)` to `.frame(minWidth: 500, idealWidth: 550, minHeight: 350, idealHeight: 400)`

**Files Modified**:
- `ListAllMac/Views/MacSettingsView.swift` (Line 58)

**Tests**: 17 tests in `SettingsWindowResizableTests`

**Learning**: `/documentation/learnings/macos-settings-window-resizable.md`

---

## Task 12.10: Quick Entry Window (MINOR)

**Problem**: No way to quickly add items without switching to app. Power users expect Things 3-style Quick Entry.

**Solution**:
1. **QuickEntryView.swift** (NEW):
   - QuickEntryViewModel with itemTitle, selectedListId, validation
   - Minimal floating window design
   - Enter to save, Escape to dismiss
   - Visual effect background (frosted glass)
2. **Window scene** with `.windowStyle(.hiddenTitleBar)`, `.defaultPosition(.center)`
3. **Menu command** - Cmd+Option+Space

**Files Created**:
- `ListAllMac/Views/QuickEntryView.swift`

**Files Modified**:
- `ListAllMac/ListAllMacApp.swift`
- `ListAllMac/Commands/AppCommands.swift`

**Tests**: 30 tests in `QuickEntryWindowTests`

**Learning**: `/documentation/learnings/macos-quick-entry-window.md`

---

## Task 12.11: Keyboard Reordering (MINOR)

**Problem**: Items only reorderable via drag-and-drop. Accessibility issue for motor disabilities.

**Solution**:
1. **ListViewModel** - Added `canReorderWithKeyboard`, `moveItemUp()`, `moveItemDown()`
2. **MacMainView** - Cmd+Option+Up/Down handlers
3. Only works when sorted by orderNumber

**Files Modified**:
- `ListAll/ViewModels/ListViewModel.swift`
- `ListAllMac/Views/MacMainView.swift`
- `ListAllMacTests/TestHelpers.swift`

**Tests**: 16 tests in `KeyboardReorderingTests`

**Learning**: SwiftUI `.onKeyPress` with arrow keys requires checking modifiers inside closure using `keyPress.modifiers.contains()`.

---

## Task 12.12: Clear All Filters Shortcut (MINOR)

**Problem**: Filter badges only clearable by clicking X on each. No keyboard shortcut.

**Solution**: Cmd+Shift+Backspace clears all filters (search text, filter option, sort to default).

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift`

---

## Task 12.13: Image Gallery Size Presets (MINOR)

**Problem**: Thumbnail slider (80-200px) had no presets. Users had to drag to find size.

**Solution**:
1. **ThumbnailSizePreset enum** - `small = 80`, `medium = 120`, `large = 160` with labels "S", "M", "L"
2. **Preset buttons** in toolbar with active state highlighting
3. **@AppStorage** persistence for thumbnail size

**Files Modified**:
- `ListAllMac/Views/Components/MacImageGalleryView.swift`

**Tests**: 22 tests in `ImageGallerySizePresetsTests`

**Learning**: `/documentation/learnings/macos-image-gallery-size-presets.md`

---

# Phase 13: Archived Lists Bug Fixes

## Phase 13 Overview

**Priority Levels**:
- CRITICAL: Feature parity violations that break user expectations
- IMPORTANT: Documentation accuracy

**Issue Discovery**: Agent swarm investigation (January 2026) revealed:
1. macOS had NO "Restore" option for archived lists (iOS has it)
2. macOS allowed full editing of archived lists (iOS is read-only)
3. Selection state persisted incorrectly when switching between Active/Archived views

**Completion Date**: January 20, 2026
**Total Tasks**: 4/4 completed
**Total Tests Added**: ~28 tests

---

## Task 13.1: Add Restore Functionality (CRITICAL)

**Problem**: macOS had no UI to restore archived lists. iOS has restore buttons in `ListRowView` (inline) and `ArchivedListView` (toolbar). Backend `restoreList(withId:)` existed but macOS UI didn't expose it.

**Solution**:
1. Added `showingRestoreConfirmation` and `listToRestore` state variables to MacSidebarView
2. Updated context menu in `normalModeRow()` to show different options based on `showingArchivedLists`:
   - Archived: "Restore" (arrow.uturn.backward icon) and "Delete Permanently" (destructive)
   - Active: "Share..." and "Delete" (existing behavior)
3. Added keyboard shortcut Cmd+Shift+R in AppCommands.swift
4. Added notification handler for "RestoreSelectedList" in MacSidebarView
5. Added restore confirmation alert following iOS pattern (includes list name in message)

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift` - Added restore state, context menu, alert, notification handler
- `ListAllMac/Commands/AppCommands.swift` - Added Cmd+Shift+R shortcut

**Tests**: 4 tests in `ArchivedListsTests`
- testRestoreConfirmationStateManagement
- testRestoreContextMenuAvailability
- testMainViewModelRestoreList
- testRestoreConfirmationMessageIncludesListName

**Learning**: `/documentation/learnings/macos-restore-archived-lists.md`

---

## Task 13.2: Make Archived Lists Read-Only (CRITICAL)

**Problem**: macOS allowed full editing of archived lists (add items, edit items, edit list name, reorder). iOS uses dedicated `ArchivedListView` that is completely read-only. This defeated the purpose of archiving (preserving list state).

**Solution**:
1. Added `isCurrentListArchived` computed property to MacListDetailView
2. Conditionally hidden editing controls in header (Edit List, Selection Mode)
3. Hidden Add Item button in toolbar for archived lists
4. Updated MacItemRowView with `isArchivedList` parameter:
   - Read-only completion indicator (no button)
   - Hidden edit/delete hover buttons
   - Only Quick Look button visible (if images exist)
   - Read-only context menu (only Quick Look)
   - Disabled double-click editing
5. Disabled drag-to-reorder via `ConditionalDraggable` modifier
6. Disabled keyboard shortcuts: Space (toggle), Enter (edit), Delete, Cmd+Opt+Up/Down (reorder)
7. Added visual "Archived" badge in header
8. Blocked CreateNewItem notification for archived lists
9. Disabled Cmd+Click/Shift+Click multi-select for archived lists

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift`

**Tests**: 19 tests in `ReadOnlyArchivedListsTests`
- testIsCurrentListArchivedReturnsTrue
- testIsCurrentListArchivedReturnsFalse
- testAddItemButtonHiddenForArchivedList
- testEditListButtonHiddenForArchivedList
- testSelectionModeButtonHiddenForArchivedList
- testItemRowReadOnlyForArchivedList
- testItemEditButtonHiddenForArchivedList
- testItemDeleteButtonHiddenForArchivedList
- testQuickLookButtonVisibleForArchivedList
- testDragReorderDisabledForArchivedList
- testContextMenuReadOnlyForArchivedList
- testSpaceKeyBehaviorForArchivedList
- testEnterKeyBehaviorForArchivedList
- testDeleteKeyBehaviorForArchivedList
- testKeyboardReorderingDisabledForArchivedList
- testShareButtonVisibleForArchivedList
- testFilterSortVisibleForArchivedList
- testArchivedBadgeDisplayed
- testArchivedListItemsNotModifiableViaUI

**Learning**: `/documentation/learnings/macos-archived-lists-read-only.md`

---

## Task 13.3: Update Documentation Status (IMPORTANT)

**Problem**: `LIST_MANAGEMENT.md` claimed full feature parity for "Restore Archived List" on macOS. `SUMMARY.md` claimed "No gaps". This was inaccurate until Tasks 13.1 and 13.2 were completed.

**Solution**:
1. Verified all functionality works after completing Tasks 13.1 and 13.2
2. Ran full test suite to confirm no regressions
3. Updated `documentation/features/LIST_MANAGEMENT.md`
4. Updated `documentation/features/SUMMARY.md`
5. Wrote learning document about archive/restore parity

**Files Modified**:
- `documentation/features/LIST_MANAGEMENT.md`
- `documentation/features/SUMMARY.md`

**Learning**: `/documentation/learnings/macos-archive-restore-feature-parity.md`

---

## Task 13.4: Fix Selection Persistence Bug (CRITICAL)

**Problem**: When user selected an archived list in "Archived Lists" view, then switched to "Active Lists" view, `selectedList` state retained the archived list. Detail view incorrectly showed archived list UI (Restore button, read-only mode) for active lists.

**Root Cause** (discovered by agent swarm investigation):
- `List` is a VALUE TYPE (struct) - when passed to MacListDetailView, it's copied
- Even after `restoreList()` updates Core Data, the view's `list` parameter retains old values
- `isCurrentListArchived` was checking `list.isArchived` (stale copy) instead of fresh data
- Multiple code paths could leave stale archived list in selection state

**Solution** (THREE fixes required):
1. **Tab switch clearing** - Added `selectedList = nil`, `selectedLists.removeAll()`, and `isInSelectionMode = false` to `.onChange(of: showingArchivedLists)` handlers in both MacMainView and MacSidebarView
2. **Restore handler clearing** - Added `selectedList = nil` in MacSidebarView's restore confirmation handler. After restore, the list moves to active lists but the stale struct copy retained `isArchived = true`
3. **Fix `isCurrentListArchived` to use fresh data** - Changed from checking stale `list.isArchived` to checking `currentList?.isArchived` (fresh data from dataManager)

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift` - Tab switch selection clearing, multi-select clearing, restore handler, `isCurrentListArchived` fix
- `ListAllMacTests/ReadOnlyArchivedListsTests.swift` - Added TabSwitchSelectionTests suite
- `ListAllMacTests/RestoreArchivedListsTests.swift` - Added `@MainActor` for Core Data threading

**Tests**: 5 tests in `TabSwitchSelectionTests`
- testSwitchFromArchivedToActiveViewClearsSelection
- testSwitchFromActiveToArchivedViewClearsSelection
- testSelectedListMustBelongToDisplayedLists
- testActiveListDetailViewNoRestoreButton
- testActiveListAllowsAddingItems

**Learning**: `/documentation/learnings/macos-tab-switch-selection-persistence.md`, `/documentation/learnings/swift-testing-coredata-mainactor.md`

---

# Phase 14: Visual Verification MCP Server

## Phase 14 Overview

**Goal**: Build an MCP server enabling Claude to visually verify its own work across all ListAll platforms (macOS, iOS, iPadOS, watchOS) without requiring manual user verification. This provides a feedback loop to 2-3x the quality of UI work.

**Completion Date**: January 2026
**Total Tasks**: 10/10 completed

**Architecture**:
```
Claude Code <--> stdio <--> listall-mcp (Swift)
                                |
              +-----------------+-----------------+
              v                 v                 v
          macOS App         iOS Sim           Watch Sim
        (Accessibility)    (XCUITest)        (XCUITest)
```

**Platform Support**:
| Platform | Launch | Screenshot | Interaction | Permissions |
|----------|--------|------------|-------------|-------------|
| macOS | `open -a` | ScreenCaptureKit | Accessibility API | Screen Recording + Accessibility |
| iOS Sim | `simctl launch` | `simctl io screenshot` | XCUITest | **NONE** |
| iPad Sim | `simctl launch` | `simctl io screenshot` | XCUITest | **NONE** |
| Watch Sim | `simctl launch` | `simctl io screenshot` | XCUITest | **NONE** |

**Performance**:
| Operation | macOS | Simulators |
|-----------|-------|------------|
| Screenshot | ~500ms | ~1s |
| Click | ~100ms | ~5-10s |
| Type | ~200ms | ~5-10s |
| Swipe | ~300ms | ~5-10s |
| Query | ~200ms | ~5-10s |

---

## Task 14.0: Prototype Validation

**Goal**: Validate MCP server + stdio transport work with Claude

**Solution**:
1. Created minimal Swift package with single "echo" tool
2. Configured in `.mcp.json` (project-local config)
3. Verified Claude can call the tool and receive response
4. Validated: snake_case naming, stderr logging, base64 image return

**Files Created**:
- `Tools/listall-mcp/Package.swift`
- `Tools/listall-mcp/Sources/listall-mcp/main.swift`

**Dependencies**: `modelcontextprotocol/swift-sdk` (0.10.2+)

---

## Task 14.1: Simulator Screenshot & Launch

**Goal**: Claude can launch and screenshot iOS/iPad/Watch apps

**Solution**:
1. `listall_list_simulators` - Wraps `simctl list devices -j`, returns structured JSON with device info
2. `listall_boot_simulator` - Wraps `simctl boot`
3. `listall_shutdown_simulator` - Wraps `simctl shutdown`, supports "all" to shutdown all simulators
4. `listall_launch` - Installs app bundle (simctl install) + launches with arguments
5. `listall_screenshot` - Captures via `simctl io screenshot`, returns base64 PNG

**Files Created**:
- `Tools/listall-mcp/Sources/listall-mcp/Tools/SimulatorTools.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Tools/ScreenshotTool.swift`

---

## Task 14.2: macOS Screenshot & Launch

**Goal**: Claude can launch and screenshot macOS app

**Solution**:
1. `listall_launch_macos` - Uses `open -a` with launch arguments
2. `listall_screenshot_macos` - Uses ScreenCaptureKit to capture specific window
3. `listall_quit_macos` - Graceful quit via AppleScript
4. `listall_hide_macos` - Hide app window without quitting
5. Permission check with clear error messages

**Permissions** (one-time manual grant):
- Screen Recording: System Settings > Privacy & Security > Screen Recording

**Files Created**:
- `Tools/listall-mcp/Sources/listall-mcp/Tools/MacOSTools.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Permissions.swift`

---

## Task 14.3: macOS Interaction Tools

**Goal**: Claude can interact with macOS app via Accessibility API

**Solution**:
1. `listall_click` - Uses AXUIElement performAction for click
2. `listall_type` - Uses AXUIElement setValue for text input
3. `listall_swipe` - Uses scroll events for scrolling
4. `listall_query` - Lists elements by accessibility ID/label with hierarchy

**Permissions** (one-time manual grant):
- Accessibility: System Settings > Privacy & Security > Accessibility

**Files Created**:
- `Tools/listall-mcp/Sources/listall-mcp/Services/AccessibilityService.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Tools/InteractionTools.swift`

---

## Task 14.4: Simulator Interaction Tools

**Goal**: Claude can interact with simulator apps via XCUITest bridge

**Architecture**:
1. MCP server writes command to synchronized file group
2. MCP server invokes `xcodebuild test-without-building` for specific test
3. XCUITest reads command, executes, writes result
4. MCP server reads result and returns to Claude

**Solution**:
1. Added `MCPCommandRunner.swift` to existing `ListAllUITests` target
2. Implemented file-based command/response protocol
3. Supports click, type, swipe, query actions
4. Pre-built test target for faster execution (~5-15s per interaction)

**Files Created**:
- `ListAllUITests/MCPCommandRunner.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift`

**Files Modified**:
- `Tools/listall-mcp/Sources/listall-mcp/Tools/InteractionTools.swift` (added simulator support)

---

## Task 14.5: Diagnostics & Error Handling

**Goal**: Clear diagnostics and actionable error messages

**Solution**:
`listall_diagnostics` tool checks:
1. Accessibility permission status
2. Screen Recording permission status
3. Available simulators (iOS, iPadOS, watchOS)
4. Booted simulators
5. Built app bundles exist
6. XCUITest runner build status
7. Xcode and developer tools availability

Returns actionable guidance for any issues found.

**Files Created**:
- `Tools/listall-mcp/Sources/listall-mcp/Tools/DiagnosticsTool.swift`

---

## Task 14.6: Integration & Documentation

**Goal**: Complete integration and setup guide

**Solution**:
1. Project-local configuration in `.mcp.json`
2. Build release binary: `swift build -c release`
3. Pre-build XCUITest target: `xcodebuild build-for-testing`
4. Comprehensive setup and usage documentation

**Configuration** (`.mcp.json`):
```json
{
  "mcpServers": {
    "listall": {
      "command": "/path/to/listall-mcp/.build/release/listall-mcp"
    }
  }
}
```

**Files Created**:
- `documentation/guides/MCP_VISUAL_VERIFICATION.md`
- `.mcp.json` (project root)

---

## Task 14.7: Visual Verification Skill

**Goal**: Create skill that teaches Claude when/how to use visual verification

**Solution**: Created comprehensive skill defining:
- When to verify (after UI changes, when debugging)
- Verification workflow (launch → screenshot → analyze → iterate)
- Platform coverage requirements
- Screenshot-only vs interactive verification patterns
- Error handling and troubleshooting

**Files Created**:
- `.claude/skills/visual-verification/SKILL.md`

---

## Task 14.8: Update CLAUDE.md

**Goal**: Add mandatory visual verification rule to project instructions

**Solution**: Added "Implementation Visual Verification" section with:
- MCP tools connection blocking rule
- Required platform coverage table
- Verification workflow (screenshot-only default, interactive optional)
- Launch and cleanup commands
- Reference to skill for detailed patterns

**Files Modified**:
- `CLAUDE.md`

---

## Task 14.9: Update Agent Definitions

**Goal**: Add visual-verification skill to relevant agents

**Solution**: Added `visual-verification` skill to:
- `apple-dev-expert.md` - Implements UI features
- `testing-specialist.md` - Verifies implementations

**Files Modified**:
- `.claude/agents/apple-dev-expert.md`
- `.claude/agents/testing-specialist.md`

---

## MCP Tools Reference

| Tool | Description | macOS | Simulators |
|------|-------------|-------|------------|
| `listall_screenshot` | Capture current state | ScreenCaptureKit | simctl io |
| `listall_launch` | Launch app in simulator | N/A | simctl install + launch |
| `listall_launch_macos` | Launch macOS app | open -a | N/A |
| `listall_screenshot_macos` | Capture macOS window | ScreenCaptureKit | N/A |
| `listall_quit_macos` | Quit macOS app | AppleScript | N/A |
| `listall_hide_macos` | Hide macOS app | AppleScript | N/A |
| `listall_click` | Tap element by ID | AXUIElement | XCUITest |
| `listall_type` | Enter text | AXUIElement | XCUITest |
| `listall_swipe` | Swipe gesture | AXUIElement | XCUITest |
| `listall_query` | List UI elements | AXUIElement | XCUITest |
| `listall_list_simulators` | List devices | N/A | simctl list |
| `listall_boot_simulator` | Boot simulator | N/A | simctl boot |
| `listall_shutdown_simulator` | Shutdown simulator | N/A | simctl shutdown |
| `listall_diagnostics` | Check setup | permissions | simulators |

---

## Research Documents

Phase 12 was based on comprehensive agent swarm research:

1. **Apple HIG Research** - macOS navigation, toolbar design, menu structure, anti-patterns
2. **Industry Best Practices** - Liquid Glass design, Quick Entry patterns, accessibility
3. **Code Analysis** - Current implementation audit, context menu analysis
4. **Critical UX Review** - 3 CRITICAL, 5 IMPORTANT, 4 MINOR issues identified

**Master learnings file**: `/documentation/learnings/macos-ux-best-practices-research-2025.md`

---

> **Navigation**: [Phases 1-4](./TODO.DONE.PHASES-1-4.md) | [Phases 5-7](./TODO.DONE.PHASES-5-7.md) | [Phases 8-11](./TODO.DONE.PHASES-8-11.md) | [Phases 15-16](./TODO.DONE.PHASES-15-16.md) | [Active Tasks](./TODO.md)
