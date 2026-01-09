# watchOS Localization - How It Works

## Overview
The watchOS app language synchronizes with the iOS app language preference using **WatchConnectivity** and **App Groups**.

## How Language Sync Works

### 1. iOS App Changes Language
When the user changes the language in the iOS app:
1. `LocalizationManager.setLanguage()` is called
2. Language is saved to App Groups: `UserDefaults(suiteName: "group.io.github.chmc.ListAll")`
3. iOS sends language to watchOS via WatchConnectivity:
   - Uses `sendMessage()` if watch is reachable (immediate)
   - Uses `transferUserInfo()` if watch is not reachable (background)

### 2. watchOS Receives Language Update
1. `WatchConnectivityService.session(_:didReceiveMessage:)` receives the language code
2. Saves it to App Groups `UserDefaults`
3. Calls `WatchLocalizationManager.shared.refreshLanguage()`
4. Sets `needsRestart = true` to show alert

### 3. User Restarts watchOS App
- When the app restarts, `WatchLocalizationManager.init()` reads the language from App Groups
- Sets `UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")`
- All `NSLocalizedString()` calls now use the new language from `Localizable.xcstrings`

## Why App Restart is Needed

String Catalogs (`.xcstrings`) are compiled into the app bundle at build time. Unlike traditional `.lproj` bundles, they cannot be dynamically swapped at runtime using Bundle swizzling.

The only way to change the language is to:
1. Set `AppleLanguages` in UserDefaults
2. Restart the app so the localization system loads strings in the new language

This is standard iOS/watchOS behavior - many apps require restart for language changes.

## Key Files

### iOS
- `ListAll/Utils/LocalizationManager.swift` - Manages language preference, syncs to watch
- `ListAll/Services/WatchConnectivityService.swift` - Sends language via WatchConnectivity

### watchOS
- `ListAllWatch Watch App/ListAllWatchApp.swift` - Contains `WatchLocalizationManager`
- `ListAllWatch Watch App/Services/WatchConnectivityService.swift` - Receives language updates

### Shared
- `ListAll/Localizable.xcstrings` - String Catalog with English and Finnish translations

## Testing Steps

1. **On iOS app**: Go to Settings → Change language to Finnish
2. **Check logs**: Should see:
   ```
   🌍 [iOS LocalizationManager] setLanguage() called with: fi
   🌍 [iOS LocalizationManager] Requested language sync to watch: fi
   🌍 [WatchConnectivity] Sending language preference to watch: fi
   ```

3. **On watchOS app**: Check logs for:
   ```
   🌍 [WatchConnectivity] Received language update: fi
   🌍 [WatchLocalizationManager] Language changed from en to fi
   🌍 [WatchLocalizationManager] ⚠️ App needs restart for language change to take effect!
   ```

4. **On watchOS app**: Should see alert "Language Changed - Please restart the app"

5. **Force quit and restart watchOS app**: Crown button → swipe left → X button → reopen app

6. **Verify**: All text should now be in Finnish (e.g., "Ladataan listoja..." instead of "Loading lists...")

## Debug Mode

All language-related operations have debug logging with the 🌍 emoji prefix. To see logs:
- Open Console app on Mac
- Select your iPhone/Watch Simulator
- Filter by "🌍" or process name "ListAllWatch"

## Troubleshooting

### Language not syncing to watch
- Check that App Groups is enabled: `group.io.github.chmc.ListAll`
- Verify WatchConnectivity session is activated
- Check Console logs for error messages

### UI still in English after restart
- Verify `AppleLanguages` was set: `defaults read`
- Check that `Localizable.xcstrings` contains Finnish translations
- Try force quitting and reopening the app again

### Can't find the alert
- The alert only shows when language actually changes
- Make sure to return to the watchOS app after changing language on iOS
- Check that `needsRestart` is being set to `true` in logs
