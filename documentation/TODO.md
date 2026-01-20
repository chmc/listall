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

## Phase Completion & Archival Rules

When an entire phase is completed (all tasks marked `[COMPLETED]`), archive it to preserve context for future LLM reference.

### File Naming Convention

| Scenario | File Name |
|----------|-----------|
| Single phase | `TODO.DONE.PHASE-{N}.md` (e.g., `TODO.DONE.PHASE-12.md`) |
| Multiple related phases | `TODO.DONE.PHASES-{N}-{M}.md` (e.g., `TODO.DONE.PHASES-8-11.md`) |

### Archival Steps

1. **Create/Update Archive File**: Move completed phase content to the appropriate `TODO.DONE.PHASE*.md` file
2. **Update Navigation Links**: Add cross-references in both files
3. **Replace Phase in TODO.md**: Convert detailed content to a summary row in the "Completed Phases" table
4. **Update Progress Tracking**: Mark phase as "Completed" in the Progress Tracking table

### LLM-Optimized Format for Archived Phases

Archive files must follow this structure for efficient LLM processing:

```markdown
# ListAll macOS App - Completed Phase {N} ({Title})

> **Navigation**: [Phases 1-4](./TODO.DONE.PHASES-1-4.md) | [Active Tasks](./TODO.md)

{Brief description of what this phase accomplished}

**Tags**: {comma-separated keywords for searchability}
**Completion Date**: {Month Day, Year}
**Total Tasks**: {X/X} completed

---

## Table of Contents

1. [Phase Overview](#phase-overview)
2. [Task N.1: {Title}](#task-n1-title)
...

---

## Phase Overview

{Priority levels if applicable, summary statistics}

---

## Task N.1: {Title}

**Problem**: {1-2 sentences explaining what was wrong}

**Solution**:
1. {Key change 1}
2. {Key change 2}

**Files Modified**:
- `path/to/file.swift`

**Tests**: {X} tests in `{TestClassName}`

**Learning**: `{path if learning doc created}`

---
```

### Key Formatting Principles

- **Concise Problem/Solution**: Summarize, don't duplicate full task descriptions
- **File Paths**: List actual files modified for easy navigation
- **Test References**: Include test class names and counts
- **Code Snippets**: Only include if they illustrate a non-obvious pattern
- **Tags**: Enable keyword search across archive files
- **Cross-Navigation**: Always include navigation links at top

### Current Archive Files

| File | Phases | Tasks |
|------|--------|-------|
| [TODO.DONE.PHASES-1-4.md](./TODO.DONE.PHASES-1-4.md) | 1-4 | 20 |
| [TODO.DONE.PHASES-5-7.md](./TODO.DONE.PHASES-5-7.md) | 5-7 | 22 |
| [TODO.DONE.PHASES-8-11.md](./TODO.DONE.PHASES-8-11.md) | 8-11 | 25 |
| [TODO.DONE.PHASE-12.md](./TODO.DONE.PHASE-12.md) | 12 | 13 |

---

## Completed Phases (1-12)

All phases 1-12 have been completed with full TDD, code examples, and documentation.
Detailed implementation records are preserved in split files for LLM reference.

| Phase | Description | Tasks | Details |
|-------|-------------|-------|---------|
| 1 | Project Setup & Architecture | 5/5 ✅ | [View](./TODO.DONE.PHASES-1-4.md#phase-1-project-setup--architecture) |
| 2 | Core Data & Models | 3/3 ✅ | [View](./TODO.DONE.PHASES-1-4.md#phase-2-core-data--models) |
| 3 | Services Layer | 7/7 ✅ | [View](./TODO.DONE.PHASES-1-4.md#phase-3-services-layer) |
| 4 | ViewModels | 5/5 ✅ | [View](./TODO.DONE.PHASES-1-4.md#phase-4-viewmodels) |
| 5 | macOS-Specific Views | 11/11 ✅ | [View](./TODO.DONE.PHASES-5-7.md#phase-5-macos-specific-views) |
| 6 | Advanced Features | 4/4 ✅ | [View](./TODO.DONE.PHASES-5-7.md#phase-6-advanced-features) |
| 7 | Testing Infrastructure | 4/4 ✅ | [View](./TODO.DONE.PHASES-5-7.md#phase-7-testing-infrastructure) |
| 8 | Feature Parity with iOS | 4/4 ✅ | [View](./TODO.DONE.PHASES-8-11.md#phase-8-feature-parity-with-ios) |
| 9 | CI/CD Pipeline | 7/7 ✅ | [View](./TODO.DONE.PHASES-8-11.md#phase-9-cicd-pipeline) |
| 10 | App Store Preparation | 5/5 ✅ | [View](./TODO.DONE.PHASES-8-11.md#phase-10-app-store-preparation) |
| 11 | Polish & Launch | 9/9 ✅ | [View](./TODO.DONE.PHASES-8-11.md#phase-11-polish--launch) |
| 12 | UX Polish & Best Practices | 13/13 ✅ | [View](./TODO.DONE.PHASE-12.md) |

**Total Completed**: 77 tasks across 12 phases

---

## Phase 13: Archived Lists Bug Fixes (CRITICAL)

> **Issue Discovery**: Agent swarm investigation (January 2026) revealed two critical bugs in macOS archived lists handling that break feature parity with iOS.

### Task 13.1: [COMPLETED] Add Restore Functionality for Archived Lists
**TDD**: Write tests for restore UI actions

**Priority**: CRITICAL - Users cannot restore archived lists on macOS

**Problem**:
- macOS has NO "Restore" option in the UI for archived lists
- iOS has restore buttons in `ListRowView` (inline) and `ArchivedListView` (toolbar)
- Backend `restoreList(withId:)` exists in `CoreDataManager` but macOS UI doesn't expose it

**Solution Implemented**:
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

**Tests Added** (4 new tests in ArchivedListsTests):
- testRestoreConfirmationStateManagement
- testRestoreContextMenuAvailability
- testMainViewModelRestoreList
- testRestoreConfirmationMessageIncludesListName

---

### Task 13.2: Make Archived Lists Read-Only
**TDD**: Write tests for read-only enforcement

**Priority**: CRITICAL - Archived lists should not be editable

**Problem**:
- macOS allows full editing of archived lists (add items, edit items, edit list name, reorder)
- iOS uses dedicated `ArchivedListView` that is completely read-only
- This defeats the purpose of archiving (preserving list state)

**iOS Reference** (`ArchivedListView.swift`):
- No add item button
- Items rendered with `ArchivedItemRowView` (no interactive elements)
- No edit controls, no swipe actions, no context menus for editing
- Only actions: Restore and Permanent Delete

**Steps**:
1. Add `isArchived` property check in `MacListDetailView` to conditionally hide:
   - Add Item button (+) in toolbar
   - Edit List button (pencil icon)
   - Selection mode toggle
   - Import/Export actions
2. Disable item editing when list is archived:
   - Hide toggle completion (checkbox)
   - Hide edit button on item rows
   - Disable drag-to-reorder
   - Remove swipe actions
3. Update context menu for archived lists:
   - Show only: "Restore" and "Delete Permanently"
   - Hide: Share, Duplicate, Edit
4. Add visual indicator that list is archived (e.g., "Archived" badge in header)
5. Optionally: Create dedicated `MacArchivedListDetailView` (cleaner separation like iOS)

**Test criteria**:
```swift
func testAddItemButtonHiddenForArchivedList() {
    // + button not visible when viewing archived list
}

func testEditListButtonHiddenForArchivedList() {
    // Pencil button not visible when viewing archived list
}

func testItemRowReadOnlyForArchivedList() {
    // Item checkbox and edit button hidden for archived items
}

func testContextMenuDifferentForArchivedLists() {
    // Only Restore and Delete options shown
}

func testDragReorderDisabledForArchivedList() {
    // Cannot reorder items in archived list
}
```

---

### Task 13.3: Update Documentation Status
**TDD**: Documentation accuracy verification

**Priority**: IMPORTANT - Documentation must reflect actual state

**Problem**:
- `LIST_MANAGEMENT.md` claims ✅ for "Restore Archived List" on macOS
- `SUMMARY.md` claims full feature parity with "No gaps"
- This is inaccurate until Tasks 13.1 and 13.2 are completed

**Steps**:
1. After completing Tasks 13.1 and 13.2, verify all functionality works
2. Run full test suite to confirm no regressions
3. Update `documentation/features/LIST_MANAGEMENT.md` if needed
4. Update `documentation/features/SUMMARY.md` if needed
5. Write learning document to `/documentation/learnings/` about archive/restore parity

**Note**: Only update to ✅ after actual implementation is verified working.

---

## Phase 14: App Store Submission

### Task 14.1: Submit to App Store
**TDD**: Submission verification

**Steps**:
1. Run full test suite
2. Build release version
3. Submit for review via:
   ```bash
   bundle exec fastlane release_mac version:1.0.0
   ```

---

## Phase 15: Spotlight Integration (Optional)

### Task 15.1: Implement Spotlight Integration
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
| Phase 12: UX Polish & Best Practices | Completed | 13/13 |
| Phase 13: Archived Lists Bug Fixes | In Progress | 1/3 |
| Phase 14: App Store Submission | Not Started | 0/1 |
| Phase 15: Spotlight Integration | Optional | 0/1 |

**Total Tasks: 83** (77 completed, 6 remaining)

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
- Task 12.1: [COMPLETED] Implement Cmd+Click Multi-Select (CRITICAL)
- Task 12.2: [COMPLETED] Fix Cmd+F Global Search Scope (CRITICAL)
- Task 12.3: [COMPLETED] Improve Selection Mode Discoverability (CRITICAL)
- Task 12.4: [COMPLETED] Redesign Filter UI to Native macOS Pattern (CRITICAL)
- Task 12.5: [COMPLETED] Add Proactive Feature Tips (IMPORTANT)
- Task 12.6: [COMPLETED] Add Sync Status Indicator in Toolbar (IMPORTANT)
- Task 12.7: [COMPLETED] Consistent Empty State Components (IMPORTANT)
- Task 12.8: [COMPLETED] Standardize Destructive Action Handling (IMPORTANT)
- Task 12.9: [COMPLETED] Make Settings Window Resizable (IMPORTANT)
- Task 12.10: [COMPLETED] Add Quick Entry Window (MINOR)
- Task 12.11: [COMPLETED] Add Keyboard Reordering (MINOR)
- Task 12.12: [COMPLETED] Add Clear All Filters Shortcut (MINOR)
- Task 12.13: [COMPLETED] Add Image Gallery Size Presets (MINOR)

**Phase 13 Status** (Archived Lists Bug Fixes - Agent Swarm Investigation):
- Task 13.1: [COMPLETED] Add Restore Functionality for Archived Lists
- Task 13.2: Make Archived Lists Read-Only
- Task 13.3: Update Documentation Status

**Phase 14 Status**:
- Task 14.1: Submit to App Store

**Phase 15 Status** (Optional):
- Task 15.1: Implement Spotlight Integration

**Notes**:
- Phase 12 added based on agent swarm UX research (January 2026)
- Phase 13 added based on agent swarm investigation (January 2026) - discovered missing restore UI and mutable archived lists bugs
- Task 6.4 (Spotlight Integration) moved to Phase 15 as optional feature (disabled by default)
- Phase 9 revised based on swarm analysis: uses parallel jobs architecture (Task 9.0 added as blocking pre-requisite)
- Task 11.7 added comprehensive feature parity analysis with `/documentation/FEATURES.md`
