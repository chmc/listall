---
title: ScreenshotOrchestrator Integration Tests TDD
date: 2025-12-20
severity: MEDIUM
category: macos
tags: [tdd, integration-tests, screenshot-orchestrator, swift-concurrency, error-handling]
symptoms: ["malloc error during test cleanup", "Swift 6 concurrency crashes", "Type organization issues"]
root_cause: Swift 6 concurrency settings caused memory management issues in test cleanup
solution: Disable Swift 6 concurrency features for Debug builds; proper type organization
files_affected: [ListAllMacTests/MacSnapshotIntegrationTests.swift, ListAllMac/Services/Screenshots/ScreenshotOrchestrator.swift, ListAll.xcodeproj/project.pbxproj]
related: [phase2-cycle2-screenshot-validation-tdd.md, phase4-e2e-refactoring.md]
---

## Problem

Create ScreenshotOrchestrator to coordinate screenshot flow:
- Hide apps -> capture -> validate
- Convert AppleScript errors to user-friendly ScreenshotErrors
- Retry logic for transient failures (NOT for TCC errors)

## TDD Process

### RED Phase
Created 20 integration tests covering full flow, TCC failures, timeout handling, retry logic, error propagation, and multiple captures.

### GREEN Phase
Implemented orchestrator with dependency injection for all components.

## Issues Encountered

### Swift 6 Concurrency Crashes

```
malloc: *** error for object 0x29a36a8c0: pointer being freed was not allocated
```

**Cause:** Swift 6 concurrency settings caused memory issues:
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

**Fix:** Disabled these settings for Debug builds and test targets.

### Type Organization

**Problem:** ScreenshotResult defined in wrong file.
**Fix:** Moved to ScreenshotTypes.swift with all other production types.

## Error Conversion Rules

| AppleScriptError | Converted To | Retry? |
|-----------------|--------------|--------|
| .permissionDenied | ScreenshotError.tccPermissionRequired | NO |
| .timeout | Propagate as-is | NO |
| .executionFailed | Propagate after max retries | YES |

## Results

- 20/20 integration tests passing
- Test execution: ~0.009 seconds
- 71/71 total tests passing

## Key Learnings

1. **Swift 6 Concurrency** - Experimental features can break test infrastructure
2. **Type Organization** - Production types belong in dedicated files
3. **Dependency Injection** - Critical for testability
4. **Error Messages** - Every error needs actionable guidance
