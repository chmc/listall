---
title: MCP Watch Interactions Failed - xctestrun Named "iphonesimulator" in Xcode 26
date: 2026-11-06
severity: MEDIUM
category: testing
tags:
  - listall-mcp
  - xctestrun
  - watchos-simulator
  - xcuitest-bridge
  - screen-recording
symptoms:
  - listall_click / listall_query on the watch simulator fail with "build-for-testing did not generate xctestrun file"
  - listall_diagnostics reports the watchOS XCUITest runner as FOUND
  - listall_screenshot_macos fails with "not found or has no visible windows" right after launch
root_cause: Xcode 26.6 names the watch scheme's file "ListAllWatch Watch App_..._iphonesimulator26.5-arm64.xctestrun", but XCUITestBridge looked for "watchsimulator" in the name
solution: Match xctestrun files by scheme-name prefix (MCPHelpers.isSimulatorXCTestRun), which also stops the iOS lookup from picking the watch file
files_affected:
  - Tools/listall-mcp/Sources/MCPHelpers/XCTestRunMatch.swift
  - Tools/listall-mcp/Sources/listall-mcp/Services/XCUITestBridge.swift
related:
  - mcp-swift-sdk-xcode-26-6-build.md
  - watchos-initial-sync-request.md
---

## Problem

Watch simulator interactions through the MCP server always failed, even right after a successful
`build-for-testing` of the watch scheme.

## Root Cause

The file's contents target `com.apple.platform.watchsimulator`, but its name uses the paired iPhone platform:

```
ListAllWatch Watch App_ListAllWatch Watch App_iphonesimulator26.5-arm64.xctestrun
```

`findXCTestRun` matched on `file.contains("watchsimulator")`, so it never found it. The iOS lookup matched
`contains("iphonesimulator")`, so it could pick the watch file depending on directory order.

## Solution

`isSimulatorXCTestRun(file, forScheme:)` requires the `"<scheme>_"` prefix, the `.xctestrun` suffix and a
simulator build. Rebuild the server (`swift build`, back up the binary first) and restart Claude Code.

## Related: macOS Screenshot False Alarm

`listall_diagnostics` reported "Screen Recording: NOT GRANTED", yet `listall_screenshot_macos` worked. The
screenshot had been sent in the same parallel batch as a UITEST_MODE launch, which quits the app first.

Fixed in the tool (2026-11-06):
- `listall_launch_macos` quits via `NSRunningApplication` and waits for termination, then waits up to 10 s for a
  window and reports "Window visible after N s" instead of "should now be visible".
- `listall_screenshot_macos` waits up to 10 s for a window before failing.
- Diagnostics report NOT GRANTED only when `CGPreflightScreenCaptureAccess()` is false; a ScreenCaptureKit error is
  shown with its domain/code (`MCPHelpers.ScreenRecordingStatus`).

See also `simulator-verification-traps.md`.

## Key Insight

> Identify build products by scheme, not by a platform word in the file name.
