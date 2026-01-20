---
title: E2E Screenshot Tests Refactoring with Orchestrator
date: 2025-12-20
severity: MEDIUM
category: macos
tags: [ui-testing, screenshot-orchestrator, e2e-tests, linker-errors, defense-in-depth]
symptoms: ["symbol(s) not found for architecture arm64", "UI tests cannot import main app types"]
root_cause: macOS UI tests run as separate process and cannot link to main app types
solution: Copy screenshot infrastructure files to UI test target; use defense-in-depth approach
files_affected: [ListAllMacUITests/MacScreenshotTests.swift, ListAllMacUITests/RealWorkspace.swift, ListAllMacUITests/RealScreenshotCapture.swift]
related: [phase3-integration-tests-tdd.md, phase2-cycle2-screenshot-validation-tdd.md]
---

## Problem

Refactor MacScreenshotTests to use ScreenshotOrchestrator while maintaining 5 E2E tests.

## Key Challenge: UI Test Target Isolation

**Problem:** macOS UI tests run in separate process from main app:
- `@testable import ListAllMac` doesn't work for UI tests
- Types defined in ListAllMac not accessible from ListAllMacUITests
- Linker error: "symbol(s) not found for architecture arm64"

**Solution:** Copy screenshot infrastructure files (9 total) directly to ListAllMacUITests:
1. ScreenshotOrchestrator.swift
2. RealAppleScriptExecutor.swift
3. WindowCaptureStrategy.swift
4. ScreenshotValidator.swift
5. RealWorkspace.swift
6. AppleScriptProtocols.swift
7. ScreenshotTypes.swift
8. AppHidingScriptGenerator.swift
9. TCCErrorDetector.swift

## Defense in Depth Approach

Two-layer app hiding for robustness:

```swift
// Layer 1: Shell script hides apps before UI tests start
// Layer 2: Swift orchestrator in prepareWindowForScreenshot()
do {
    try orchestrator.hideBackgroundApps(excluding: ["ListAll"], timeout: 10.0)
} catch {
    print("Orchestrator failed: \(error)")
    // Fallback to shell-based hiding
}
```

## Results

- 5/5 E2E tests passing
- 100% reliability
- Total test time: ~8 minutes
- Partial integration (hideBackgroundApps only)

## Key Learnings

1. **macOS UI Tests Are Isolated** - UI tests run as separate process, cannot link to app types
2. **Defense in Depth Works** - Shell + Swift layers provide redundancy
3. **Pragmatic Integration** - Using just hideBackgroundApps() achieves goal without full refactoring
4. **Linker Errors** - Solution is including source files in UI test target, not importing from app
