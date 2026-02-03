# MCP Tool Performance & Reliability Improvement Plan

## Executive Summary

Research identified fundamental architectural bottlenecks in the iOS MCP tooling that cause 5-15s per interaction. Critical review revealed that the original persistent XCUITest runner approach has significant risks due to Apple design constraints.

Revised approach: Evaluate existing solutions (idb) before building custom, implement low-risk improvements (retry logic, batching) first.

---

## Critical Review Findings

| Issue | Severity | Finding |
|-------|----------|---------|
| XCUITest timeout | CRITICAL | Apple enforces 600s execution timeout; not designed for persistent operation |
| Memory leaks | CRITICAL | XCUITest leaks memory in long-running sessions |
| Existing solution | CRITICAL | InditexTech already built MCP server using idb at github.com/InditexTech/mcp-server-simulator-ios-idb |
| Performance overestimate | HIGH | 0.5s per action unrealistic; 1-3s more achievable even with optimization |

---

## Current Architecture Analysis

Why macOS is Fast (around 100ms):
- MCP Server calls AccessibilityService.swift which calls AXUIElement APIs directly
- Direct in-process Accessibility API calls, no process spawning

Why iOS is Slow (5-15s per action):
- MCP Server calls XCUITestBridge.swift
- Writes command to /tmp/listall_mcp_command.json
- Spawns xcodebuild test-without-building process
- XCUITest runner executes single action
- Writes result to /tmp/listall_mcp_result.json
- Process exits, MCP reads result

Root cause: xcodebuild process spawn overhead (around 3-5s per invocation)

---

## Ralph Loop Phases

Each phase below is designed to be run as a Ralph Loop prompt. Copy the phase content exactly.

### Progress

| Phase | Status | Date |
|-------|--------|------|
| 1A: Retry Logic | ✅ Completed | 2026-02-03 |
| 1B: idb Spike | ✅ Completed | 2026-02-03 |
| 1C: Command Batching | ⏳ Pending | - |
| 2: Decision Point | ⏳ Pending | - |

---

### PHASE 1A: Implement Retry Logic ✅ COMPLETED

TASK: Add retry logic with exponential backoff to XCUITestBridge.swift

**Status**: Completed 2026-02-03
- Added `executeWithRetry` function with exponential backoff (500ms, 1s, 2s)
- All XCUITest operations (click, type, swipe, query) now use retry wrapper
- Code compiles successfully

Read the file Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift

Add a private static function called executeWithRetry that:
- Takes maxAttempts (default 3) and an async throwing operation closure
- Loops through attempts, catching errors
- On failure, waits with exponential backoff: 500ms, 1000ms, 2000ms
- Uses Task.sleep for delays
- Throws the last error if all attempts fail

Then wrap the main XCUITest execution calls (click, type, swipe, query) with this retry logic.

FILES TO MODIFY:
- Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift

If after 3 iterations you cannot complete the task:
- Document what is blocking progress
- List approaches you have tried
- Suggest alternative solutions

WHEN COMPLETE - All criteria must be met:
- executeWithRetry function exists in XCUITestBridge.swift
- Function implements exponential backoff (500ms, 1s, 2s delays)
- At least one XCUITest operation (click or type or swipe) uses the retry wrapper
- Code compiles without errors (run: swift build in Tools/listall-mcp directory)

Output COMPLETE when all criteria are met.

---

### PHASE 1B: idb Spike Investigation ✅ COMPLETED

**Status**: Completed 2026-02-03
- idb provides coordinate-based interactions only (no identifier/label support)
- Performance: 1-3s per action (vs 5-15s current)
- Recommendation: Do NOT adopt idb - interaction model mismatch
- Findings: documentation/learnings/idb-spike-findings.md

TASK: Investigate Facebook idb as alternative backend for iOS simulator interactions

RESEARCH STEPS:
1. Check if idb-companion is installed: run which idb-companion or brew list idb-companion
2. If not installed, document installation command: brew install idb-companion
3. Search for idb documentation and capabilities online
4. Find and analyze InditexTech mcp-server-simulator-ios-idb repository on GitHub
5. Compare idb capabilities vs current XCUITest approach

DOCUMENT FINDINGS:
- Can idb do tap/click operations? How fast?
- Can idb query accessibility tree?
- Can idb type text?
- What is the architecture (companion process, gRPC, etc)?
- Does InditexTech MCP server have features we need?

Write findings to documentation/learnings/idb-spike-findings.md

If after 3 iterations you cannot complete the task:
- Document what is blocking progress
- List approaches you have tried
- Suggest alternative solutions

WHEN COMPLETE - All criteria must be met:
- Findings document exists at documentation/learnings/idb-spike-findings.md
- Document contains idb capability assessment (tap, type, query)
- Document contains performance comparison notes
- Document contains recommendation (use idb or not)

Output COMPLETE when all criteria are met.

---

### PHASE 1C: Command Batching Support

TASK: Add command batching to execute multiple actions in single XCUITest run

This reduces spawn overhead by running multiple commands per xcodebuild invocation.

IMPLEMENTATION:
1. Read Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift
2. Read ListAll/ListAllUITests/MCPCommandRunner.swift (find actual path first)
3. Modify Command struct to support array of actions
4. Modify MCPCommandRunner to loop through command array
5. Add new MCP tool or parameter for batched execution

COMMAND FORMAT (conceptual):
Instead of single action, accept commands array with multiple actions to execute sequentially.

FILES TO MODIFY:
- Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift
- ListAll/ListAllUITests/MCPCommandRunner.swift (or similar path)
- Tools/listall-mcp/Sources/listall-mcp/Tools/InteractionTools.swift (if needed)

If after 3 iterations you cannot complete the task:
- Document what is blocking progress
- List approaches you have tried
- Suggest alternative solutions

WHEN COMPLETE - All criteria must be met:
- Command struct supports multiple actions (commands array field)
- MCPCommandRunner processes array of commands in single test run
- XCUITestBridge can send batched commands
- Code compiles without errors
- Test with 3-action batch works (verify via MCP tool or unit test)

Output COMPLETE when all criteria are met.

---

### PHASE 2: Decision Point

TASK: Evaluate Phase 1 results and decide next steps

READ AND ANALYZE:
1. Check if retry logic is implemented in XCUITestBridge.swift
2. Read idb spike findings at documentation/learnings/idb-spike-findings.md
3. Check if command batching is implemented

DECISION CRITERIA:
- If idb is fast (under 2s per action) AND reliable AND has needed features: Recommend idb backend adoption
- If idb is insufficient but batching works well: Recommend continuing with XCUITest plus batching
- If neither solution is satisfactory: Recommend persistent runner prototype OR gray-box agent

Write decision and rationale to documentation/learnings/mcp-improvement-decision.md

If after 3 iterations you cannot complete the task:
- Document what is blocking progress
- List approaches you have tried
- Suggest alternative solutions

WHEN COMPLETE - All criteria must be met:
- Decision document exists at documentation/learnings/mcp-improvement-decision.md
- Document summarizes Phase 1 results (retry, idb spike, batching)
- Document contains clear recommendation with rationale
- Document outlines next steps based on decision

Output COMPLETE when all criteria are met.

---

## Performance Expectations

| Optimization | Current | Realistic Target |
|--------------|---------|------------------|
| Retry Logic | 0 percent retry | 90-95 percent success rate |
| Command Batching | 24s for 3 actions | 10-12s for 3 actions |
| idb Backend | 8s per action | 1-2s per action (if viable) |

Revised combined improvement: 4-8x faster (not 20-50x as originally estimated)

---

## Key Files Reference

| File | Purpose |
|------|---------|
| Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift | iOS simulator interaction bridge |
| Tools/listall-mcp/Sources/listall-mcp/Services/AccessibilityService.swift | macOS Accessibility API |
| ListAll/ListAllUITests/MCPCommandRunner.swift | XCUITest command runner |
| Tools/listall-mcp/Sources/listall-mcp/Tools/InteractionTools.swift | MCP interaction tools |

---

## Final Decisions Made

| Decision | Selection |
|----------|-----------|
| Investigation approach | idb spike first - evaluate before building custom |
| Scope | iOS Simulator only - watchOS later |
| Execution method | Ralph Loop phases one at a time |
