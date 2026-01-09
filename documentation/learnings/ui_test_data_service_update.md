# UITestDataService Update for UI Test Isolation Pattern

## Summary

Updated `UITestDataService` to support the new UI test isolation pattern that uses separate SQLite databases for UI tests. The service now works consistently across iOS, watchOS, and macOS platforms.

## Changes Made

### 1. Added `isUsingIsolatedDatabase` Property

**Location**: `/Users/aleksi/source/ListAllApp/ListAll/ListAll/Services/UITestDataService.swift`

Added a new static property to detect when the app is using an isolated test database:

```swift
/// Check if we're using an isolated test database
/// UI tests use a separate SQLite file (ListAll-UITests.sqlite) to isolate test data
/// from production data. Unit tests use in-memory stores.
static var isUsingIsolatedDatabase: Bool {
    // UI tests use isolated database via UITEST_MODE launch argument
    if isUITesting {
        return true
    }
    // Unit tests use in-memory store via XCTestConfigurationFilePath environment variable
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
        return true
    }
    return false
}
```

This property returns `true` when:
- **UI Tests**: `UITEST_MODE` launch argument is present → uses `ListAll-UITests.sqlite`
- **Unit Tests**: `XCTestConfigurationFilePath` environment variable is present → uses in-memory store

### 2. Enhanced `isUITesting` Documentation

Added clearer documentation to explain that `isUITesting` detects the `UITEST_MODE` launch argument:

```swift
/// Check if the app is running in UI test mode
/// UI tests set this launch argument to trigger test data population
static var isUITesting: Bool {
    return ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
}
```

### 3. macOS App Integration

**Location**: `/Users/aleksi/source/ListAllApp/ListAll/ListAllMac/ListAllMacApp.swift`

Updated the macOS app to use `UITestDataService` for consistency across platforms:

**Before**:
```swift
guard ProcessInfo.processInfo.arguments.contains("UI_TESTING") else {
    return
}
```

**After**:
```swift
guard UITestDataService.isUITesting else {
    return
}
```

Also updated `populateTestData()` to use shared test data:

**Before**: Hard-coded simple test lists
**After**: Uses `UITestDataService.generateTestData()` for locale-aware, deterministic test data

## How the Isolation Pattern Works

### Database Selection Logic (CoreDataManager)

The database selection happens in `CoreDataManager.swift` based on these conditions:

1. **Unit Tests** (`XCTestConfigurationFilePath` set):
   - Uses **in-memory store** (`NSInMemoryStoreType`)
   - No file system access
   - No permission dialogs on macOS
   - Fresh database for each test run

2. **UI Tests** (`UITEST_MODE` launch argument):
   - Uses **separate SQLite file**: `ListAll-UITests.sqlite`
   - Stored in App Groups container: `group.io.github.chmc.ListAll`
   - Isolated from production data
   - Populated with deterministic test data via `UITestDataService.generateTestData()`

3. **Production** (neither flag set):
   - Uses **production SQLite file**: `ListAll.sqlite`
   - Stored in App Groups container
   - Syncs with CloudKit (in Release builds)
   - User's actual data

### Test Data Population

All three platforms now use the same test data service:

**iOS** (`ListAllApp.swift`):
```swift
if !ProcessInfo.processInfo.arguments.contains("SKIP_TEST_DATA") {
    let testLists = UITestDataService.generateTestData()
    // Populate data manager...
}
```

**watchOS** (`ListAllWatchApp.swift`):
- Uses `WatchUITestDataService` (separate implementation for watchOS-specific needs)
- Same pattern as iOS

**macOS** (`ListAllMacApp.swift`):
```swift
if !ProcessInfo.processInfo.arguments.contains("SKIP_TEST_DATA") {
    let testLists = UITestDataService.generateTestData()
    // Populate data manager...
}
```

## Platform Compatibility

### UITestDataService is Available On:
- ✅ **iOS app target** (`ListAll`)
- ✅ **macOS app target** (`ListAllMac`)
- ❌ **watchOS** (has separate `WatchUITestDataService`)
- ❌ **Test targets** (don't need it - tests import `@testable`)

### LocalizationManager Works On:
- ✅ **iOS** - Uses `UserDefaults` with App Groups
- ✅ **macOS** - Same shared implementation
- ✅ **watchOS** - Uses separate `WatchLocalizationManager`

## Test Data Features

### Locale-Aware Test Data

`generateTestData()` automatically detects the current locale and returns:
- **English** (`en-US`): English list names and item titles
- **Finnish** (`fi`): Finnish list names and item titles

Detection uses `LocalizationManager.shared.currentLanguage` which reads from `AppleLanguages` UserDefaults key (set by Fastlane's `localize_simulator` during screenshot generation).

### Deterministic Data

All test data is fully deterministic:
- Fixed list names and order
- Fixed item titles, quantities, descriptions, and order
- Fixed timestamps (relative to `Date()` with constant offsets)
- Fixed completion states (some items crossed out)

This ensures:
- Consistent screenshots across test runs
- Reliable UI test assertions
- Same visual appearance in all locales

## Launch Arguments Reference

### For UI Tests:
- `UITEST_MODE` - Trigger UI test mode and isolated database
- `SKIP_TEST_DATA` - Skip test data population (for empty state screenshots)
- `DISABLE_TOOLTIPS` - Hide all tooltips in screenshots
- `FORCE_LIGHT_MODE` - Force light appearance mode (iOS only)

### For Unit Tests:
- `XCTestConfigurationFilePath` - Automatically set by Xcode (triggers in-memory store)

## Verification

### Build Status
- ✅ **iOS**: Builds successfully
- ✅ **macOS**: Builds successfully
- ✅ **watchOS**: Not modified (has separate service)

### Code Changes
1. ✅ `UITestDataService.swift` - Added `isUsingIsolatedDatabase` property
2. ✅ `ListAllMacApp.swift` - Updated to use `UITestDataService`
3. ✅ Both changes maintain backward compatibility

## Testing

To test the isolated database pattern:

### iOS UI Tests
```bash
# UI test with isolated database
cd ListAll && xcodebuild test \
  -project ListAll.xcodeproj \
  -scheme ListAll \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.1' \
  -only-testing:ListAllUITests
```

### macOS UI Tests
```bash
# macOS UI test with isolated database
cd ListAll && xcodebuild test \
  -project ListAll.xcodeproj \
  -scheme ListAllMac \
  -destination 'platform=macOS' \
  -only-testing:ListAllMacUITests
```

### Unit Tests (In-Memory Store)
```bash
# iOS unit tests (in-memory store - no permission dialogs)
cd ListAll && xcodebuild test \
  -project ListAll.xcodeproj \
  -scheme ListAll \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.1' \
  -only-testing:ListAllTests

# macOS unit tests (in-memory store - no permission dialogs)
cd ListAll && xcodebuild test \
  -project ListAll.xcodeproj \
  -scheme ListAllMac \
  -destination 'platform=macOS' \
  -only-testing:ListAllMacTests
```

## Benefits of This Pattern

1. **Test Isolation**: UI tests and unit tests never touch production data
2. **No Permission Dialogs**: macOS unit tests use in-memory stores
3. **Faster Tests**: In-memory stores are faster than disk-based
4. **Deterministic**: Test data is consistent across runs
5. **Platform Consistency**: Same test data service across iOS and macOS
6. **Locale Support**: Test data automatically adapts to test locale
7. **CI/CD Friendly**: No manual intervention required

## Related Documentation

- `/Users/aleksi/source/ListAllApp/ListAll/documentation/macos_test_permission_fix.md` - Original macOS test permission fix
- `/Users/aleksi/source/ListAllApp/ListAll/ListAll/Models/CoreData/CoreDataManager.swift` - Database selection logic
- `/Users/aleksi/source/ListAllApp/ListAll/ListAll/Services/UITestDataService.swift` - Test data service implementation

## Date
2025-12-06
