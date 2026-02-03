# idb Spike Investigation Findings

**Date**: 2026-02-03
**Phase**: 1B of MCP Tool Performance Improvement Plan
**Tags**: idb, facebook, ios-simulator, mcp, performance, automation

---

## Executive Summary

Facebook's idb (iOS Development Bridge) offers promising low-level simulator automation capabilities, but **is NOT recommended** as a replacement for our XCUITest-based approach. While idb provides faster individual operations, it lacks identifier-based interactions which are essential for reliable UI automation.

---

## Installation Status

**idb-companion is NOT installed** on this system.

```bash
# Check results:
which idb-companion      # Not found
brew list idb-companion  # Not available

# To install:
brew install idb-companion
pip install fb-idb       # Python client
```

---

## idb Architecture

### Components

| Component | Role |
|-----------|------|
| **idb_companion** | gRPC server (Objective-C++) running on macOS, communicates with iOS automation APIs |
| **idb client** | Python 3.6+ CLI that connects to companion via gRPC |

### Communication Model
- gRPC over TCP or Unix Domain Sockets
- Single-target design (one companion per simulator/device)
- Native API access through FBSimulatorControl and FBDeviceControl frameworks

### Key Advantage
Unlike XCUITest bridge approaches, idb communicates directly with iOS automation APIs without test runner overhead.

---

## Capability Assessment

### Tap/Click Operations

**YES** - idb supports tap operations:
```bash
idb ui tap X Y                    # Tap at coordinates
idb ui tap 200 200 --duration 0.5 # Tap with custom duration
idb ui button HOME                # Hardware button presses
idb ui swipe X1 Y1 X2 Y2          # Swipe gestures
```

**Limitation**: Coordinate-based only, no identifier support.

### Text Input

**YES** - idb supports text input:
```bash
idb ui text "hello world"   # Type text
idb ui key KEYCODE          # Press individual keys
idb ui key-sequence         # Sequential key presses
```

**Limitation**: Types into focused element only, cannot target by identifier.

### Accessibility Tree Query

**YES** - idb can query accessibility:
```bash
idb ui describe-all        # Get entire UI hierarchy as JSON
idb ui describe-point X Y  # Hit-test at coordinates
```

**Output format**:
```json
{
  "AXFrame": "{{199, 116}, {64, 87.5}}",
  "AXUniqueId": "Wallet",
  "frame": {"y":116, "x":199, "width":64, "height":87.5},
  "role_description": "button",
  "AXLabel": "Wallet",
  "type": "Button",
  "enabled": true,
  "role": "AXButton"
}
```

---

## Performance Comparison

| Metric | Current XCUITestBridge | idb Estimated |
|--------|------------------------|---------------|
| **Single action** | 5-15 seconds | 1-3 seconds |
| **Overhead source** | xcodebuild spawn + test runner init | gRPC call + native API |
| **3-action sequence** | 15-45 seconds | 3-9 seconds |

### Why idb is Faster
1. **No test runner**: Direct API access without XCUITest framework initialization
2. **Persistent companion**: gRPC server stays running, no process spawn per action
3. **Native execution**: Simulators run native macOS code

### Why idb is NOT as Fast as macOS Accessibility
- Still requires cross-process communication (gRPC)
- iOS automation APIs have inherent latency
- Estimated 1-3s per action vs ~100ms for macOS Accessibility

---

## InditexTech MCP Server Analysis

Repository: `github.com/InditexTech/mcp-server-simulator-ios-idb`

### Features Provided
- Simulator management (boot, shutdown, list)
- App management (install, launch, terminate)
- UI interaction (tap, swipe, button)
- Screenshots and video recording
- Location simulation
- Crash log access

### Architecture
```
Natural Language → NLParser → MCPOrchestrator → IDBManager → idb CLI
```

### Critical Limitations

| Feature | InditexTech MCP | Our ListAll MCP |
|---------|----------------|-----------------|
| **Interaction model** | Coordinate-based only | Identifier/label-based |
| **Query method** | Natural language strings | Direct tool calls |
| **macOS support** | None | Full support |
| **watchOS support** | None | Full support |
| **API type** | CLI wrapper | Native APIs |

### Key Finding
InditexTech wraps idb CLI but does NOT expose programmatic accessibility query methods. Their `IDBManager.ts` has:
- NO methods for querying accessibility tree
- NO methods to interact by identifier/label
- Only coordinate-based tap/swipe methods

---

## Comparison: idb vs XCUITest for ListAll MCP

| Requirement | idb | XCUITest (current) |
|-------------|-----|--------------------|
| Click by identifier | NO | YES |
| Click by label | NO | YES |
| Type into specific field | NO | YES |
| Query accessibility tree | YES (coordinates) | YES (identifiers) |
| Performance per action | 1-3s | 5-15s |
| macOS support | NO | N/A (Accessibility API) |
| watchOS support | Partial | YES |
| Process model | Persistent gRPC | Spawn per action |

---

## Recommendation

### Decision: Do NOT adopt idb as primary backend

**Rationale**:

1. **Interaction Model Mismatch**: idb only supports coordinate-based interactions. Our MCP tools (`listall_click`, `listall_type`) rely on identifier/label-based targeting which is more robust and maintainable.

2. **Would Require Two-Step Process**: To click a button by identifier with idb:
   - Call `idb ui describe-all` to get element list
   - Parse JSON to find element with matching identifier
   - Extract coordinates
   - Call `idb ui tap X Y`

   This adds complexity and potential failure points.

3. **Platform Coverage**: idb only supports iOS/iPadOS simulators. We need macOS and watchOS support which idb doesn't provide.

4. **Architecture Philosophy**: Our identifier-based approach is more aligned with accessibility-driven testing best practices.

### Alternative Recommendations

1. **Proceed with Command Batching (Phase 1C)**: Reduce XCUITest spawn overhead by batching multiple commands per xcodebuild invocation. Expected improvement: 3 actions in ~10-12s instead of ~24s.

2. **Keep XCUITest for Identifier-Based Interaction**: XCUITest's identifier-based element finding is a feature, not a limitation.

3. **Consider Hybrid Approach Later**: If performance remains insufficient:
   - Use idb for simple coordinate-based operations where appropriate
   - Keep XCUITest for identifier-based interactions
   - Would require maintaining two codepaths

4. **Persistent XCUITest Runner (Future)**: Despite timeout concerns, investigate if a managed persistent runner with 5-minute heartbeat restarts could work.

---

## References

- [idb Official Documentation](https://fbidb.io/)
- [idb GitHub Repository](https://github.com/facebook/idb)
- [idb Architecture](https://fbidb.io/docs/architecture/)
- [idb Accessibility Commands](https://fbidb.io/docs/accessibility/)
- [InditexTech MCP Server](https://github.com/InditexTech/mcp-server-simulator-ios-idb)
