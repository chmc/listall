# MCP Tool Performance & Reliability Improvement Plan

## Executive Summary

Research identified **fundamental architectural bottlenecks** in the iOS MCP tooling that cause 5-15s per interaction. Critical review revealed that the original "persistent XCUITest runner" approach has significant risks due to Apple's design constraints.

**Revised approach**: Evaluate existing solutions (idb) before building custom, implement low-risk improvements (retry logic, batching) first.

---

## Critical Review Findings

Three independent critics identified these issues with the original plan:

| Issue | Severity | Finding |
|-------|----------|---------|
| XCUITest timeout | CRITICAL | Apple enforces 600s execution timeout; not designed for persistent operation |
| Memory leaks | CRITICAL | XCUITest leaks memory in long-running sessions |
| Existing solution | CRITICAL | InditexTech already built MCP server using idb: `github.com/InditexTech/mcp-server-simulator-ios-idb` |
| Performance overestimate | HIGH | 0.5s/action unrealistic; 1-3s more achievable even with optimization |
| Socket IPC complexity | MEDIUM | Adds complexity for marginal 90ms gain vs file-based |
| Missing failure modes | MEDIUM | Plan didn't address runner crash, app hang, zombie processes |

---

## Current Architecture Analysis

### Why macOS is Fast (~100ms)
```
MCP Server → AccessibilityService.swift → AXUIElement APIs → Immediate response
```
- Direct in-process Accessibility API calls
- No process spawning

### Why iOS is Slow (5-15s per action)
```
MCP Server → XCUITestBridge.swift
  → Write command to /tmp/listall_mcp_command.json
  → Spawn: xcodebuild test-without-building ...
  → XCUITest runner executes single action
  → Writes result to /tmp/listall_mcp_result.json
  → Process exits
  → MCP reads result
```

**Root cause**: xcodebuild process spawn overhead (~3-5s per invocation)

---

## Revised Implementation Plan

### Phase 1: Immediate Improvements (Low risk, high value)

#### 1.1 Retry Logic with Exponential Backoff
**Risk**: Low | **Effort**: 4-8 hours | **Impact**: Reliability improvement

```swift
// XCUITestBridge.swift - add retry wrapper
private static func executeWithRetry<T>(
    maxAttempts: Int = 3,
    operation: () async throws -> T
) async throws -> T {
    var lastError: Error?
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            if attempt < maxAttempts {
                let delay = UInt64(pow(2.0, Double(attempt - 1)) * 500_000_000)
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }
    throw lastError!
}
```

#### 1.2 Command Batching
**Risk**: Low | **Effort**: 8-16 hours | **Impact**: 3-5x faster for multi-step workflows

Accept array of commands, execute in single XCUITest run:
```swift
{
  "commands": [
    { "action": "click", "identifier": "button1" },
    { "action": "type", "text": "hello" },
    { "action": "click", "identifier": "submit" }
  ]
}
```

This works WITH XCUITest's design (single test execution with multiple actions).

### Phase 2: Investigation Required

#### 2.1 Evaluate Facebook idb (SPIKE REQUIRED)
**Risk**: Unknown | **Effort**: 4-8 hours investigation | **Impact**: Potentially replaces XCUITest entirely

**Why idb might be better:**
- Persistent companion process per simulator (already solved the spawn problem)
- gRPC communication (low latency)
- Direct accessibility tree access
- Input injection without XCUITest
- Battle-tested at Facebook scale

**Spike tasks:**
1. Install idb: `brew install idb-companion`
2. Test basic operations: `idb describe`, `idb tap`, `idb accessibility_info`
3. Measure performance vs current XCUITest approach
4. Evaluate InditexTech's MCP server: `github.com/InditexTech/mcp-server-simulator-ios-idb`

#### 2.2 Persistent Runner Prototype (PROTOTYPE FIRST)
**Risk**: High (Apple constraints) | **Effort**: 16-24 hours | **Impact**: Unknown

**Must answer before implementing:**
1. What happens after XCUITest runs for 10 minutes? 30 minutes?
2. Does memory grow unbounded?
3. Does the 600s timeout kill the test?

**If prototyping:**
- Start with simple 5-minute loop test
- Monitor memory consumption
- Check for test framework warnings/errors
- Measure actual achieved latency

### Phase 3: Architectural Options (Choose one after Phase 2)

#### Option A: Use idb Backend
Replace XCUITestBridge with idb calls:
```
MCP Server → idb companion (persistent) → Simulator
```
**Pros**: Already solved, maintained by Meta
**Cons**: Additional dependency, may not support all features

#### Option B: Persistent XCUITest (if proven viable)
Keep runner alive with session-based loop:
```
MCP Server → Running XCUITest process → Command polling
```
**Pros**: Full control, no external deps
**Cons**: Fights Apple's design, maintenance burden

#### Option C: Gray-Box Agent
Embed agent in ListAll app:
```
MCP Server → ListAll app agent → Direct execution
```
**Pros**: Fastest possible (10-50x), app-specific optimization
**Cons**: Only works for ListAll, requires app changes

---

## Revised Performance Expectations

| Optimization | Current | Realistic Target | Notes |
|--------------|---------|------------------|-------|
| Retry Logic | 0% retry | 90-95% success | Handles transient failures |
| Command Batching | 24s (3 actions) | 10-12s | Single spawn for multiple actions |
| idb Backend | 8s/action | 1-2s/action | Pending investigation |
| Persistent Runner | 8s/action | 2-4s/action | If feasible |

**Revised combined improvement**: 4-8x faster (not 20-50x as originally claimed)

---

## Files to Modify

### Phase 1

| File | Changes |
|------|---------|
| `Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift` | Add retry logic, batch command support |
| `ListAll/ListAllUITests/MCPCommandRunner.swift` | Handle batch commands |
| `ListAllWatch Watch App/ListAllWatch Watch AppUITests/MCPCommandRunner.swift` | Handle batch commands (both iOS and watchOS) |

### Phase 2+ (After investigation)

Depends on chosen approach (idb vs persistent runner vs gray-box).

---

## Final Decisions

| Decision | Selection |
|----------|-----------|
| Investigation approach | **idb spike first** - evaluate before building custom |
| Scope | **iOS Simulator only** - watchOS later |
| Phase 1 | Retry logic + batching (approved) |

---

## Implementation Order (Final)

```
Phase 1A - Reliability (can start immediately):
└── Implement retry logic in XCUITestBridge.swift

Phase 1B - idb Spike (parallel with 1A):
├── Install idb: brew install idb-companion
├── Test: idb tap, idb accessibility_info
├── Measure performance vs XCUITest
├── Evaluate InditexTech's mcp-server-simulator-ios-idb
└── Document findings

Phase 1C - Batching (after 1A):
└── Add batch command support to MCPCommandRunner

Decision Point (after Phase 1 complete):
├── If idb fast + reliable → Adopt idb backend
├── If idb insufficient → Consider persistent runner prototype
└── If neither viable → Continue with batching improvements only
```

---

## Verification Plan

1. **Benchmark baseline**: Measure 10-action workflow time before changes
2. **Test retry logic**: Run 100 iterations, measure success rate improvement
3. **Test batching**: Measure 3-action workflow before/after
4. **idb spike**: Document findings, performance measurements
5. **Final benchmark**: Compare against baseline

---

## Next Steps After Approval

1. **Immediate**: Implement retry logic in `XCUITestBridge.swift`
2. **Parallel**: Run idb spike (install, test basic operations, measure)
3. **Then**: Implement command batching
4. **Decision**: Choose Phase 3 direction based on spike results
