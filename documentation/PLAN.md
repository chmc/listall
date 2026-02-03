# watchOS MCP Tools Improvement Plan

**Date**: 2026-02-03
**Goal**: Improve watchOS MCP tools performance and reliability for better Claude-driven automation
**Status**: Revised after critical review

---

## Status Tracking Rules

Each phase has a **Status** field that must be updated:

| Status | When to Use |
|--------|-------------|
| `pending` | Phase not started yet |
| `in-progress` | Phase work has begun |
| `completed` | Phase work finished and verified |

**Rules**:
1. When starting a phase, change its status from `pending` → `in-progress`
2. When finishing a phase, change its status from `in-progress` → `completed`
3. Only one phase should be `in-progress` at a time (follow the sequence: 0 → 1 → 2 → 3 → 4 → 5 → 6)
4. Do not skip phases unless explicitly agreed

---

## Executive Summary

After extensive research including open source alternatives (idb, Appium, AskUI), the conclusion is clear: **XCUITest is the only viable option** for identifier-based watchOS automation. No open source project provides what we need.

### Key Findings

| Alternative | Status | Why Not Viable |
|-------------|--------|----------------|
| Facebook idb | Evaluated | Coordinate-based only, no identifier/label support |
| Appium | Evaluated | No watchOS driver exists |
| AskUI idb-mcp | Evaluated | iOS only, wraps idb |

### Performance Expectations

**IMPORTANT**: These are targets, not guarantees. Actual improvements depend on baseline measurements.

| Scenario | Current (estimated) | Target | Notes |
|----------|---------------------|--------|-------|
| Single action | 10-30s | TBD after baseline | xcodebuild spawn overhead irreducible |
| Batch (3 actions) | 15-18s | TBD after baseline | Single spawn amortized |
| Query | 15-30s | TBD after baseline | Element tree traversal |

**Fundamental constraint**: watchOS simulator emulation is inherently 1.5-2x slower than iOS. This cannot be changed through software.

### Known watchOS Limitations (XCUITest)

- **Digital Crown**: NOT supported - use swipe gestures instead
- **Force Touch**: NOT supported (deprecated by Apple)
- **Complications**: Limited automation support

---

## Improvement Plan

### Phase 0: Baseline Measurements (REQUIRED FIRST)
<!-- Status: pending | in-progress | completed -->
**Status**: `pending`

**Problem**: We have no actual performance data. All current estimates are assumptions.

**Actions**:
1. Create performance test script that measures:
   - Single click action (10 runs, compute mean/stddev)
   - Single query action (10 runs)
   - Batch of 3 actions (10 runs)
   - Screenshot capture (10 runs)

2. Document test environment:
   - macOS version
   - Xcode version
   - watchOS simulator version
   - Apple Silicon vs Intel

3. Run tests on booted (warm) and fresh-booted (cold) simulators

**Output**: Baseline measurements document with statistical variance

**Effort**: LOW (2-3 hours)

---

### Phase 1: Add Accessibility Identifiers (HIGH IMPACT)
<!-- Status: pending | in-progress | completed -->
**Status**: `pending`

**Problem**: watchOS views use `accessibilityLabel`/`accessibilityHint` but **ZERO** `accessibilityIdentifier` modifiers. This is a significant gap compared to iOS app.

**Effort**: HIGH (this is adding an entirely new identifier system, not just a few modifiers)

**Files to modify**:

1. `ListAll/ListAllWatch Watch App/Views/WatchListsView.swift`
   ```swift
   .accessibilityIdentifier("WatchListRow_\(list.id.uuidString)")
   .accessibilityIdentifier("WatchSyncIndicator")
   ```

2. `ListAll/ListAllWatch Watch App/Views/WatchListView.swift`
   ```swift
   .accessibilityIdentifier("WatchItemsContent")
   .accessibilityIdentifier("WatchItemCountSummary")
   ```

3. `ListAll/ListAllWatch Watch App/Views/Components/WatchItemRowView.swift`
   ```swift
   .accessibilityIdentifier("WatchItemRow_\(item.id.uuidString)")
   ```

4. `ListAll/ListAllWatch Watch App/Views/Components/WatchFilterPicker.swift`
   ```swift
   .accessibilityIdentifier("WatchFilterPicker")
   .accessibilityIdentifier("WatchFilter_\(option.rawValue)")
   ```

5. `ListAll/ListAllWatch Watch App/Views/Components/WatchListRowView.swift`
6. `ListAll/ListAllWatch Watch App/Views/Components/WatchEmptyStateView.swift`
7. `ListAll/ListAllWatch Watch App/Views/Components/WatchLoadingView.swift`

**Impact**: 20-30% faster element location, more reliable interactions

---

### Phase 2: Optimize watchOS MCPCommandRunner (MEDIUM IMPACT)
<!-- Status: pending | in-progress | completed -->
**Status**: `pending`

**File**: `ListAll/ListAllWatch Watch AppUITests/MCPCommandRunner.swift`

**Prerequisite**: Write integration tests for MCPCommandRunner BEFORE making changes (prevents silent regressions)

**Changes**:

1. **Optimized element search order** (watchOS UI is simpler):
   ```swift
   // Search buttons first (most common), then cells, then generic
   private let watchOSElementPriority: [XCUIElement.ElementType] = [
       .button, .cell, .switch, .staticText, .textField
   ]
   ```

2. **Reduce element stability wait** (0.3s for clicks vs 1.0s default):
   ```swift
   private func getStabilityTimeout(for action: String) -> TimeInterval {
       switch action {
       case "click": return 0.3
       case "type": return 0.5
       case "swipe": return 1.0
       default: return 0.5
       }
   }
   ```

3. **Reduce default query depth** from 3 to 2 (simpler UI hierarchy)
   - **Risk**: May miss deeply nested elements. Verify with baseline query results first.

4. **Reduce element limit** from 50 to 30 (faster queries)
   - **Risk**: May truncate results. Verify typical element counts first.

5. **Optional: Stop-on-error for batches**:
   ```swift
   let continueOnFailure: Bool  // default: true for backward compatibility
   ```

**Impact**: TBD - measure after implementation against Phase 0 baseline

---

### Phase 3: Timeout & Batch Improvements (MEDIUM IMPACT)
<!-- Status: pending | in-progress | completed -->
**Status**: `pending`

**File**: `Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift`

**Note**: Simplified from original plan. "Simulator warmth detection" removed due to complexity concerns (detecting simulator reboots, state machine maintenance). Keep fixed multiplier approach.

**Changes**:

1. **Action-specific timeouts** (simpler than warmth detection):
   ```swift
   func getActionTimeout(action: String, platform: SimulatorPlatform) -> TimeInterval {
       let base: TimeInterval = switch action {
           case "click": 60
           case "type": 75
           case "query": 90
           default: 90
       }
       return platform == .watchOS ? base * 1.5 : base
   }
   ```

2. **Batch size limit** for watchOS: Maximum 5 actions to stay under XCUITest 600s timeout

3. **Feature flag for rollback**:
   ```swift
   struct XCUITestBridgeConfig {
       static var useWatchOSOptimizations = true  // Can disable if issues arise
   }
   ```

**Impact**: Prevents timeout failures, enables safe rollback

---

### Phase 4: Platform-Specific Temp Files (RELIABILITY)
<!-- Status: pending | in-progress | completed -->
**Status**: `pending`

**Files**:
- `Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift`
- `ListAll/ListAllWatch Watch AppUITests/MCPCommandRunner.swift`
- `ListAll/ListAllUITests/MCPCommandRunner.swift`

**Change**: Use platform-prefixed temp files to prevent theoretical race conditions:
```swift
// watchOS
private static let commandPath = "/tmp/listall_mcp_watch_command.json"
private static let resultPath = "/tmp/listall_mcp_watch_result.json"

// iOS (existing)
private static let commandPath = "/tmp/listall_mcp_command.json"
private static let resultPath = "/tmp/listall_mcp_result.json"
```

**Impact**: Enables future parallel iOS+watchOS testing, prevents race conditions

---

### Phase 5: Enhanced Diagnostics (LOW EFFORT)
<!-- Status: pending | in-progress | completed -->
**Status**: `pending`

**File**: `Tools/listall-mcp/Sources/listall-mcp/Tools/DiagnosticsTool.swift`

**Add watchOS-specific diagnostic section**:
```
WATCHOS PERFORMANCE GUIDANCE:
  Single action: 10-30 seconds (normal)
  Batched (3 actions): 10-15 seconds total
  Screenshot: 2-5 seconds
  Query: 15-30 seconds (depends on UI complexity)

  Tips:
  - Use listall_batch for multi-action sequences
  - Add accessibilityIdentifier for 20-30% faster element location
  - Pre-boot simulator: listall_boot_simulator before interactions
```

**Impact**: Better user understanding, faster troubleshooting

---

### Phase 6: Error Messages (LOW EFFORT)
<!-- Status: pending | in-progress | completed -->
**Status**: `pending`

**Files**:
- `Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift`
- `ListAll/ListAllWatch Watch AppUITests/MCPCommandRunner.swift`

**Add watchOS-specific error messages**:
```swift
case .operationTimedOut where platform == .watchOS:
    return """
    watchOS XCUITest timed out. Recovery steps:
    1. Run listall_screenshot to check simulator state
    2. If unresponsive: listall_shutdown_simulator(udid: "all")
    3. Use listall_batch for multi-action sequences

    Note: watchOS actions take 10-30s per action (this is normal)
    """
```

**Impact**: Better debugging experience

---

## Implementation Priority

| Phase | Priority | Effort | Impact | Risk |
|-------|----------|--------|--------|------|
| 0. Baseline measurements | REQUIRED | Low | N/A | None |
| 1. Accessibility IDs | HIGH | **HIGH** | High | Low |
| 2. MCPCommandRunner opts | HIGH | Medium | Medium | Medium |
| 3. Timeout & Batch improvements | MEDIUM | Low | Medium | Low |
| 4. Temp file naming | MEDIUM | Low | Low | Low |
| 5. Diagnostics | LOW | Low | Low | None |
| 6. Error messages | LOW | Low | Low | None |

**Recommended sequence**: 0 → 1 → 2 → 3 → 4 → 5 → 6

**Critical**: Phase 0 MUST complete before any other phase to establish baseline

---

## Verification Plan

### Phase 0 Verification (Baseline)
Run performance measurements script, document results in `documentation/learnings/watchos-performance-baseline.md`

### Phase 1 Verification
1. Run `listall_query` on watchOS, verify new identifiers appear
2. Compare element finding speed against baseline

### Phase 2 Verification
1. Run existing MCPCommandRunner tests (add if missing)
2. Measure single click timing against baseline
3. Verify no regressions in element finding

### Phase 3 Verification
1. Test batch of 6 actions (should fail with max 5 limit)
2. Test batch of 5 actions (should succeed)
3. Verify feature flag disables optimizations

### Phase 4 Verification
1. Run iOS and watchOS tests SIMULTANEOUSLY
2. Verify no file conflicts or race conditions

### Phase 5-6 Verification
1. Run `listall_diagnostics`, verify watchOS section appears
2. Verify Digital Crown limitation is documented

### End-to-end test:
```bash
# 1. Get bundle ID from Info.plist first
# 2. Boot watch simulator
listall_boot_simulator(udid: "watch-udid")

# 3. Launch app (verify bundle_id from Info.plist)
listall_launch(udid: "booted", bundle_id: "ACTUAL_BUNDLE_ID", launch_args: ["UITEST_MODE"])

# 4. Query to see new identifiers
listall_query(simulator_udid: "booted", bundle_id: "...")

# 5. Batch interaction test with new identifiers
listall_batch(simulator_udid: "booted", bundle_id: "...", actions: [
    {action: "click", identifier: "WatchListRow_..."},
    {action: "click", identifier: "WatchItemRow_..."},
    {action: "click", identifier: "WatchFilterPicker"}
])

# 6. Screenshot verification
listall_screenshot(udid: "booted")
```

---

## Critical Files Summary

| File | Changes |
|------|---------|
| `ListAll/ListAllWatch Watch App/Views/*.swift` (8 files) | Add accessibility identifiers |
| `ListAll/ListAllWatch Watch AppUITests/MCPCommandRunner.swift` | Optimize element search, timeouts, temp file path |
| `ListAll/ListAllUITests/MCPCommandRunner.swift` | Update temp file path (Phase 4) |
| `Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift` | Action-specific timeouts, temp file paths, feature flags |
| `Tools/listall-mcp/Sources/listall-mcp/Tools/DiagnosticsTool.swift` | watchOS diagnostic section, limitations |
| `Tools/listall-mcp/Sources/listall-mcp/Tools/InteractionTools.swift` | Update `listall_batch` docs for watchOS |

**Bundle ID Note**: Verify actual bundle ID from `ListAll/ListAllWatch Watch App/ListAllWatch-Watch-App-Info.plist` before testing

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Performance improvements don't materialize | Medium | Medium | Phase 0 baseline first; feature flags for rollback |
| Accessibility identifiers break existing UI tests | Low | High | Coordinate naming with iOS; test before commit |
| Reduced query depth misses elements | Medium | Medium | Verify typical element counts in Phase 0 |
| Temp file changes cause new race conditions | Low | High | Test parallel iOS+watchOS thoroughly |
| watchOS behavior differs between Xcode versions | Medium | Medium | Test on current Xcode; document version |

---

## What We're NOT Doing (And Why)

1. **Not switching to idb**: Coordinate-based only, no identifier support
2. **Not using Appium**: No watchOS driver exists
3. **Not building persistent XCUITest runner**: Apple's 600s timeout makes this unreliable
4. **Not expecting iOS-level performance**: Platform constraint, not fixable in code
5. **Not implementing "simulator warmth detection"**: Too complex, fragile state machine

---

## Expected Outcomes

**Note**: Specific performance numbers TBD after Phase 0 baseline measurements.

After implementation:
- **Reliability**: Fewer timeout failures with action-specific timeouts
- **Element finding**: More reliable with explicit accessibility identifiers
- **Developer experience**: Better error messages and diagnostics
- **Batch safety**: Maximum batch size prevents XCUITest timeout failures
- **Parallel testing**: iOS and watchOS can run simultaneously (Phase 4)
- **Rollback capability**: Feature flags allow disabling optimizations if issues arise

**Success criteria**: Improvements measured against Phase 0 baseline, not estimated targets

---

## Sources

- [Facebook idb](https://github.com/facebook/idb) - Evaluated, not viable
- [AskUI idb-mcp](https://github.com/askui/idb-mcp) - iOS only MCP wrapper
- [Appium watchOS Issue #4829](https://github.com/appium/appium/issues/4829) - No watchOS driver
- [XCUITest Performance Guide](https://medium.com/@eahilendran/performance-testing-in-ios-with-xctest-9bb070669543)
