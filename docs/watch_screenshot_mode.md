# Watch App Screenshot Mode

## Overview
The watch app includes a screenshot mode configuration that allows you to display pre-defined English sample data for App Store screenshots. This solves the problem of watch simulators not having any data to display.

## Configuration Setup

### First Time Setup

1. **Copy the template configuration file**:
   ```bash
   cd ListAll/ListAllWatch\ Watch\ App/
   cp Config.plist.template Config.plist
   ```

2. The `Config.plist` file is automatically ignored by git (already in `.gitignore`)
3. The `Config.plist.template` file is committed to git as a reference

### Enable Screenshot Mode

1. Open `ListAll/ListAllWatch Watch App/Config.plist`
2. Change the `ScreenshotMode` value to `true`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ScreenshotMode</key>
	<true/>
</dict>
</plist>
```

3. Build and run the watch app on the simulator
4. The app will now display a pre-populated "Shopping List" with sample items in English

### Disable Screenshot Mode (Normal Operation)

1. Open `ListAll/ListAllWatch Watch App/Config.plist`
2. Change the `ScreenshotMode` value to `false`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ScreenshotMode</key>
	<false/>
</dict>
</plist>
```

3. Build and run the watch app
4. The app will now use real user data from Core Data

## Sample Data

When screenshot mode is enabled, the watch app displays a "Shopping List" with the following items:

- Milk (quantity: 2)
- Bread (quantity: 1)
- Eggs (quantity: 12)
- Apples (quantity: 6)
- Chicken breast (quantity: 1)
- Rice (quantity: 1)
- Tomatoes (quantity: 4)
- Cheese (quantity: 1)
- Butter (quantity: 1)
- Coffee (quantity: 1)
- Orange juice (quantity: 1)
- Pasta (quantity: 1)

The sample data includes:
- 12 items total
- All items are active (non-completed)
- All items in English
- Realistic quantities

## Technical Details

### Configuration File Structure

The configuration is stored in a `.plist` file with the following structure:

- **Config.plist.template**: Template file committed to git showing available configuration options
- **Config.plist**: Actual configuration file (ignored by git) containing your local settings

### Files Modified/Created

1. **New File**: `/ListAll/ListAllWatch Watch App/Config.plist.template`
   - Template configuration file (committed to git)
   - Shows available configuration options with comments
   
2. **New File**: `/ListAll/ListAllWatch Watch App/Config.plist`
   - Actual configuration file (ignored by git)
   - Copy from template and modify as needed
   - Defaults to screenshot mode disabled

3. **New File**: `/ListAll/ListAllWatch Watch App/Utils/WatchScreenshotConfiguration.swift`
   - Singleton configuration manager
   - Reads screenshot mode from Config.plist
   - Provides sample list data

4. **Modified**: `/ListAll/ListAllWatch Watch App/ViewModels/WatchMainViewModel.swift`
   - Added check for screenshot mode in `loadLists()` method
   - Returns sample data when screenshot mode is enabled
   - Falls back to normal Core Data loading when disabled

5. **Modified**: `/ListAll/ListAllWatch Watch App/ViewModels/WatchListViewModel.swift`
   - Added check for screenshot mode in `loadItems()` method
   - Uses items from list directly when screenshot mode is enabled

6. **Modified**: `.gitignore`
   - Already includes `Config.plist` to prevent committing local configurations

### How It Works

1. When `loadLists()` is called in `WatchMainViewModel`, it first checks if screenshot mode is enabled by reading from `Config.plist`
2. If enabled, it uses `WatchScreenshotConfiguration.shared.getScreenshotLists()` to get sample data
3. If disabled, it proceeds with normal Core Data loading
4. Similarly, `WatchListViewModel.loadItems()` checks screenshot mode and uses items from the list directly instead of Core Data
5. The rest of the app functions normally - the UI doesn't need to know if it's displaying sample or real data

## Use Cases

- **App Store Screenshots**: Enable screenshot mode to capture consistent screenshots across all devices
- **Demos**: Show potential users what the app looks like with data
- **Testing**: Verify UI layout with consistent data
- **Development**: Test UI without needing to manually add data

## Important Notes

- ⚠️ **Always disable screenshot mode before releasing to production**
- ⚠️ **Never commit `Config.plist` with screenshot mode enabled** (it's already in `.gitignore`)
- The configuration is read at runtime from the `.plist` file
- Each developer can have their own `Config.plist` settings without affecting others
- Screenshot mode only affects the watch app, not the iPhone app
- When screenshot mode is enabled, all watch sync and Core Data operations are bypassed for the lists view

## Benefits of Config File Approach

1. ✅ **No code changes needed**: Just edit the plist file
2. ✅ **Git-safe**: Config.plist is ignored, so you can't accidentally commit it
3. ✅ **Team-friendly**: Each developer has their own config
4. ✅ **Template provided**: Config.plist.template shows what's available
5. ✅ **Easy to extend**: Add more configuration options in the future
