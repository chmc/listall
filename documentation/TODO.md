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
| [TODO.DONE.PHASES-12-14.md](./TODO.DONE.PHASES-12-14.md) | 12-14 | 27 |

---

## Completed Phases (1-13)

All phases 1-13 have been completed with full TDD, code examples, and documentation.
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
| 12 | UX Polish & Best Practices | 13/13 ✅ | [View](./TODO.DONE.PHASES-12-14.md#phase-12-ux-polish) |
| 13 | Archived Lists Bug Fixes | 4/4 ✅ | [View](./TODO.DONE.PHASES-12-14.md#phase-13-archived-lists-bug-fixes) |
| 14 | Visual Verification MCP Server | 10/10 ✅ | [View](./TODO.DONE.PHASES-12-14.md#phase-14-visual-verification-mcp-server) |

**Total Completed**: 91 tasks across 14 phases

---

## Phase 15: Feature Parity - High & Medium Priority

**Source**: Generated from `/documentation/FEATURE_PARITY.md` verification (2026-01-23)

### Task 15.1: [COMPLETED] macOS Active/Archived Toggle
**Platform**: macOS
**Severity**: High (was incorrectly flagged - feature exists)

**Finding**: Feature already existed as collapsible "Archived" sidebar section following macOS HIG pattern (superior to iOS toggle button). Issues were:
1. UITEST_MODE had no archived sample data, so section never showed
2. Archive menu command handler was missing
3. SwiftUI Section conditional rendering had a bug

**Fixes Applied**:
1. Added archived list to UITestDataService.swift (English: "Old Shopping List", Finnish: "Vanha ostoslista")
2. Added missing `ArchiveSelectedList` notification handler in MacMainView.swift
3. Fixed CoreDataManager.addList() to preserve `isArchived` property
4. Fixed SwiftUI Section rendering by keeping ForEach always in view hierarchy with visibility control

**Files Modified**:
- `ListAll/Services/UITestDataService.swift` - Added archived sample lists
- `ListAllMac/Views/MacMainView.swift` - Added notification handler, fixed Section rendering
- `ListAll/Models/CoreData/CoreDataManager.swift` - Fixed addList() to preserve isArchived

**Visual Verification**: macOS archived section works with collapse/expand toggle

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 15.2: [COMPLETED] iPad Split View Layout
**Platform**: iPad
**Severity**: High

**Implementation**: Created `NavigationStyleModifier` that conditionally applies `.navigationViewStyle(.stack)`:
- iPhone: Always stack navigation (standard iOS pattern)
- iPad + UITEST_MODE: Stack for consistent App Store screenshots
- iPad normally: Default style (enables split view for better multitasking)

**Files Modified**:
- `ListAll/Views/MainView.swift` - Added NavigationStyleModifier, replaced hardcoded .stack

**Visual Verification**: iPad shows stack style in UITEST_MODE (correct for screenshots)

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 15.3: iPad NavigationSplitView Sidebar
**Platform**: iPad
**Severity**: High
**TDD**: Write tests before implementation

**Implementation Hint**: Implement NavigationSplitView for iPad with sidebar showing lists

**Steps**:
1. Write failing tests for sidebar navigation on iPad
2. Implement NavigationSplitView with sidebar for lists
3. Verify tests pass
4. Visual verification on iPad simulator

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on iPad simulator
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 15.4: macOS Bulk Delete Lists
**Platform**: macOS
**Severity**: Medium
**TDD**: Write tests before implementation

**Implementation Hint**: Add "Delete Lists" option to SelectionActionsMenu in ListsToolbarView

**Steps**:
1. Write failing tests for bulk delete lists functionality
2. Implement delete option in SelectionActionsMenu
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 15.5: macOS Export CSV
**Platform**: macOS
**Severity**: Medium
**TDD**: Write tests before implementation

**Implementation Hint**: Add CSV format option to export dialogs for spreadsheet compatibility

**Steps**:
1. Write failing tests for CSV export functionality
2. Implement CSV export option in ShareListView and ExportAllListsView
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 15.6: macOS Manual Sync Button
**Platform**: macOS
**Severity**: Medium
**TDD**: Write tests before implementation

**Implementation Hint**: Add refresh button to toolbar with sync animation

**Steps**:
1. Write failing tests for manual sync button functionality
2. Implement sync button in toolbar with animation feedback
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 15.7: iOS Default Sort Order in Settings
**Platform**: iOS
**Severity**: Medium
**TDD**: Write tests before implementation

**Implementation Hint**: Add sort order picker to iOS Settings like macOS has

**Steps**:
1. Write failing tests for default sort order setting
2. Implement sort order picker in iOS SettingsView
3. Verify tests pass
4. Visual verification on iPhone simulator

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on iPhone simulator
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 15.8: iPad Keyboard Shortcuts
**Platform**: iPad
**Severity**: Medium
**TDD**: Write tests before implementation

**Implementation Hint**: Add `.keyboardShortcut()` modifiers for common actions (Cmd+N new item, etc.)

**Steps**:
1. Write failing tests for keyboard shortcuts on iPad
2. Implement keyboard shortcuts for common actions
3. Verify tests pass
4. Visual verification on iPad simulator (test via hardware keyboard)

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on iPad simulator
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

## Phase 16: Feature Parity - Low Priority & Polish

**Source**: Generated from `/documentation/FEATURE_PARITY.md` verification (2026-01-23)

### Task 16.1: macOS Filter: Has Description
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add advanced filter option to filter items with non-empty description (parity with iOS)

**Steps**:
1. Write failing tests for "Has Description" filter
2. Implement filter option in MacFilterView
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.2: macOS Filter: Has Images
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add advanced filter option to filter items with attached images (parity with iOS)

**Steps**:
1. Write failing tests for "Has Images" filter
2. Implement filter option in MacFilterView
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.3: macOS Duplicate Item Action
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add "Duplicate" to item context menu or selection actions

**Steps**:
1. Write failing tests for duplicate item functionality
2. Implement duplicate action in item context menu
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.4: macOS Include Images in Share List
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add "Include images" option to single list Share dialog

**Steps**:
1. Write failing tests for images option in share dialog
2. Implement images toggle in ShareListView
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.5: macOS Collapse/Expand Suggestions Toggle
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add expand/collapse button on "Suggestions" header

**Steps**:
1. Write failing tests for suggestions collapse/expand toggle
2. Implement toggle button on suggestions section header
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.6: macOS Live Sync Status Indicator
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add sync status indicator in toolbar showing last sync time

**Steps**:
1. Write failing tests for live sync status indicator
2. Implement sync status in toolbar with last sync timestamp
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.7: macOS Feature Tips Reset Button
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add "Reset All Tips" button to clear viewed tips and show them again

**Steps**:
1. Write failing tests for feature tips reset functionality
2. Implement reset button in Settings > General
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.8: macOS Auth Timeout Duration
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add timeout duration picker when biometric auth is enabled

**Steps**:
1. Write failing tests for auth timeout duration setting
2. Implement timeout picker in Settings > Security
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.9: macOS Duplicate List Visibility
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Make duplicate list action more discoverable - may be sync/UI refresh issue

**Steps**:
1. Investigate why Cmd+D duplicate doesn't appear in sidebar
2. Write failing tests for duplicate list visibility
3. Fix the UI refresh/sync issue
4. Verify tests pass
5. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.10: macOS Sample List Templates
**Platform**: macOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add template picker when creating new list (e.g., Grocery, Travel, Project)

**Steps**:
1. Write failing tests for sample list templates
2. Implement template picker in CreateListView
3. Verify tests pass
4. Visual verification on macOS

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on macOS
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.11: iOS Live Sync Status Indicator
**Platform**: iOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add visual indicator for ongoing sync (spinner/badge)

**Steps**:
1. Write failing tests for live sync status indicator
2. Implement sync indicator in toolbar
3. Verify tests pass
4. Visual verification on iPhone simulator

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on iPhone simulator
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.12: iOS Clear All Filters Button
**Platform**: iOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add "Reset" button to ItemOrganizationView to clear all active filters

**Steps**:
1. Write failing tests for clear all filters button
2. Implement reset button in ItemOrganizationView
3. Verify tests pass
4. Visual verification on iPhone simulator

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on iPhone simulator
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.13: iOS Explicit 10 Image Limit UI
**Platform**: iOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add guard check for max 10 images like macOS and show clear UI indication

**Steps**:
1. Write failing tests for 10 image limit
2. Implement limit check and UI feedback in ItemEditView
3. Verify tests pass
4. Visual verification on iPhone simulator

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on iPhone simulator
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.14: iOS Left Swipe Actions on Items
**Platform**: iOS
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: iOS only has Delete on right swipe; consider adding Edit/Duplicate on left swipe

**Steps**:
1. Write failing tests for left swipe actions
2. Implement left swipe actions in ItemRowView
3. Verify tests pass
4. Visual verification on iPhone simulator

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on iPhone simulator
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.15: iPad Multi-Column Layout
**Platform**: iPad
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Consider showing list detail alongside items on larger iPads

**Steps**:
1. Write failing tests for multi-column layout on large iPads
2. Implement adaptive layout for 12.9" iPad Pro
3. Verify tests pass
4. Visual verification on iPad simulator

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on iPad simulator
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.16: iPad Pointer/Trackpad Hover Effects
**Platform**: iPad
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add `.hoverEffect()` for buttons and list rows

**Steps**:
1. Write failing tests for hover effects (if testable)
2. Implement `.hoverEffect()` modifiers on interactive elements
3. Verify tests pass
4. Visual verification on iPad simulator with trackpad

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on iPad simulator
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

### Task 16.17: All Platforms - Test Data Images for UITEST_MODE
**Platform**: All
**Severity**: Low
**TDD**: Write tests before implementation

**Implementation Hint**: Add sample images to UITEST_MODE data for verification of image features

**Steps**:
1. Write failing tests for UITEST_MODE sample data with images
2. Add sample images to test data generation
3. Verify tests pass
4. Visual verification on macOS, iPhone, and iPad

**Task Rule**:
- Mark title `[IN PROGRESS]` when starting
- Follow strict TDD: write tests first, then implement
- Mark title `[COMPLETED]` only after ALL of the following:
  1. All tests pass (`xcodebuild test`)
  2. Visual verification loop (MANDATORY):
     a. Launch app with UITEST_MODE via MCP tools
     b. Interact with app (click, type, navigate) while taking screenshots
     c. Does feature work as expected?
     d. If NO: fix the issue, then repeat from step (a)
     e. If YES: continue to next step
  3. Commit code with descriptive message
  4. Proceed to next task
  5. Feature verified working on ALL platforms: macOS, iPhone, iPad
- If MCP visual verification tools fail:
  1. Investigate and fix the MCP tool issue
  2. Rebuild: `cd Tools/listall-mcp && swift build`
  3. Restart Claude Code, then resume verification

---

## Phase 17: App Store Submission

### Task 17.1: Submit to App Store
**TDD**: Submission verification

**Steps**:
1. Run full test suite
2. Build release version
3. Submit for review via:
   ```bash
   bundle exec fastlane release_mac version:1.0.0
   ```

---

## Phase 18: Spotlight Integration (Optional)

### Task 18.1: Implement Spotlight Integration
**TDD**: Write Spotlight indexing tests

**Priority**: Low - Optional feature, disabled by default

**User Setting**:
- Add "Enable Spotlight Indexing" toggle in Settings > General
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
| Phase 13: Archived Lists Bug Fixes | Completed | 4/4 |
| Phase 14: Visual Verification MCP Server | Completed | 10/10 |
| Phase 15: Feature Parity - High & Medium | Not Started | 0/8 |
| Phase 16: Feature Parity - Low Priority | Not Started | 0/17 |
| Phase 17: App Store Submission | Not Started | 0/1 |
| Phase 18: Spotlight Integration | Optional | 0/1 |

**Total Tasks: 118** (91 completed, 27 remaining)

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
- Task 13.2: [COMPLETED] Make Archived Lists Read-Only
- Task 13.3: [COMPLETED] Update Documentation Status
- Task 13.4: [COMPLETED] Fix Selection Persistence Bug When Switching Tabs

**Phase 15 Status** (Feature Parity - High & Medium Priority):
- Task 15.1: macOS Active/Archived Toggle
- Task 15.2: iPad Split View Layout
- Task 15.3: iPad NavigationSplitView Sidebar
- Task 15.4: macOS Bulk Delete Lists
- Task 15.5: macOS Export CSV
- Task 15.6: macOS Manual Sync Button
- Task 15.7: iOS Default Sort Order in Settings
- Task 15.8: iPad Keyboard Shortcuts

**Phase 16 Status** (Feature Parity - Low Priority & Polish):
- Task 16.1: macOS Filter: Has Description
- Task 16.2: macOS Filter: Has Images
- Task 16.3: macOS Duplicate Item Action
- Task 16.4: macOS Include Images in Share List
- Task 16.5: macOS Collapse/Expand Suggestions Toggle
- Task 16.6: macOS Live Sync Status Indicator
- Task 16.7: macOS Feature Tips Reset Button
- Task 16.8: macOS Auth Timeout Duration
- Task 16.9: macOS Duplicate List Visibility
- Task 16.10: macOS Sample List Templates
- Task 16.11: iOS Live Sync Status Indicator
- Task 16.12: iOS Clear All Filters Button
- Task 16.13: iOS Explicit 10 Image Limit UI
- Task 16.14: iOS Left Swipe Actions on Items
- Task 16.15: iPad Multi-Column Layout
- Task 16.16: iPad Pointer/Trackpad Hover Effects
- Task 16.17: All Platforms - Test Data Images for UITEST_MODE

**Phase 17 Status**:
- Task 17.1: Submit to App Store

**Phase 18 Status** (Optional):
- Task 18.1: Implement Spotlight Integration

**Notes**:
- Phase 12 added based on agent swarm UX research (January 2026)
- Phase 13 added based on agent swarm investigation (January 2026) - discovered missing restore UI and mutable archived lists bugs
- Phase 14 revised (January 2026): Visual Verification MCP Server with 10 tasks - includes spike validation, XCUITest bridge for simulators, and Claude self-instruction skills
- Phase 15-16 added (January 2026): Feature parity tasks from `/documentation/FEATURE_PARITY.md` verification - 25 tasks across 4 platforms (macOS, iOS, iPad, watchOS)
- Task 6.4 (Spotlight Integration) moved to Phase 18 as optional feature (disabled by default)
- Phase 9 revised based on swarm analysis: uses parallel jobs architecture (Task 9.0 added as blocking pre-requisite)
- Task 11.7 added comprehensive feature parity analysis with `/documentation/FEATURES.md`
