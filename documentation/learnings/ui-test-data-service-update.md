---
title: UITestDataService Update for UI Test Isolation Pattern
date: 2025-12-06
severity: MEDIUM
category: testing
tags: [ui-testing, test-isolation, coredata, cross-platform, test-data]
symptoms: ["Inconsistent test data between platforms", "UI tests affecting production data"]
root_cause: Platform-specific UI test detection and data population needed standardization
solution: Add isUsingIsolatedDatabase property and standardize test data service across iOS/macOS
files_affected: [ListAll/Services/UITestDataService.swift, ListAllMac/ListAllMacApp.swift]
related: [macos-test-permission-fix.md]
---

## Problem

UI tests needed consistent, isolated databases across iOS and macOS platforms.

## Solution

### Added `isUsingIsolatedDatabase` Property

```swift
static var isUsingIsolatedDatabase: Bool {
    // UI tests use isolated database via UITEST_MODE launch argument
    if isUITesting { return true }
    // Unit tests use in-memory store via XCTestConfigurationFilePath
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return true }
    return false
}
```

### Database Selection Logic (CoreDataManager)

| Mode | Database | Storage |
|------|----------|---------|
| Unit Tests | In-memory store | `NSInMemoryStoreType` |
| UI Tests | `ListAll-UITests.sqlite` | App Groups container |
| Production | `ListAll.sqlite` | App Groups container |

### Standardized Test Data

Both iOS and macOS now use:
```swift
guard UITestDataService.isUITesting else { return }
let testLists = UITestDataService.generateTestData()
```

## Launch Arguments Reference

| Argument | Purpose |
|----------|---------|
| `UITEST_MODE` | Trigger UI test mode and isolated database |
| `SKIP_TEST_DATA` | Skip test data population (empty state screenshots) |
| `XCTestConfigurationFilePath` | Auto-set by Xcode (triggers in-memory store) |

## Benefits

1. Test isolation - UI/unit tests never touch production data
2. No permission dialogs - macOS unit tests use in-memory stores
3. Faster tests - in-memory stores
4. Deterministic - consistent test data across runs
5. Locale support - test data adapts to test locale
6. CI/CD friendly - no manual intervention
