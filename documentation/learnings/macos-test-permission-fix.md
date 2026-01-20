---
title: macOS Unit Test Permission Dialog Fix via In-Memory Store
date: 2026-01-20
severity: HIGH
category: macos
tags: [testing, permission-dialogs, coredata, in-memory-store, ci-cd]
symptoms: ["ListAllMac.app wants to access other apps data dialog", "Tests cannot run automatically", "Dialog appears on every test run"]
root_cause: CoreDataManager singleton accesses App Groups container, triggering sandbox prompts for unsigned test builds
solution: Detect test environment via XCTestConfigurationFilePath and use in-memory Core Data store
files_affected: [ListAll/Models/CoreData/CoreDataManager.swift]
related: [macos-app-groups-test-dialogs.md, macos-test-isolation-permission-dialogs.md]
---

## Problem

`xcodebuild test` triggers permission dialog on every run because:
1. `CoreDataManager.shared` accesses App Groups container during initialization
2. Each test run creates new unsigned test bundle with different identity
3. macOS sandbox detects unsigned code accessing App Groups and prompts

## Solution: Automatic Test Environment Detection

```swift
lazy var persistentContainer: NSPersistentContainer = {
    let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    if isTestEnvironment {
        let container = NSPersistentContainer(name: "ListAll")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Failed to load in-memory store: \(error)")
            }
        }
        return container
    }
    // Production code with App Groups access...
}
```

## How It Works

1. XCTest sets `XCTestConfigurationFilePath` environment variable
2. In-memory store (`NSInMemoryStoreType`) bypasses file system
3. No App Groups access = no permission dialogs
4. Zero changes required in test code
5. Production builds unchanged

## Benefits

- No permission dialogs
- Faster tests (in-memory vs disk)
- Test isolation (fresh database each run)
- CI/CD compatible (no manual intervention)
- Zero test code changes needed

## Verification

```bash
xcodebuild test -project ListAll.xcodeproj -scheme ListAllMac -destination 'platform=macOS'
```

All tests pass without permission dialogs.
