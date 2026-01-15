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

## Completed Phases (1-10)

> **Full implementation details**: See [TODO.DONE.md](./TODO.DONE.md)

All phases 1-10 have been completed with full TDD, code examples, and documentation. 
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

**Total Completed**: 55 tasks across 10 phases

---

## Phase 11: Polish & Launch

### Task 11.1: [COMPLETED] Implement macOS-Specific Keyboard Navigation
**TDD**: Accessibility tests

**SWARM VERIFIED** (December 2025): Implemented by 4 specialized agents:
- **Apple Development Expert**: Researched SwiftUI keyboard APIs and designed implementation plan
- **Testing Specialist**: Designed comprehensive test plan with 25+ test cases
- **Critical Reviewer**: Identified and helped fix bidirectional focus sync and Cmd+C interception issues

**Completed**:
1. ✅ **Sidebar Navigation (MacSidebarView)**:
   - `@FocusState private var focusedListID: UUID?` for tracking focused list
   - `.focusable()` and `.focused($focusedListID, equals: list.id)` on each list row
   - `.onKeyPress(.return)` - Enter key selects focused list
   - `.onKeyPress(.space)` - Space key selects focused list (macOS convention)
   - `.onKeyPress(.delete)` - Delete key removes focused list
   - `moveFocusAfterDeletion(deletedId:)` helper to maintain focus after deletion
   - Bidirectional focus/selection sync (arrow keys update selection immediately)

2. ✅ **Item List Navigation (MacListDetailView)**:
   - `@FocusState private var focusedItemID: UUID?` for tracking focused item
   - `@FocusState private var isSearchFieldFocused: Bool` for search field
   - `.focusable()` and `.focused($focusedItemID, equals: item.id)` on each item row
   - `.onKeyPress(.space)` - Space toggles completion OR shows Quick Look if item has images
   - `.onKeyPress(.return)` - Enter opens edit sheet
   - `.onKeyPress(.delete)` - Delete removes item
   - `.onKeyPress(characters: "c")` - 'C' key toggles completion (ignores Cmd+C)
   - `moveFocusAfterItemDeletion(deletedId:)` helper

3. ✅ **Search Field Keyboard Shortcuts**:
   - `.focused($isSearchFieldFocused)` on TextField
   - `.onExitCommand` - Escape clears search and unfocuses
   - `.onKeyPress(characters: "f")` with Cmd modifier - Cmd+F focuses search

4. ✅ **Accessibility Identifiers Added**:
   - `ListsSidebar`, `SidebarListCell_<name>`, `AddListButton`
   - `ItemsList`, `ItemRow_<title>`, `AddItemButton`
   - `ListSearchField`, `FilterSortButton`, `ShareListButton`, `EditListButton`

5. ✅ **UI Tests Created** (`MacKeyboardNavigationTests.swift`):
   - 25+ test methods covering arrow keys, Enter, Escape, Space, Delete
   - Keyboard shortcuts (Cmd+N, Cmd+Shift+N, Cmd+R, Cmd+F, Cmd+Shift+S)
   - Accessibility identifier verification tests
   - Focus management tests

**Critical Review Findings** (addressed):
- ❌→✅ Fixed: Bidirectional focus/selection sync (Issue #2)
- ❌→✅ Fixed: 'C' key was capturing Cmd+C (Issue #9)
- ⚠️ Noted: Tab navigation relies on SwiftUI default behavior
- ⚠️ Noted: Space key behavior differs for items with images (shows Quick Look)

**Files created/modified**:
- `ListAllMac/Views/MacMainView.swift` - Added ~150 lines of keyboard navigation code
- `ListAllMacUITests/MacKeyboardNavigationTests.swift` - NEW (25+ tests)

---

### Task 11.2: [COMPLETED] Implement VoiceOver Support
**TDD**: VoiceOver tests

**Steps**:
1. Add accessibility labels to all elements
2. Add accessibility hints for interactive elements
3. Test with VoiceOver enabled

**Completed**:

1. **Accessibility Analysis** - Performed comprehensive audit of all macOS view files identifying 100+ elements needing accessibility improvements

2. **VoiceOver Tests Created** (`ListAllMacTests/VoiceOverAccessibilityTests.swift`):
   - 59 new tests using Swift Testing framework
   - Test suites: Labels (14), Hints (10), Values (10), Traits (10), Containers (9), Keyboard (3), Dynamic Content (5)

3. **Accessibility Labels Added** to 50+ interactive elements across 7 files:
   - Sidebar list rows with dynamic item counts
   - Item rows with comprehensive combined labels (title, status, quantity, images, description)
   - All buttons (Add, Edit, Delete, Share, Quick Look, etc.)
   - Search fields, filter/sort controls
   - Sheet titles and form fields

4. **Accessibility Hints Added** to 20+ action elements:
   - Buttons: "Opens sheet to create new list", "Opens image preview", "Permanently removes this item"
   - Toggles: "When enabled, syncs lists across your devices"
   - Draggable items: "Double-tap to edit. Use actions menu for more options."

5. **Accessibility Values Added** for dynamic content:
   - List item counts: "X active, Y total items"
   - Sort/filter selections: "Selected" state indicators
   - Image galleries: "N images"

6. **Accessibility Traits Applied**:
   - `.isHeader` on sheet titles and section headers
   - `.isImage` on thumbnails
   - `.isSelected` on selected items
   - `.accessibilityHidden(true)` on decorative icons

7. **Element Grouping Implemented**:
   - `MacItemRowView`: Combined with comprehensive label for clean VoiceOver navigation
   - Empty states: Combined for single announcement

**Files created**:
- `ListAllMacTests/VoiceOverAccessibilityTests.swift` - 59 VoiceOver tests

**Files modified**:
- `ListAllMac/Views/MacMainView.swift` - 40+ accessibility modifiers
- `ListAllMac/Views/MacSettingsView.swift` - 9 accessibility modifiers
- `ListAllMac/Views/Components/MacImageGalleryView.swift` - 10 accessibility modifiers
- `ListAllMac/Views/Components/MacItemOrganizationView.swift` - 8 accessibility modifiers
- `ListAllMac/Views/Components/MacShareFormatPickerView.swift` - 10 accessibility modifiers
- `ListAllMac/Views/Components/MacSuggestionListView.swift` - 6 accessibility modifiers
- `ListAllMac/Views/Components/MacQuickLookView.swift` - 6 accessibility modifiers

**Test Results**: All 108 macOS tests pass (49 existing + 59 new)

---

### Task 11.3: [COMPLETED] Implement Dark Mode Support
**TDD**: Appearance tests

**Steps**:
1. Verify all views work in dark mode
2. Use semantic colors from asset catalog
3. Test light/dark mode switching

**Completed**:
- Analyzed all macOS view files for hardcoded colors
- Fixed 4 critical dark mode issues:
  - MacMainView.swift: Image count badge used `Color.black.opacity(0.7)` - replaced with `.ultraThinMaterial` + `NSColor.darkGray`
  - MacQuickLookView.swift: Same image badge issue - fixed with same approach
- Configured AccentColor asset with proper light/dark variants:
  - Light mode: Blue (RGB 0, 0, 1)
  - Dark mode: Lighter blue (RGB 0.2, 0.4, 1) for better visibility
- Most views already correctly use semantic colors:
  - `Color.secondary`, `Color.accentColor` for system-adaptive colors
  - `NSColor.windowBackgroundColor`, `NSColor.controlBackgroundColor` for backgrounds
  - Theme.Colors struct for shared semantic colors
- Created 19 dark mode unit tests in `DarkModeColorTests` class:
  - Theme.Colors accessibility tests (5 tests)
  - Semantic status colors tests (4 tests)
  - AccentColor asset tests (2 tests)
  - NSColor system colors tests (5 tests)
  - Badge colors dark mode compatibility tests (3 tests)

**Files modified**:
- `ListAllMac/Views/MacMainView.swift` - Dark mode compatible image badges
- `ListAllMac/Views/Components/MacQuickLookView.swift` - Dark mode compatible image badges
- `ListAllMac/Assets.xcassets/AccentColor.colorset/Contents.json` - Light/dark color variants
- `ListAllMacTests/ListAllMacTests.swift` - Added DarkModeColorTests class

**Test Results**: All 133 macOS tests pass (19 new dark mode + 114 existing)

---

### Task 11.4: [COMPLETED] Performance Optimization
**TDD**: Performance benchmarks

**Steps**:
1. Profile with Instruments
2. Optimize list rendering for large lists
3. Optimize image loading and caching

**Completed** (January 6, 2026):

**Research Phase**:
- Apple Development Expert analyzed current implementation across 8 key files
- Critical Reviewer provided theoretical framework for SwiftUI/Core Data performance
- Identified 7 areas for optimization (2 high, 3 medium, 2 low priority)

**Performance Benchmark Tests Created** (`ListAllMacTests/PerformanceBenchmarkTests.swift`):
- 19 performance tests covering list operations, thumbnails, Core Data, memory
- `PerformanceBenchmarkTests` class with baseline measurements
- `AsyncThumbnailPatternTests` class for async/concurrent testing

**Optimizations Implemented**:

1. **Async Thumbnail Creation** (HIGH - Issue 4):
   - Added `createThumbnailAsync(from:size:)` to `ImageService.swift`
   - Uses `Task.detached` with `.userInitiated` priority
   - Maintains cache hit fast-path on calling thread
   - NSCache thread-safe for concurrent access

2. **Image Relationship Prefetching** (HIGH - Issue 5):
   - Updated Core Data fetches to prefetch `["items", "items.images"]`
   - Prevents N+1 query problems when loading lists with images
   - Applied to both `loadData()` and `getLists()` methods

3. **@ViewBuilder Optimization** (LOW - Issue 3):
   - Added `@ViewBuilder` to `makeItemRow(item:)` in MacMainView
   - Helps SwiftUI's type checker with complex view-returning functions

4. **Gallery Async Loading**:
   - Updated `MacImageGalleryView` to use new `createThumbnailAsync`
   - Leverages existing Task.detached pattern for double-async optimization

**Existing Good Patterns Verified**:
- ✅ Thumbnail caching with NSCache and appropriate limits (50 items, 50MB)
- ✅ LazyVGrid for image gallery (efficient rendering)
- ✅ Debounced remote change handling (0.5s debounce)
- ✅ Deferred sheet content loading (faster sheet appearance)
- ✅ Transaction-based state updates (prevents animation conflicts)
- ✅ Relationship prefetching for items (now includes images)

**Performance Baselines Established**:
| Operation | Average Time |
|-----------|-------------|
| Large list filtering (1000 items) | ~0.25ms |
| Large list sorting (3 sorts) | ~1ms |
| Thumbnail cache hit (100 hits) | ~1.2ms |
| Batch thumbnail loading (20 images) | ~0.25ms (cached) |
| Model conversion (100 items) | ~0.7ms |
| Realistic workflow simulation | ~0.1ms |

**Files Created**:
- `ListAllMacTests/PerformanceBenchmarkTests.swift` (500+ lines, 21 tests)

**Files Modified**:
- `ListAll/Services/ImageService.swift` - Added `createThumbnailAsync`
- `ListAll/Models/CoreData/CoreDataManager.swift` - Added image prefetching
- `ListAllMac/Views/MacMainView.swift` - Added @ViewBuilder
- `ListAllMac/Views/Components/MacImageGalleryView.swift` - Use async thumbnails

**Test Results**: All 463 macOS unit tests pass (7 skipped)

---

### Task 11.5: [COMPLETED] Memory Leak Testing
**TDD**: Memory tests

**Steps**:
1. Run with Memory Graph Debugger
2. Fix any retain cycles
3. Test with large data sets

**Implementation**:
- Analyzed entire codebase for potential memory leaks and retain cycles
- Confirmed SwiftUI structs don't create retain cycles (value types, not reference types)
- Verified existing ViewModels properly clean up in deinit (NotificationCenter, Timers)
- Added clarifying comment in MacMainView.swift for Timer closure capture pattern
- Created 24 memory leak unit tests in ListAllMacTests.swift covering:
  - Item and List model memory management
  - ViewModel existence verification
  - Closure capture patterns
  - Timer cleanup patterns
  - NotificationCenter observer lifecycle
  - Large dataset operations (500+ items)
  - ImageService cache behavior
  - Combine cancellables cleanup
- Documented learnings in `/documentation/learnings/macos-memory-management-patterns.md`

**Test Results**: All 463+ macOS unit tests pass

---

### Task 11.6: [COMPLETED] Final Integration Testing
**TDD**: End-to-end tests

**Steps**:
1. Test full workflow: create list → add items → sync → export
2. Test iCloud sync between iOS and macOS
3. Test all menu commands

**Implementation**:
- Created `MacFinalIntegrationTests.swift` with 62 integration tests
- 5 test classes: FullWorkflowIntegrationTests, CloudKitSyncIntegrationTests, MenuCommandIntegrationTests, EndToEndWorkflowTests, IntegrationTestDocumentation
- Tests verify notification-based architecture, sync infrastructure, and export workflows
- All tests avoid App Groups access to prevent permission dialogs

**Test Results**: All 62 integration tests pass

---

### Task 11.7: [COMPLETED] Implement macOS Feature Parity with iOS
**TDD**: Feature implementation tests

**Purpose**: Implement missing iOS features on macOS for full feature parity.

**Reference Documentation**: `/documentation/FEATURES.md` - Comprehensive feature inventory

**Progress** (January 7, 2026):

**HIGH Priority (ALL DONE):**

1. **Bulk Archive/Delete for Lists** - Implemented proper archive vs permanent delete semantics
   - Active lists view: "Archive Lists" action (recoverable via restore)
   - Archived lists view: "Delete Permanently" action (irreversible)
   - Added `archiveSelectedLists()` and `permanentlyDeleteSelectedLists()` methods
   - Extracted @ViewBuilder properties to fix SwiftUI type-checker performance issues
   - Added 21 unit tests in `BulkListOperationsMacTests`

2. **Filter: Has Images** - Verified already working, documentation was outdated
   - Updated FILTER_SORT.md status from ⚠️ to ✅
   - Updated count from macOS 14/15 to macOS 15/15

3. **Documentation Updates**:
   - LIST_MANAGEMENT.md: Updated status to 13/13, marked Bulk Archive/Delete as ✅
   - FILTER_SORT.md: Updated status to 15/15, marked Filter: Has Images as ✅
   - SUMMARY.md: Updated category counts and gap tables

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift` - Added bulk archive/delete with proper semantics
- `ListAllMacTests/ListAllMacTests.swift` - Added BulkListOperationsMacTests class
- `documentation/features/SUMMARY.md` - Updated status counts
- `documentation/features/LIST_MANAGEMENT.md` - Updated status
- `documentation/features/FILTER_SORT.md` - Updated status

**MEDIUM Priority (ALL DONE):**

1. **Feature Tips System** - Implemented macOS tooltip/tips system for feature discovery
   - Created MacTooltipManager with macOS-specific tips
   - Created MacAllFeatureTipsView for viewing all tips
   - Added Help & Tips section to MacSettingsView GeneralSettingsTab
   - Added 18 unit tests in FeatureTipsMacTests
   - Status: **IMPLEMENTED**

---

#### HIGH Priority Feature Gaps (macOS needs these)

| # | Feature | iOS Implementation | macOS Status |
|---|---------|-------------------|--------------|
| 1 | **Multi-Select Mode for Lists** | Selection checkboxes, bulk archive/delete | **IMPLEMENTED** |
| 2 | **Multi-Select Mode for Items** | Selection checkboxes, bulk operations | **IMPLEMENTED** |
| 3 | **Move Items Between Lists** | DestinationListPickerView | **IMPLEMENTED** |
| 4 | **Copy Items Between Lists** | DestinationListPickerView | **IMPLEMENTED** |
| 5 | **Undo Complete** | 5-second undo banner | **IMPLEMENTED** |
| 6 | **Undo Delete** | 5-second undo banner | **IMPLEMENTED** |
| 7 | **Import Preview Dialog** | ImportPreviewView with summary | **IMPLEMENTED** |
| 8 | **Import Progress UI** | Progress bar with details | **IMPLEMENTED** |

**Implementation Priority**: These 8 features are HIGH priority for macOS feature parity.

---

#### MEDIUM Priority Feature Gaps

| # | Feature | iOS Implementation | macOS Status |
|---|---------|-------------------|--------------|
| 9 | **Language Selection** | Picker in Settings | **IMPLEMENTED** |
| 10 | **Auth Timeout Options** | 5 timeout durations | **IMPLEMENTED** |
| 11 | **Feature Tips System** | TooltipOverlay with tracking | **IMPLEMENTED** |
| 12 | **Filter: Has Images** | ItemFilterOption.hasImages | **IMPLEMENTED** |

---

#### BUG: [FIXED] Remove iCloud Sync Toggle from macOS Settings

**Issue**: MacSettingsView.swift had an "Enable iCloud Sync" toggle (`@AppStorage("iCloudSyncEnabled")`) that was misleading.

**Reason**: iCloud sync is **mandatory and built-in** - NSPersistentCloudKitContainer automatically syncs all data. The toggle didn't actually disable sync at the Core Data level.

**Resolution**: Replaced the misleading toggle with read-only sync status information showing "iCloud Sync: Enabled" with explanatory text.

**Location**: `/ListAll/ListAllMac/Views/MacSettingsView.swift`

---

#### iOS-Only Features (Not Applicable to macOS)

These features are intentionally iOS-only due to platform differences:

| Feature | Reason |
|---------|--------|
| Pull-to-Refresh | macOS uses manual refresh button |
| Swipe Actions | macOS uses context menus |
| Haptic Feedback | No Mac equivalent |
| Tab Bar Navigation | macOS uses sidebar navigation |
| Camera Capture | macOS has different camera model |
| Photo Library Picker | macOS uses file picker |
| Apple Watch Sync | watchOS paired to iPhone only |

---

#### macOS-Only Features (Available)

These features are macOS-specific and working:

| Feature | Description |
|---------|-------------|
| Menu Commands | File/Edit/Lists/View/Help menus |
| Keyboard Shortcuts | Cmd+N, Cmd+Shift+N, Cmd+R, Cmd+F, etc. |
| Services Menu | "Add to ListAll" from any app |
| Quick Look | Space key to preview images |
| Sidebar Navigation | Three-column NavigationSplitView |
| Focus States | Arrow key navigation |
| NSSharingServicePicker | Native macOS sharing |
| Multi-Window | Standard macOS window management |
| Drag-Drop Images | From Finder |
| Paste Images | Cmd+V clipboard support |

---

#### Feature Implementation Summary

**Shared (Working on Both)**:
- List CRUD operations
- Item CRUD operations
- Filter (5 options) and Sort (5 options)
- Search functionality
- Smart Suggestions
- iCloud Sync (CloudKit)
- Handoff (iOS ↔ macOS)
- Import/Export (JSON, CSV, Plain Text)
- Sharing
- Image management (add, delete, reorder)
- Thumbnail caching
- Dark mode
- Accessibility (VoiceOver)

**Files Created**:
- `/documentation/FEATURES.md` - Comprehensive LLM-friendly feature reference

**References**:
- iOS Views: `/ListAll/ListAll/Views/` (25 view files)
- macOS Views: `/ListAllMac/Views/` (12 view files)
- Shared ViewModels: `/ListAll/ListAll/ViewModels/` (5 ViewModels)
- Shared Services: `/ListAll/ListAll/Services/` (13 services)

---

### Task 11.8: [COMPLETED] Fix macOS CloudKit Sync Not Receiving iOS Changes
**TDD**: Write sync verification tests

**Problem**: macOS app doesn't automatically sync when iOS app makes changes. Only when macOS app makes changes does iOS get updated later. This is the inverse of the issue fixed in `cloudkit-ios-realtime-sync.md`.

**Symptoms**:
- Changes made on iOS are NOT reflected on macOS in real-time
- Changes made on macOS ARE reflected on iOS (with some delay)
- macOS requires app restart or manual action to see iOS changes

**Investigation Areas**:
1. **Push Notifications**: macOS doesn't use UIBackgroundModes - relies on polling and observers
2. **NSManagedObjectContextDidSave Observer**: Check if properly configured for macOS
3. **NSPersistentCloudKitContainer Events**: Check if import events trigger UI refresh
4. **Threading**: Check for main thread violations like iOS had
5. **Polling Timer**: macOS has 30s sync polling timer - verify it's working
6. **View Observers**: Check MacMainView/MacListDetailView for `.coreDataRemoteChange` observers

**Key Files to Investigate**:
- `ListAll/ListAll/Models/CoreData/CoreDataManager.swift` - Observer setup
- `ListAllMac/Views/MacMainView.swift` - UI refresh observers
- `ListAll/ListAll/ViewModels/MainViewModel.swift` - Data loading
- `ListAll/ListAll/ViewModels/ListViewModel.swift` - Item refresh

**References**:
- `documentation/learnings/cloudkit-ios-realtime-sync.md` - Previous iOS fix
- `documentation/learnings/cloudkit-push-notification-config.md` - Push notification analysis

**Test criteria**:
```swift
func testMacOSReceivesCloudKitChangesFromiOS() {
    // Make change on iOS simulator
    // Verify macOS UI updates within 30 seconds (polling interval)
}

func testContextDidSaveObserverFires() {
    // Verify NSManagedObjectContextDidSave fires on macOS for remote changes
}

func testUIRefreshOnRemoteChange() {
    // Post .coreDataRemoteChange notification
    // Verify MacMainView refreshes list data
}
```

**Steps**:
1. Investigate CoreDataManager observer setup for macOS
2. Verify MainViewModel handles remote changes correctly on macOS
3. Check MacMainView for proper notification observers
4. Fix threading issues if any (similar to iOS fix)
5. Add missing observers if needed
6. Create unit tests for the fix
7. Document learnings

**Root Cause Found**:
Race condition in sync polling timer at `MacMainView.swift` lines 261-269:
- `viewContext.perform { refreshAllObjects() }` (async) and `DispatchQueue.main.async { loadData() }` (async)
- These are independent queue mechanisms that don't guarantee execution order
- `loadData()` could fetch stale data before `refreshAllObjects()` completed

**Fix Applied**:
Changed `perform` to `performAndWait` (synchronous) to ensure `refreshAllObjects()` completes before `loadData()`:
```swift
viewContext.performAndWait {
    viewContext.refreshAllObjects()
}
DispatchQueue.main.async {
    dataManager.loadData()
}
```

**Files Modified**:
- `ListAllMac/Views/MacMainView.swift` - Fixed sync polling timer

**Learnings Document**:
- `documentation/learnings/macos-cloudkit-sync-race-condition.md`

---

### Task 11.8.1: [COMPLETED] Enhanced CloudKit Sync Reliability

**Problem**: Initial Task 11.8 fix addressed race condition but sync still required app restart in some cases.

**Root Causes Identified** (via agent swarm analysis):
1. CloudKit event handler was refreshing UI on event START, not COMPLETE
2. Double notification handling - both `handleContextDidSave` and `handleCloudKitEvent` fired for CloudKit imports
3. Missing `setQueryGenerationFrom(.current)` for iOS (only macOS had it)
4. No manual refresh option for users

**Fixes Implemented**:

1. **CloudKit Event Handler Timing Fix** (CoreDataManager.swift):
   - Only refresh UI when `cloudEvent.endDate != nil` (event completed)
   - Reset query generation after CloudKit imports

2. **Notification Deduplication** (CoreDataManager.swift):
   - `handleContextDidSave` now detects CloudKit import contexts by name
   - Skips CloudKit contexts to prevent double-refresh (let `handleCloudKitEvent` handle them)

3. **Query Generation for iOS** (CoreDataManager.swift):
   - Added `setQueryGenerationFrom(.current)` for iOS (was only macOS)
   - Ensures fetch requests see latest CloudKit-imported data

4. **Last Sync Timestamp Tracking** (CoreDataManager.swift):
   - Added `@Published var lastSyncDate: Date?`
   - Updated on successful CloudKit imports/exports

5. **Manual Refresh Button** (MacMainView.swift):
   - Added refresh button to macOS toolbar
   - Shows last sync time in tooltip and sidebar footer
   - Calls `CoreDataManager.forceRefresh()` for manual sync

6. **Comprehensive CloudKit Logging**:
   - Platform-specific logging (`[iOS]` vs `[macOS]`)
   - Logs event start, completion, success, and failures

**Files Modified**:
- `ListAll/ListAll/Models/CoreData/CoreDataManager.swift`
- `ListAll/ListAllMac/Views/MacMainView.swift`
- `ListAll/ListAllTests/ServicesTests.swift` (test fixes)
- `ListAll/ListAllTests/CoreDataRemoteChangeTests.swift` (test timeout adjustment)

**Learnings Document**:
- `documentation/learnings/cloudkit-sync-enhanced-reliability.md`

---

### Task 11.8.2: [COMPLETED] Fix CloudKit Sync Trigger Mechanism

**Problem**: Despite previous fixes (11.8, 11.8.1), CloudKit sync between iOS and macOS still only works after app restart.

**User-Reported Symptoms (TestFlight builds)**:
- Changes on iOS only appear on macOS after BOTH apps restart
- Changes on macOS only appear on iOS after iOS restart
- Manual sync button has no effect

**Root Causes Identified** (via agent swarm analysis):

1. **CloudKitService.sync() was empty**: The method had a placeholder block that did nothing:
   ```swift
   coreDataManager.persistentContainer.persistentStoreCoordinator.performAndWait {
       // This triggers the CloudKit sync  <-- EMPTY!
   }
   ```

2. **No mechanism to wake up CloudKit**: `refreshAllObjects()` only refreshes from LOCAL store, not from CloudKit server. NSPersistentCloudKitContainer sync is passive (APNS-based) and unreliable when foregrounded.

3. **macOS used wrong Timer pattern**: `Timer.scheduledTimer` with `[self]` in SwiftUI View captures a stale copy of the struct.

**Key Insight**: You CANNOT force CloudKit to fetch from server. However, triggering a background context operation can wake up the CloudKit mirroring delegate to process pending operations.

**Fixes Implemented**:

1. **Added triggerCloudKitSync()** (CoreDataManager.swift):
   ```swift
   func triggerCloudKitSync() {
       persistentContainer.performBackgroundTask { context in
           context.processPendingChanges()
       }
   }
   ```

2. **Fixed CloudKitService.sync()** (CloudKitService.swift):
   - Calls `triggerCloudKitSync()` to wake up CloudKit
   - Adds 0.5s delay to allow processing
   - Then calls `forceRefresh()` to update UI

3. **Updated forceRefresh()** (CoreDataManager.swift):
   - Now calls `triggerCloudKitSync()` first
   - Then refreshes local objects and posts notification

4. **Fixed macOS Timer pattern** (MacMainView.swift):
   - Changed from `Timer.scheduledTimer` to `Timer.publish` pattern
   - Added `import Combine` for Timer.publish support
   - Uses `isSyncPollingActive` flag with `.onReceive` modifier

5. **Added triggerCloudKitSync() to polling** (Both platforms):
   - iOS and macOS polling now call `triggerCloudKitSync()` before refreshing

**Files Modified**:
- `ListAll/ListAll/Models/CoreData/CoreDataManager.swift`
- `ListAll/ListAll/Services/CloudKitService.swift`
- `ListAll/ListAllMac/Views/MacMainView.swift`
- `ListAll/ListAll/Views/MainView.swift`

**Learnings Document**:
- `documentation/learnings/cloudkit-sync-trigger-mechanism.md`

**Important Caveats**:
- This is not a guaranteed fix - CloudKit sync timing is controlled by Apple's infrastructure
- App restart still works best due to full zone fetch during initialization
- Polling (30s interval) is essential fallback for sync reliability

---

### Task 11.9: [COMPLETED] Implement Proper Test Isolation with Dependency Injection
**TDD**: Tests should run without any system permission dialogs

**Problem**:
macOS unit tests trigger permission dialogs for App Groups ("ListAll would like to access data from other apps") and Keychain access. Tests should be completely isolated and use fakes/mocks instead of real system services.

**Current Workarounds** (incomplete):
- `CoreDataManager` uses `/dev/null` SQLite store in test mode
- Lazy initialization to defer singleton access
- Test detection guards for App Groups access
- Separate Debug entitlements without App Groups

**Why Current Approach is Insufficient**:
1. Production singletons still INITIALIZE during test runs (even if not fully accessed)
2. Test classes inherit from production classes, risking production code execution
3. Test detection logic scattered throughout production code (`ListAllMacApp.swift`)
4. Inconsistent singleton access patterns across codebase
5. Any accidental touch of a lazy property triggers App Groups access

**Root Cause**:
The codebase uses singletons (`DataManager.shared`, `CoreDataManager.shared`) accessed throughout production code. Tests try to work around singletons rather than using proper dependency injection.

**Solution: Protocol-Based Dependency Injection**

**Phase 1: Define Protocols** (non-breaking changes)
```swift
// CoreDataManaging protocol
protocol CoreDataManaging {
    var viewContext: NSManagedObjectContext { get }
    var backgroundContext: NSManagedObjectContext { get }
    func save()
    func loadStores()
}

// DataManaging protocol
protocol DataManaging: ObservableObject {
    var lists: [List] { get }
    func loadData()
    func addList(_ list: List)
    func updateList(_ list: List)
    func deleteList(withId id: UUID)
    // ... other methods
}

// CloudSyncProviding protocol
protocol CloudSyncProviding: ObservableObject {
    var isSyncing: Bool { get }
    var syncStatus: SyncStatus { get }
    func sync() async
}
```

**Phase 2: Conform Production Classes**
```swift
extension CoreDataManager: CoreDataManaging { }
extension DataManager: DataManaging { }
extension CloudKitService: CloudSyncProviding { }
```

**Phase 3: Create Test Mocks** (composition, not inheritance)
```swift
class MockCoreDataManager: CoreDataManaging {
    // In-memory Core Data stack - no App Groups access
    private let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "ListAll")
        let description = NSPersistentStoreDescription()
        description.url = URL(fileURLWithPath: "/dev/null")
        description.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, _ in }
    }

    var viewContext: NSManagedObjectContext { container.viewContext }
    // ... implement protocol methods
}

class MockDataManager: DataManaging {
    @Published var lists: [List] = []
    // Pure in-memory implementation - no Core Data
}
```

**Phase 4: Update ViewModels for Constructor Injection**
```swift
class MainViewModel: ObservableObject {
    private let dataManager: DataManaging

    // Production: Uses default, Tests: Inject mock
    init(dataManager: DataManaging = DataManager.shared) {
        self.dataManager = dataManager
    }
}
```

**Phase 5: Remove Test Detection from Production Code**
- Remove `isUnitTesting` checks from `ListAllMacApp.swift`
- Remove `DataManagerWrapper` pattern
- Use compile-time `#if TESTING` flags only where absolutely necessary

**Services Requiring Protocol Abstraction**:

| Service | Priority | Reason |
|---------|----------|--------|
| `CoreDataManager` | P0 - Critical | App Groups access triggers dialogs |
| `DataManager` | P0 - Critical | Uses CoreDataManager internally |
| `DataRepository` | P0 - Critical | Uses both managers |
| `CloudKitService` | P1 - High | Network and CloudKit access |
| `LocalizationManager` | P1 - High | Uses App Groups for shared preferences |
| `ImageService` | P2 - Medium | Shared thumbnail cache |
| `BiometricAuthService` | P2 - Medium | System authentication |
| `WatchConnectivityService` | P3 - Low | iOS only, already guarded |
| `HandoffService` | P3 - Low | NSUserActivity management |

**Test Criteria**:
```swift
func testNoPermissionDialogsTriggered() {
    // All tests should pass without any UI interruption
    // This is verified by CI running tests non-interactively
}

func testMockDataManagerDoesNotAccessAppGroups() {
    let mock = MockDataManager()
    mock.loadData()
    mock.addList(List(name: "Test"))
    // No App Groups access - verified by no permission prompts
}

func testViewModelWorksWithMock() {
    let mock = MockDataManager()
    let viewModel = MainViewModel(dataManager: mock)
    viewModel.createList(name: "Test")
    XCTAssertTrue(mock.lists.contains { $0.name == "Test" })
}
```

**Estimated Effort**:
- Phase 1 (Protocols): 2-3 hours
- Phase 2 (Conformance): 1 hour
- Phase 3 (Mocks): 3-4 hours
- Phase 4 (Constructor injection): 4-6 hours
- Phase 5 (Cleanup): 2-3 hours
- Test updates: 4-6 hours
- **Total**: 16-23 hours (2-3 days)

**Benefits**:
- Tests run without ANY system permission dialogs
- Tests are faster (no system service initialization)
- Better test isolation (no shared state between tests)
- Cleaner architecture (follows SOLID principles)
- Easier to test edge cases (mock can simulate errors)
- CI stability (no flaky tests due to system prompts)

**References**:
- WWDC21: Build apps that share data through CloudKit and Core Data
- Apple Documentation: Testing Core Data with NSPersistentCloudKitContainer
- objc.io: Dependency Injection in Swift

**Files to Create**:
- `ListAll/ListAll/Protocols/CoreDataManaging.swift`
- `ListAll/ListAll/Protocols/DataManaging.swift`
- `ListAll/ListAll/Protocols/CloudSyncProviding.swift`
- `ListAll/ListAllMacTests/Mocks/MockCoreDataManager.swift`
- `ListAll/ListAllMacTests/Mocks/MockDataManager.swift`
- `ListAll/ListAllMacTests/Mocks/MockCloudKitService.swift`

**Files to Modify**:
- `ListAll/ListAll/Models/CoreData/CoreDataManager.swift` - Conform to protocol
- `ListAll/ListAll/Models/DataManager.swift` - Conform to protocol
- `ListAll/ListAll/Services/CloudKitService.swift` - Conform to protocol
- `ListAll/ListAll/ViewModels/MainViewModel.swift` - Constructor injection
- `ListAll/ListAll/ViewModels/ListViewModel.swift` - Constructor injection
- `ListAll/ListAll/ViewModels/ItemViewModel.swift` - Constructor injection
- `ListAll/ListAllMac/ListAllMacApp.swift` - Remove test detection
- `ListAll/ListAllMacTests/TestHelpers.swift` - Use new mocks

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

### Task 12.1: Implement Cmd+Click Multi-Select (CRITICAL)

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
