---
title: listall-mcp build failure with Xcode 26.6 (swift-sdk 0.10.2) and concurrent tool calls in 0.12
date: 2026-11-06
severity: HIGH
category: macos
tags:
  - mcp
  - listall-mcp
  - swift-sdk
  - xcode-26
  - swift-concurrency
  - data-race
  - rpath
  - libIndexStore
symptoms:
  - "swift build in Tools/listall-mcp fails: NetworkTransport.swift: sending 'sendContinuationResumed' risks causing data races"
  - Existing MCP binary works but cannot be rebuilt
  - After upgrading swift-sdk, tool calls run in parallel (overlapping log lines "CallTool called")
root_cause: swift-sdk 0.10.2 does not compile under Swift 6.3 region checking; swift-sdk 0.11+ handles every request in its own Task, so tool handlers that share state run concurrently
solution: Pin swift-sdk .upToNextMinor(from 0.12.1), serialize CallTool through SerialGate, migrate deprecated Tool.Content factories to plainText(_:), link libIndexStore from the selected Xcode
files_affected:
  - Tools/listall-mcp/Package.swift
  - Tools/listall-mcp/Package.resolved
  - Tools/listall-mcp/Sources/MCPHelpers/SerialGate.swift
  - Tools/listall-mcp/Sources/MCPHelpers/ToolContent.swift
  - Tools/listall-mcp/Sources/listall-mcp/main.swift
  - Tools/swift-call-graph/Package.swift
related:
  - claude-code-mcp-server-config.md
  - mcp-visual-verification-runtime-fixes.md
---

## Problem

Xcode 26.6 (Swift 6.3.3) refuses to compile swift-sdk 0.10.2 (`NetworkTransport.swift:581/812`, `#SendingRisksDataRace`). The error is in the dependency, so the MCP server could not be rebuilt. The binary built with Xcode 26.1 kept working, which hid the problem until a rebuild was needed.

## Root Cause

1. **Build**: swift-sdk 0.10.2 code is rejected by newer region-based isolation checks. 0.12.1 rewrote NetworkTransport and compiles. The upstream fix #301 on `main` is not needed and was not tagged as of 2026-11-06.
2. **Behavior change hidden behind a clean compile**: 0.10.2 awaited each request in the receive loop (`Server.swift:204`). 0.12.1 starts a `Task` per request (`Server.swift:233-237`). listall-mcp handlers assume one call at a time:
   - `ScreenshotStorage` uses `nonisolated(unsafe) static var` session state
   - `XCUITestBridge` "serial queue" does `executionQueue.async { Task { … } }`, which does not serialize, and shares `/tmp/listall_mcp_command.json` / `result.json`

```swift
// BAD - an actor alone does not serialize: it is reentrant across await
actor Gate { func run<T>(_ op: () async throws -> T) async rethrows -> T { try await op() } }

// GOOD - SerialGate queues waiters with continuations and hands the gate over
try await toolCallGate.run { /* whole CallTool handler */ }
```

3. **API**: `Tool.Content.text` now has three associated values and no defaults. `.text(_:metadata:)` and `.image(…, metadata:)` are deprecated (51 `.text` + 2 `.image` call sites).
4. **Also new in 0.12**: requests no longer run in wire order (each gets an unstructured `Task`), so a pipelined "click then screenshot" may run in either order. The server now honors `notifications/cancelled` and cancels the running handler: `Task.sleep` and the shell cancellation handler in `SimulatorTools` abort mid-operation when the user presses Esc.

## Solution

- `Package.swift`: `.upToNextMinor(from: "0.12.1")`. With 0.x versions, `from:` would accept any 0.y, and minor bumps break the API.
- `main.swift`: the whole CallTool handler runs inside `SerialGate.run`. Verified with start/done logging: without the gate three calls overlap, with the gate they alternate strictly. A call cancelled while waiting throws `CancellationError` and does not run its tool. The gate restores "one at a time", not wire order.
- `MCPHelpers/ToolContent.swift`: `Tool.Content.plainText(_:)` keeps the enum shape in one place. nil `annotations`/`_meta` are omitted from JSON, so the wire format is unchanged.
- Both manifests (listall-mcp, swift-call-graph) take libIndexStore from `DEVELOPER_DIR`, then `xcode-select -p`, and fall back to `/Applications/Xcode.app`. rpaths: the selected toolchain first, `/Applications/Xcode.app/...` second, so the binary keeps loading after the selected Xcode is removed (dyld tries rpaths in order).

## Prevention

- [ ] Before rebuilding the MCP server, back up `.build/debug/listall-mcp`. `.mcp.json` runs it from the repo; a failed build removes every `listall_*` tool.
- [ ] On dependency upgrades, diff runtime semantics (request concurrency, cancellation, defaults), not just compile errors.
- [ ] Count warnings from a clean build. An incremental build reported 17 deprecations; a clean build showed 53.
- [ ] If the rpath points to an old Xcode after `xcode-select -s`, try `swift package purge-cache` or build with `--manifest-cache none` (not verified; `otool -l .build/debug/listall-mcp | grep -A2 LC_RPATH` shows the result).
- [ ] `DEVELOPER_DIR` must point to `…/Contents/Developer`; a bare `/Applications/Foo.app` silently falls back to `/Applications/Xcode.app` (deliberately not handled).
- [ ] Keep `SerialGate` around CallTool. It is the fix, not a workaround: the XCUITest runners (`ListAllUITests/MCPCommandRunner.swift:112-113` and the watchOS runner) use fixed `/tmp/listall_mcp_*.json` paths and run one command at a time, and `ScreenshotStorage` is only called from tool handlers. Removing or narrowing the gate brings the races back.

## Key Insight

> A dependency bump that compiles cleanly can still change concurrency semantics: check how the library dispatches your handlers.
