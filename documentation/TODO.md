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
| [TODO.DONE.PHASES-12-13.md](./TODO.DONE.PHASES-12-13.md) | 12-13 | 17 |

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
| 12 | UX Polish & Best Practices | 13/13 ✅ | [View](./TODO.DONE.PHASES-12-13.md#phase-12-ux-polish) |
| 13 | Archived Lists Bug Fixes | 4/4 ✅ | [View](./TODO.DONE.PHASES-12-13.md#phase-13-archived-lists-bug-fixes) |

**Total Completed**: 81 tasks across 13 phases

---

## Phase 14: Visual Verification MCP Server

Build an MCP server enabling Claude to visually verify its own work across all ListAll platforms (macOS, iOS, iPadOS, watchOS) without requiring manual user verification.

**Goal**: Give Claude a feedback loop to 2-3x the quality of UI work by allowing it to see and interact with the apps.

### Feasibility

| Platform | Launch | Screenshot | Interaction | Permissions |
|----------|--------|------------|-------------|-------------|
| macOS | `open -a` | ScreenCaptureKit | Accessibility API | Screen Recording + Accessibility |
| iOS Sim | `simctl launch` | `simctl io screenshot` | XCUITest | **NONE** |
| iPad Sim | `simctl launch` | `simctl io screenshot` | XCUITest | **NONE** |
| Watch Sim | `simctl launch` | `simctl io screenshot` | XCUITest | **NONE** |

### Architecture

```
Claude Code <--> stdio <--> listall-mcp (Swift)
                                |
              +-----------------+-----------------+
              v                 v                 v
          macOS App         iOS Sim           Watch Sim
        (Accessibility)    (XCUITest)        (XCUITest)
```

### MCP Tools

| Tool | Description | macOS | Simulators |
|------|-------------|-------|------------|
| `listall_screenshot` | Capture current state | ScreenCaptureKit | simctl io |
| `listall_launch` | Launch app | open -a | simctl install + launch |
| `listall_click` | Tap element by ID | AXUIElement | XCUITest |
| `listall_type` | Enter text | AXUIElement | XCUITest |
| `listall_swipe` | Swipe gesture | AXUIElement | XCUITest |
| `listall_query` | List UI elements | AXUIElement | XCUITest |
| `listall_list_simulators` | List devices | N/A | simctl list |
| `listall_boot_simulator` | Boot simulator | N/A | simctl boot |
| `listall_shutdown` | Shutdown | N/A | simctl shutdown |
| `listall_diagnostics` | Check setup | permissions | simulators |

### Task 14.0: [COMPLETED] Prototype Validation (Spike)
**Goal**: Validate MCP server + stdio transport work with Claude

**Steps**:
1. Create minimal Swift package with single "echo" tool
2. Configure in `~/.claude/claude.json`
3. Verify Claude can call the tool and receive response
4. Validate: snake_case naming, stderr logging, base64 image return

**Files**:
- `Tools/listall-mcp/Package.swift`
- `Tools/listall-mcp/Sources/listall-mcp/main.swift`

**Acceptance**: Claude successfully calls tool and receives response

### Task 14.1: [COMPLETED] Simulator Screenshot & Launch
**Goal**: Claude can launch and screenshot iOS/iPad/Watch apps

**Steps**:
1. Implement `listall_list_simulators` (wraps `simctl list devices -j`)
2. Implement `listall_boot_simulator` (wraps `simctl boot`)
3. Implement `listall_launch` for simulators (simctl install + launch)
4. Implement `listall_screenshot` for simulators (simctl io screenshot)
5. Return screenshot as base64 PNG

**Files**:
- `Tools/listall-mcp/Sources/listall-mcp/Tools/SimulatorTools.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Tools/ScreenshotTool.swift`

**Acceptance**: Claude can boot iPhone simulator, launch ListAll, take screenshot

### Task 14.2: [COMPLETED] macOS Screenshot & Launch
**Goal**: Claude can launch and screenshot macOS app

**Steps**:
1. Implement `listall_launch` for macOS (`open -a ListAllMac`)
2. Implement `listall_screenshot` for macOS (ScreenCaptureKit)
3. Implement permission check with clear error messages
4. Return screenshot as base64 PNG

**Permissions** (one-time manual grant):
- Screen Recording: System Settings > Privacy & Security > Screen Recording

**Files**:
- `Tools/listall-mcp/Sources/listall-mcp/Tools/MacOSTools.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Permissions.swift`

**Acceptance**: Claude can launch ListAllMac and take screenshot (after permission grant)

### Task 14.3: [COMPLETED] macOS Interaction Tools
**Goal**: Claude can interact with macOS app via Accessibility API

**Steps**:
1. Implement `listall_click` for macOS (AXUIElement performAction)
2. Implement `listall_type` for macOS (AXUIElement setValue)
3. Implement `listall_swipe` for macOS (AXUIElement scroll/drag)
4. Implement `listall_query` for macOS (list elements by accessibility ID)
5. Implement permission check for Accessibility

**Permissions** (one-time manual grant):
- Accessibility: System Settings > Privacy & Security > Accessibility

**Files**:
- `Tools/listall-mcp/Sources/listall-mcp/Services/AccessibilityService.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Tools/ClickTool.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Tools/TypeTool.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Tools/SwipeTool.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Tools/QueryTool.swift`

**Acceptance**: Claude can click buttons, type text, swipe on macOS app

### Task 14.4: [COMPLETED] Simulator Interaction Tools (XCUITest Bridge)
**Goal**: Claude can interact with simulator apps via XCUITest

**Architecture**:
1. MCP server writes command to temp file
2. MCP server invokes `xcodebuild test-without-building` for specific test
3. XCUITest reads command, executes, writes result
4. MCP server reads result and returns to Claude

**Steps**:
1. Added `MCPCommandRunner.swift` to existing `ListAllUITests` target (uses synchronized file groups)
2. Implement `MCPCommandRunner` XCUITest that reads commands from file
3. Implement click, type, swipe, query actions in XCUITest
4. Wire MCP tools to invoke XCUITest via xcodebuild
5. Pre-build test target for faster execution

**Performance**: ~5-15s per interaction (acceptable for verification loop)

**Files**:
- `ListAll/ListAllUITests/MCPCommandRunner.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Tools/InteractionTools.swift` (updated)

**Acceptance**: Claude can click, type, swipe on iOS/iPad/Watch simulator apps

### Task 14.5: [COMPLETED] Diagnostics & Error Handling
**Goal**: Clear diagnostics and actionable error messages

**Steps**:
1. Implement `listall_diagnostics` tool
2. Check: Accessibility permission, Screen Recording permission
3. Check: Available simulators, booted simulators
4. Check: Built app bundles exist
5. Return actionable guidance for any issues

**Files**:
- `Tools/listall-mcp/Sources/listall-mcp/Tools/DiagnosticsTool.swift`

**Acceptance**: Claude can diagnose issues and guide user to fix them

### Task 14.6: [COMPLETED] Integration & Documentation
**Goal**: Complete integration and create setup guide

**Steps**:
1. Build release binary: `swift build -c release`
2. Pre-build XCUITest target: `xcodebuild build-for-testing`
3. Configure `~/.claude/claude.json`
4. Test full workflow on all platforms
5. Create comprehensive setup guide

**Configuration** (`~/.claude/claude.json`):
```json
{
  "mcpServers": {
    "listall": {
      "command": "/Users/aleksi/source/listall/Tools/listall-mcp/.build/release/listall-mcp"
    }
  }
}
```

**Files**:
- `documentation/guides/MCP_VISUAL_VERIFICATION.md`

**Acceptance**: End-to-end verification loop works for all platforms

### Task 14.7: [COMPLETED] Visual Verification Skill
**Goal**: Create skill that teaches Claude when/how to use visual verification

**File**: `.claude/skills/visual-verification/SKILL.md`

**Acceptance**: Claude automatically uses visual verification after UI changes

### Task 14.8: [COMPLETED] Update CLAUDE.md
**Goal**: Add mandatory visual verification rule to project instructions

**Acceptance**: CLAUDE.md includes visual verification in mandatory rules

### Task 14.9: [COMPLETED] Update Agent Definitions
**Goal**: Add visual-verification skill to relevant agents

**Files**:
- `.claude/agents/apple-dev-expert.md` - Add skill
- `.claude/agents/testing-specialist.md` - Add skill

**Acceptance**: Relevant agents include visual-verification skill

### Performance Expectations

| Operation | macOS | Simulators |
|-----------|-------|------------|
| Screenshot | ~500ms | ~1s |
| Click | ~100ms | ~5-10s |
| Type | ~200ms | ~5-10s |
| Swipe | ~300ms | ~5-10s |
| Query | ~200ms | ~5-10s |

### File Structure

```
Tools/
└── listall-mcp/
    ├── Package.swift
    ├── Sources/
    │   └── listall-mcp/
    │       ├── main.swift
    │       ├── Permissions.swift
    │       ├── Services/
    │       │   ├── AccessibilityService.swift
    │       │   └── XCUITestBridge.swift
    │       └── Tools/
    │           ├── ScreenshotTool.swift
    │           ├── LaunchTool.swift
    │           ├── ClickTool.swift
    │           ├── TypeTool.swift
    │           ├── SwipeTool.swift
    │           ├── QueryTool.swift
    │           ├── SimulatorTools.swift
    │           └── DiagnosticsTool.swift
    └── Tests/

ListAll/
└── ListAllMCPTests/
    ├── MCPCommandRunner.swift
    └── Info.plist
```

### Dependencies

- `modelcontextprotocol/swift-sdk` (0.10.2+)
- macOS 14.0+
- Xcode 16+

---

## Phase 15: App Store Submission

### Task 15.1: Submit to App Store
**TDD**: Submission verification

**Steps**:
1. Run full test suite
2. Build release version
3. Submit for review via:
   ```bash
   bundle exec fastlane release_mac version:1.0.0
   ```

---

## Phase 16: Spotlight Integration (Optional)

### Task 16.1: Implement Spotlight Integration
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
| Phase 15: App Store Submission | Not Started | 0/1 |
| Phase 16: Spotlight Integration | Optional | 0/1 |

**Total Tasks: 93** (91 completed, 2 remaining)

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

**Phase 14 Status** (Visual Verification MCP Server):
- Task 14.0: [COMPLETED] Prototype Validation (Spike)
- Task 14.1: [COMPLETED] Simulator Screenshot & Launch
- Task 14.2: [COMPLETED] macOS Screenshot & Launch
- Task 14.3: [COMPLETED] macOS Interaction Tools
- Task 14.4: [COMPLETED] Simulator Interaction Tools (XCUITest Bridge)
- Task 14.5: [COMPLETED] Diagnostics & Error Handling
- Task 14.6: [COMPLETED] Integration & Documentation
- Task 14.7: [COMPLETED] Visual Verification Skill
- Task 14.8: [COMPLETED] Update CLAUDE.md
- Task 14.9: [COMPLETED] Update Agent Definitions

**Phase 15 Status**:
- Task 15.1: Submit to App Store

**Phase 16 Status** (Optional):
- Task 16.1: Implement Spotlight Integration

**Notes**:
- Phase 12 added based on agent swarm UX research (January 2026)
- Phase 13 added based on agent swarm investigation (January 2026) - discovered missing restore UI and mutable archived lists bugs
- Phase 14 revised (January 2026): Visual Verification MCP Server with 10 tasks - includes spike validation, XCUITest bridge for simulators, and Claude self-instruction skills
- Task 6.4 (Spotlight Integration) moved to Phase 16 as optional feature (disabled by default)
- Phase 9 revised based on swarm analysis: uses parallel jobs architecture (Task 9.0 added as blocking pre-requisite)
- Task 11.7 added comprehensive feature parity analysis with `/documentation/FEATURES.md`
