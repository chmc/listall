# MCP Visual Verification: Stuck Detection and Timeout Implementation

**Date**: 2026-01-23
**Tags**: mcp, timeout, concurrency, swift, xcuitest, process-management

## Problem Summary

Two issues with MCP visual verification:

1. **Stuck Detection**: `process.waitUntilExit()` had NO timeout. If xcodebuild hangs, the MCP server blocks indefinitely.

2. **Screenshot Folder Naming**: `sanitizeContext()` only stripped platform **prefixes** (`macos-...`), not **suffixes** (`...-macos`), causing inconsistent folder names.

## Solution

### Fix 1: Screenshot Folder Naming

**File**: `Tools/listall-mcp/Sources/listall-mcp/Services/ScreenshotStorage.swift`

Updated `sanitizeContext()` to:
- Strip ALL platform prefixes (loops until none remain)
- Strip ALL platform suffixes (loops until none remain)
- Return "screenshot" for empty results or bare platform names

**Edge cases handled:**
- `"macos"` → `"screenshot"` (bare platform)
- `"-macos"` → `"screenshot"` (empty after strip)
- `"macos-button-macos"` → `"button"` (both stripped)
- `"ios-macos-feature-iphone-watch"` → `"feature"` (all platforms stripped)

### Fix 2: Timeout-Enabled Shell Execution

**Files Modified:**
- `Tools/listall-mcp/Sources/listall-mcp/Tools/SimulatorTools.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift`

**Key Components:**

1. **ProcessExecutionState Class**: Thread-safe state wrapper using `@unchecked Sendable` to avoid Swift concurrency warnings with `DispatchWorkItem`.

2. **Timeout Watchdog**: Uses `DispatchQueue.global().asyncAfter()` with `DispatchWorkItem` for cancellable timeout.

3. **Process Termination Strategy**:
   - SIGTERM first (graceful shutdown)
   - Wait 2 seconds
   - SIGKILL if still running (force kill)
   - `process.waitUntilExit()` to reap zombie

4. **Serial Execution Queue**: Prevents race conditions on shared temp files (`/tmp/listall_mcp_command.json`, `/tmp/listall_mcp_result.json`).

**Timeout Values:**
| Operation | Timeout | Rationale |
|-----------|---------|-----------|
| XCUITest (click/type/swipe) | 90s | Normal: 5-15s, first-run compile: 30-60s |
| XCUITest (query) | 120s | Large element trees + potential compile |
| simctl commands | 30s | Boot/shutdown typically < 10s |

## Implementation Patterns

### Thread-Safe State for Process Execution

```swift
private final class ProcessExecutionState: @unchecked Sendable {
    private let lock = NSLock()
    private var _didResume = false
    private var _timeoutWork: DispatchWorkItem?

    func setResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _didResume { return false }
        _didResume = true
        return true
    }
    // ... other methods
}
```

### Serial Queue for XCUITest Commands

```swift
private static let executionQueue = DispatchQueue(label: "io.listall.xcuitest.bridge")

static func executeCommand(...) async throws -> Result {
    try await withCheckedThrowingContinuation { continuation in
        executionQueue.async {
            Task {
                // Execute command within serial queue
            }
        }
    }
}
```

### Error with Recovery Instructions

```swift
case .operationTimedOut(let action, let timeout):
    return """
        XCUITest '\(action)' timed out after \(Int(timeout))s.
        The simulator may be unresponsive. Recovery steps:
        1. Run listall_screenshot to check simulator state
        2. Run listall_shutdown_simulator(udid: "all") to stop simulators
        3. Run listall_boot_simulator to restart
        4. Retry the operation
        """
```

## Why Serial Queue Over UUID-Based Temp Files

| Approach | Pros | Cons |
|----------|------|------|
| **Serial Queue** | No MCPCommandRunner changes, no IPC protocol changes, simplest | No parallel execution |
| UUID Temp Files | Allows parallel | Complex IPC, MCPCommandRunner changes, more failure modes |

Serial queue wins because XCUITest commands would conflict on the simulator anyway - parallel execution isn't useful for UI automation.

## Verification

After Claude Code restart (to load new MCP binary):

1. **Screenshot naming**: `"test-macos"` → folder `YYMMDD-HHMMSS-test`
2. **Timeout**: Commands complete in ~10s normally
3. **Timeout recovery**: If simulator hangs, timeout at 90s with recovery instructions
4. **Serial execution**: Rapid sequential commands work without race conditions

## Related Files

- `Tools/listall-mcp/Sources/listall-mcp/Services/ScreenshotStorage.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Tools/SimulatorTools.swift`
- `Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift`
