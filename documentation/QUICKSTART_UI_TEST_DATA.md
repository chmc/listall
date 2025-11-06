# Quick Start: UI Test Data

## TL;DR
The app now supports deterministic test data for UI testing and screenshots. Just run UI tests normally - test data is automatically loaded.

## How It Works

When you run UI tests, the app:
1. Detects `UITEST_MODE` launch argument (set automatically in tests)
2. Clears all existing data
3. Loads 4 test lists with realistic items
4. Disables iCloud sync

## Test Data Included

**4 Lists** (English or Finnish based on system language):
- Grocery Shopping (6 items, some completed)
- Weekend Projects (3 items, 1 completed)
- Books to Read (3 items, 1 completed)
- Travel Packing (4 items, 1 completed)

All with realistic dates, quantities, and descriptions.

## Running Tests

```bash
# Run all UI tests
xcodebuild test -project ListAll/ListAll.xcodeproj -scheme ListAll \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Or in Xcode: Cmd+U (test navigator) → Right-click scheme → Test
```

## For Screenshots

Ready for Fastlane Snapshot! The data is consistent every time, perfect for:
- Automated screenshot generation
- App Store screenshots in multiple languages
- Consistent test results

## Customizing Test Data

Edit: `ListAll/ListAll/Services/UITestDataService.swift`

Functions to modify:
- `generateEnglishTestData()` - English lists/items
- `generateFinnishTestData()` - Finnish lists/items

## Technical Details

**Launch Arguments**:
- `UITEST_MODE` - Enables test data (required)
- `UITEST_SEED` - Future use for variations (optional)

**What Gets Disabled**:
- iCloud sync (via UserDefaults key `iCloudSyncEnabled`)

**Data Cleanup**:
- All lists deleted via NSBatchDeleteRequest
- Fresh start every test run

## Files

- **Service**: `ListAll/ListAll/Services/UITestDataService.swift`
- **App Setup**: `ListAll/ListAll/ListAllApp.swift` (init method)
- **Tests**: `ListAll/ListAllUITests/ListAllUITests.swift` (setUpWithError)
- **Docs**: `documentation/deterministic_test_data.md`

## Next: Screenshot Automation

Now ready for Phase 3.2+:
1. Add Fastlane Snapshot helpers
2. Write screenshot tests
3. Generate multi-language screenshots
4. Frame with device images

---

✅ **Status**: Implemented & Tested  
📖 **Full Docs**: See `documentation/deterministic_test_data.md`
