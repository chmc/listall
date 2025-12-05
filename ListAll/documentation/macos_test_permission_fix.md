# macOS Unit Test Permission Dialog Fix

## Problem

When running `xcodebuild test` for the ListAllMac scheme, a macOS permission dialog appeared repeatedly:
- **Dialog**: "ListAllMac.app haluaa käyttää muiden appien tietoja" (ListAllMac.app wants to access other apps' data)
- **Frequency**: Appeared on every test run, even after clicking "Allow"
- **Impact**: Tests could not run automatically in CI/CD or locally without manual intervention

## Root Cause

The permission dialog was triggered because:

1. **App Groups Access During Tests**: `CoreDataManager.shared` singleton accessed App Groups container (`group.io.github.chmc.ListAll`) during initialization
2. **Unsigned Test Builds**: Each test run created a new unsigned test bundle with a different identity
3. **macOS Sandboxing**: macOS sandbox security detected unsigned code accessing App Groups and prompted for permission
4. **Transitive Initialization**: Even tests that didn't directly use CoreDataManager triggered initialization through singleton pattern

### Code Path That Triggered Permission Dialog

```
Test starts
    ↓
@testable import ListAllMac (imports all internal code)
    ↓
Test accesses any singleton (ImageService.shared, DataManager.shared, etc.)
    ↓
CoreDataManager.shared.persistentContainer accessed
    ↓
FileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.io.github.chmc.ListAll")
    ↓
⚠️ PERMISSION DIALOG: "wants to access other apps' data"
```

## Solution

### Implementation: Automatic Test Environment Detection

Modified `CoreDataManager.swift` to automatically detect test environment and use an in-memory Core Data store:

```swift
lazy var persistentContainer: NSPersistentContainer = {
    // CRITICAL: Check if running in test environment - use in-memory store to avoid permission dialogs
    let isTestEnvironment = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    if isTestEnvironment {
        print("🧪 CoreDataManager: Test environment detected - using IN-MEMORY store")
        let container = NSPersistentContainer(name: "ListAll")

        // Configure in-memory store for tests
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.url = URL(fileURLWithPath: "/dev/null")
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Failed to load in-memory store: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }

    // ... production code continues with App Groups access ...
}
```

### How It Works

1. **Test Detection**: XCTest automatically sets `XCTestConfigurationFilePath` environment variable when running tests
2. **In-Memory Store**: Tests use `NSInMemoryStoreType` which doesn't access the file system
3. **No App Groups Access**: In-memory store bypasses App Groups container access entirely
4. **Zero Code Changes in Tests**: Tests continue working without modification
5. **Production Unchanged**: Production builds still use App Groups and persistent storage

### Benefits

- ✅ **No Permission Dialogs**: Tests never trigger file system access
- ✅ **Faster Tests**: In-memory store is faster than disk-based store
- ✅ **Test Isolation**: Each test run gets a fresh, isolated database
- ✅ **Zero Test Changes**: Existing tests work without modification
- ✅ **CI/CD Compatible**: Tests run automatically without manual intervention
- ✅ **Clean Separation**: Test and production environments are completely isolated

## Verification

All unit tests now pass without permission dialogs:

```bash
xcodebuild test -project ListAll.xcodeproj -scheme ListAllMac -destination 'platform=macOS'
```

### Test Results

- ✅ **ListAllMacTests**: Core Data entity tests (in-memory store)
- ✅ **DataModelTests**: Data model tests (no file access)
- ✅ **ImageServiceTests**: Image processing tests (no file access)
- ✅ **MacBiometricAuthServiceTests**: Biometric auth tests (no file access)
- ✅ **DataRepositoryValidationTests**: Validation logic tests (no file access)

**All tests pass without any permission dialogs appearing.**

## Alternative Approaches Considered

### 1. Test Entitlements File (Not Used)

Created `ListAllMacTests/ListAllMacTests.entitlements` with App Groups access:
- **Pros**: Would grant test bundle access to App Groups
- **Cons**: Still requires proper code signing; doesn't work for unsigned builds
- **Status**: Created but not needed with in-memory store approach

### 2. Dependency Injection (Not Used)

Refactor singletons to accept injected dependencies:
- **Pros**: Better testability, more flexible architecture
- **Cons**: Requires significant code changes across entire codebase
- **Status**: Too invasive for this issue

### 3. Environment Variable Flag (Implemented)

Use `XCTestConfigurationFilePath` to detect test environment:
- **Pros**: Automatic detection, no code changes in tests, clean separation
- **Cons**: Relies on XCTest setting environment variable (reliable)
- **Status**: ✅ **Chosen solution - works perfectly**

## Related Files

### Modified Files
- `/Users/aleksi/source/ListAllApp/ListAll/ListAll/Models/CoreData/CoreDataManager.swift`
  - Added test environment detection
  - Added in-memory store configuration for tests

### Created Files
- `/Users/aleksi/source/ListAllApp/ListAll/ListAllMacTests/ListAllMacTests.entitlements`
  - Optional entitlements file (not currently used)
  - Available if needed for future signed test builds

### Test Files (No Changes Required)
- `/Users/aleksi/source/ListAllApp/ListAll/ListAllMacTests/ListAllMacTests.swift`
  - No changes needed - tests work automatically

## Why This Approach is Superior

### For Testing
- **Faster**: In-memory store is faster than disk I/O
- **Isolated**: Each test run starts with clean database
- **Reliable**: No file system race conditions or permissions issues
- **Simple**: No test code changes required

### For Development
- **Zero Impact**: Production code unchanged
- **Maintainable**: Single point of change in CoreDataManager
- **Debuggable**: Clear log messages show test environment detection
- **Scalable**: Works for any number of tests

### For CI/CD
- **Automated**: No manual intervention required
- **Repeatable**: Same behavior every time
- **Fast**: No file system access delays
- **Reliable**: No permission dialog interruptions

## Testing Best Practices Applied

1. **Test Isolation**: Tests use separate in-memory database
2. **No File System Access**: Tests don't depend on file system state
3. **Fast Execution**: In-memory operations are faster
4. **Clean Environment**: Fresh database for each test run
5. **Zero Side Effects**: Tests don't affect production data

## Conclusion

The permission dialog issue is **fully resolved** by detecting the test environment and using an in-memory Core Data store. This approach:
- Eliminates permission dialogs completely
- Improves test performance
- Maintains test isolation
- Requires zero changes to test code
- Follows testing best practices

All macOS unit tests now run successfully without any permission prompts.
