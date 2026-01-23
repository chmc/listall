<!--
Severity: MEDIUM - tools fail but workaround exists
Naming: mcp-visual-verification-runtime-fixes.md
Search: grep -l "mcp" documentation/learnings/*.md
-->
---
title: MCP Visual Verification Runtime Fixes
date: 2025-01-21
severity: MEDIUM
category: mcp
tags:
  - mcp
  - visual-verification
  - screenshot
  - api-limits
  - uitest-mode
  - simulator
symptoms:
  - API Error 400 with "image dimensions exceed max allowed size 2000 pixels"
  - iOS simulator screenshots show empty state instead of test data
  - iPad screenshots fail with invalid_request_error
root_cause: Screenshots exceeded Claude API 2000px limit; launch_args not passed for UITEST_MODE
solution: Auto-resize images to 1800px max; add launch_args parameter to listall_launch tool
files_affected:
  - Tools/listall-mcp/Sources/listall-mcp/Services/ScreenshotStorage.swift
  - Tools/listall-mcp/Sources/listall-mcp/Tools/SimulatorTools.swift
  - Tools/listall-mcp/Sources/listall-mcp/Tools/MacOSTools.swift
related:
  - none
---

## Problem

During actual usage of Phase 14 MCP visual verification tools, two runtime issues prevented successful verification: (1) iPad screenshots exceeded Claude API's 2000px image limit causing API errors, (2) iOS simulators showed empty "Welcome" state because UITEST_MODE launch argument wasn't passed.

## Root Cause

```swift
// Issue 1: No size check - iPad screenshots can be 2388x1668 or larger
let base64Image = imageData.base64EncodedString()  // Sent raw to API

// Issue 2: launch_args not supported
let launchCommand = ["launch", udid, bundleId]  // No way to pass UITEST_MODE
```

## Solution

```swift
// Fix 1: Auto-resize in ScreenshotStorage.swift
static let maxImageDimension: CGFloat = 1800
let imageData = ScreenshotStorage.resizeImageIfNeeded(rawImageData)

// Fix 2: Add launch_args to SimulatorTools.swift
var launchCommand = ["launch", udid, bundleId]
launchCommand.append(contentsOf: launchArgs)  // ["UITEST_MODE", "DISABLE_TOOLTIPS"]
```

## Prevention

- [ ] Add image dimension validation to MCP screenshot tests
- [ ] Document launch_args in tool descriptions
- [ ] Test with iPad simulators (largest screenshots) before release

## Key Insight

> MCP tools need real-world testing - API limits and app-specific requirements only surface during actual usage, not unit tests.
