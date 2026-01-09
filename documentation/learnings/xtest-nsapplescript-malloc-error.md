# Learning: XCTest + NSAppleScript Memory Management Issue

## Problem
When executing `NSAppleScript` in an XCTest unit test environment, a malloc error occurs:
```
malloc: *** error for object 0x29a36a8a0: pointer being freed was not allocated
```

This error crashes the test runner, causing tests to fail and restart repeatedly.

## Root Cause
The issue appears to be a memory management conflict between:
1. XCTest's test host process management
2. NSAppleScript's internal memory allocation (potentially through FSFindFolder)
3. The test bundle's initialization

The error occurs at a consistent memory address (`0x29a36a8a0`), suggesting it's not random but a systematic issue with how XCTest hosts AppleScript execution.

## Symptoms
- Tests crash immediately when `NSAppleScript.executeAndReturnError()` is called
- Error appears before script actually executes
- FSFindFolder errors also appear: `[foldermgr] FSFindFolder failed with error=-43`
- Affects both `NSAppleScript` and `Process` (osascript) approaches

## Solution
Mark AppleScript execution tests as **integration tests** that are skipped by default:

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

1. **Unit tests should not execute real AppleScript** - Use mocks and dependency injection
2. **Integration tests require special environment** - Document the requirement
3. **Test AppleScript generation logic separately** - String output can be unit tested
4. **Test error detection with fake stderr** - TCCErrorDetector tests don't need real scripts

## When to Run Integration Tests
Integration tests can be enabled for manual verification:
```bash
ENABLE_APPLESCRIPT_INTEGRATION_TESTS=1 xcodebuild test \
  -only-testing:ListAllMacTests/AppleScriptTimeoutTests ...
```

## Files Affected
- `ListAllMacTests/AppleScriptTimeoutTests.swift` - Added skip mechanism
- `ListAllMac/Services/Screenshots/RealAppleScriptExecutor.swift` - NSAppleScript implementation

## Date
2025-12-19
