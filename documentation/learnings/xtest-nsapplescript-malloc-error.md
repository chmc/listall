---
title: XCTest + NSAppleScript Memory Management Issue
date: 2025-12-19
severity: HIGH
category: macos
tags: [xctest, applescript, memory-management, integration-tests, malloc]
symptoms: ["malloc error: pointer being freed was not allocated", "Tests crash before script executes", "FSFindFolder failed with error=-43"]
root_cause: Memory management conflict between XCTest host process and NSAppleScript internal allocation
solution: Mark AppleScript tests as integration tests, skip by default, use mocks for unit tests
files_affected: [ListAllMacTests/AppleScriptTimeoutTests.swift, ListAllMac/Services/Screenshots/RealAppleScriptExecutor.swift]
related: [swift-testing-coredata-mainactor.md, macos-test-isolation-permission-dialogs.md, section8-code-fixes.md]
---

## Problem

Executing `NSAppleScript` in XCTest unit tests causes:
```
malloc: *** error for object 0x29a36a8a0: pointer being freed was not allocated
```

Crashes test runner repeatedly.

## Root Cause

Memory management conflict between:
1. XCTest's test host process management
2. NSAppleScript's internal memory allocation (via FSFindFolder)
3. Test bundle initialization

Error occurs at consistent address, indicating systematic issue with how XCTest hosts AppleScript execution.

## Solution

Mark AppleScript execution tests as integration tests:

```swift
private var shouldRunIntegrationTests: Bool {
    ProcessInfo.processInfo.environment["ENABLE_APPLESCRIPT_INTEGRATION_TESTS"] == "1"
}

private func skipIfIntegrationTestsDisabled() throws {
    try XCTSkipUnless(shouldRunIntegrationTests,
        "AppleScript integration tests disabled. Set ENABLE_APPLESCRIPT_INTEGRATION_TESTS=1 to run.")
}
```

## Best Practices

1. Unit tests should not execute real AppleScript - use mocks
2. Test AppleScript generation logic separately - string output can be unit tested
3. Test error detection with fake stderr - TCCErrorDetector tests don't need real scripts

## Running Integration Tests

```bash
ENABLE_APPLESCRIPT_INTEGRATION_TESTS=1 xcodebuild test \
  -only-testing:ListAllMacTests/AppleScriptTimeoutTests ...
```
