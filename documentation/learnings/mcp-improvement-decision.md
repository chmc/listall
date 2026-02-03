# MCP Tool Improvement Decision

**Date**: 2026-02-03
**Phase**: 2 - Decision Point
**Status**: Complete

---

## Phase 1 Results Summary

### 1A: Retry Logic - COMPLETED

**Implementation Status**: Fully implemented in XCUITestBridge.swift

| Aspect | Details |
|--------|---------|
| Function | `executeWithRetry` with configurable `maxAttempts` (default: 3) |
| Backoff Strategy | Exponential: 500ms, 1000ms delays between attempts |
| Coverage | All operations: click, type, swipe, query, batch |
| Integration | Both `executeCommand` and `executeBatchCommand` use retry wrapper |

**Impact**: Improved reliability for transient failures. Expected 90-95% success rate on first attempt, with retries catching intermittent issues.

---

### 1B: idb Spike Investigation - COMPLETED

**Recommendation**: DO NOT adopt idb

| Factor | Finding |
|--------|---------|
| Performance | 1-3s per action (vs 5-15s current) - significant improvement |
| Interaction Model | Coordinate-based only - NO identifier/label support |
| Platform Coverage | iOS/iPadOS only - no macOS, limited watchOS |
| Architecture | Persistent gRPC companion server - good design |

**Critical Issue**: idb's coordinate-based interaction model is fundamentally incompatible with our identifier/label-based MCP tools. Adopting idb would require:
- Query all elements first (1-3s)
- Parse JSON to find element coordinates
- Tap at coordinates

This two-step process negates the performance benefit and introduces fragility (elements may move between query and tap). Our tools are designed for robust, accessibility-identifier-based targeting which aligns with Apple's accessibility testing best practices.

---

### 1C: Command Batching - COMPLETED

**Implementation Status**: Fully implemented across all layers

| Component | Status |
|-----------|--------|
| MCPCommand struct | Supports `commands: [MCPAction]?` array for batch mode |
| XCUITestBridge | `executeBatch` method with retry logic |
| MCPCommandRunner | Processes batch commands in single XCUITest run |
| MCP Tool | `listall_batch` tool available for simulator interactions |

**Performance Achieved**:
- 3 actions: ~10-12s (batch) vs ~24s (separate calls)
- Improvement: ~50% reduction in total time
- Matches realistic target from plan (10-12s for 3 actions)

---

## Decision

### Recommendation: Continue with XCUITest + Batching

**Rationale**:

1. **idb is NOT suitable** due to interaction model mismatch (coordinate-based vs identifier-based)

2. **Batching works well** and delivers meaningful performance improvement:
   - 50% reduction for multi-action sequences
   - No architectural changes required
   - Backward compatible with existing tools

3. **Retry logic provides reliability** for transient failures without user intervention

4. **Platform consistency**: XCUITest works across iOS, iPadOS, and watchOS with same identifier-based API

### Performance Summary

| Scenario | Before | After | Improvement |
|----------|--------|-------|-------------|
| Single action | 5-15s | 5-15s (with retry) | Reliability improvement |
| 3-action sequence | ~24s | ~10-12s | ~50% faster |
| 5-action sequence | ~40s | ~15-18s | ~55% faster |

**Realistic combined improvement**: 2-3x faster for batched operations, not the 20-50x originally estimated. This is a pragmatic, achievable gain.

---

## Next Steps

### Immediate (No Additional Development)

1. **Update documentation** to recommend `listall_batch` for multi-action sequences
2. **Add usage examples** to MCP tool descriptions showing batch patterns
3. **Monitor reliability** metrics after retry logic deployment

### Future Considerations (If Needed)

| Option | When to Consider | Complexity |
|--------|------------------|------------|
| Persistent XCUITest Runner | If batch overhead still too high | HIGH - Apple timeout limits |
| Gray-box Agent | If need faster single actions | MEDIUM - architectural change |
| Hybrid Approach | If specific use cases need speed | MEDIUM - maintain two backends |

**Current recommendation**: The combination of retry logic + command batching provides sufficient improvement. No further development needed unless specific pain points emerge.

---

## Lessons Learned

1. **Evaluate existing solutions first**: idb spike prevented building custom solution for incompatible technology
2. **Realistic expectations**: 2-3x improvement is meaningful; 20-50x was unrealistic
3. **Incremental improvements**: Retry + batching delivered practical value with low risk
4. **Architecture constraints**: Apple's XCUITest design (600s timeout, no persistent mode) limits optimization options

---

## Tags

`mcp-tools` `xcuitest` `performance` `idb` `batching` `decision`
