# Deterministic UI Test Data

This document describes the implementation of deterministic test data for UI testing and screenshot automation in ListAll.

## Overview

The app now supports a special UI test mode that:
- Detects when running in UI tests via launch argument
- Clears all existing data for a clean slate
- Populates deterministic, consistent test data
- Disables iCloud sync to prevent interference
- Supports both English and Finnish locales

## Implementation

### Components

1. **UITestDataService.swift** - Service that generates deterministic test data
2. **ListAllApp.swift** - Modified to detect UI test mode and populate data at launch
3. **ListAllUITests.swift** - Updated to enable test mode with launch arguments

### Launch Arguments

To enable UI test mode, pass these arguments when launching the app:

- `UITEST_MODE` - Enables deterministic test data mode
- `UITEST_SEED` (optional) - Environment variable for future extensibility

### Test Data Structure

The test data includes 4 lists with various items to showcase different app features:

#### English Data

1. **Grocery Shopping** (7 days old)
   - 6 items (2 crossed out)
   - Items have quantities and descriptions
   - Mix of active and completed items

2. **Weekend Projects** (3 days old)
   - 3 items (1 crossed out)
   - Demonstrates task management
   - Recent modifications

3. **Books to Read** (2 weeks old)
   - 3 items (1 crossed out)
   - Shows long-term lists
   - Descriptions with author names

4. **Travel Packing** (2 days old)
   - 4 items (1 crossed out)
   - Recent activity (modified 10 minutes ago)
   - Mix of quantities

#### Finnish Data

Same structure with localized content:
1. **Ruokaostokset** - Grocery shopping
2. **Viikonlopun projektit** - Weekend projects
3. **Luettavat kirjat** - Books to read
4. **Matkapakkaus** - Travel packing

### Features Demonstrated

- **Multiple lists** with different creation dates
- **Varied items** with different properties:
  - Quantities (1x, 2x, 6x, 12x)
  - Descriptions (some items have them, some don't)
  - Crossed out state (mix of active and completed)
  - Different modification times
- **Realistic timestamps** spread across different timeframes
- **Locale support** - Automatically uses appropriate language

## Usage in UI Tests

### Basic Setup

```swift
override func setUpWithError() throws {
    continueAfterFailure = false
    
    app = XCUIApplication()
    
    // Enable UI test mode with deterministic data
    app.launchArguments.append("UITEST_MODE")
    
    // Set a fixed seed for consistent data generation
    app.launchEnvironment["UITEST_SEED"] = "1"
    
    app.launch()
}
```

### Test Example

```swift
@MainActor
func testDeterministicDataLoaded() throws {
    // Wait for data to load
    sleep(1)
    
    // Verify we have the expected lists
    let listCells = app.cells
    XCTAssertGreaterThanOrEqual(listCells.count, 4, "Expected at least 4 test lists")
}
```

## Benefits

1. **Consistency** - Same data every time tests run
2. **Predictability** - No random behavior or flakiness
3. **Screenshots** - Perfect for generating App Store screenshots
4. **Isolation** - No interference from iCloud or existing user data
5. **Localization** - Automatically adapts to test language
6. **Clean State** - Fresh start for each test run

## Screenshot Automation

This implementation perfectly supports Phase 3 of the automation roadmap:
- ✅ Deterministic data for consistent screenshots
- ✅ No iCloud sync interference
- ✅ Locale-aware content (EN + FI)
- ✅ Realistic, production-like data
- Ready for Fastlane Snapshot integration

## Technical Details

### Data Generation

The test data is generated programmatically with:
- Fixed UUIDs per run (deterministic)
- Relative timestamps for realism
- Proper relationships (lists → items)
- Realistic quantities and descriptions

### Data Cleanup

On each launch in test mode:
1. All existing lists are deleted (batch delete)
2. Core Data context is saved
3. Test data is generated
4. Test lists and items are added
5. Data is reloaded to update UI

### iCloud Sync

During UI tests, iCloud sync is disabled by:
```swift
UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
```

This prevents:
- Sync conflicts during tests
- Network delays affecting test timing
- Real user data interfering with tests

## Maintenance

To update test data:
1. Edit `UITestDataService.swift`
2. Modify `generateEnglishTestData()` or `generateFinnishTestData()`
3. Keep data realistic and representative
4. Update this documentation if adding new features

## Next Steps

Ready for:
- ✅ Phase 3.2: Add Snapshot helpers to UITests
- ✅ Phase 3.3: Write screenshot tests (EN)
- ✅ Phase 3.4: Enable localization runs (EN + FI)
- ✅ Phase 3.5: Devices - iPhone 6.5" + iPad 13"
- ✅ Phase 3.6: Framing - device frames and captions
