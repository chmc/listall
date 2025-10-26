# watchOS Localization Setup Instructions

## Issue
The watchOS app is displaying in English even when the iOS app is set to Finnish.

## Root Cause
The `LocalizationManager.swift` file needs to be added to the watchOS target in Xcode so that the watchOS app can read the language preference from the shared App Groups container.

## Solution

### Step 1: Add LocalizationManager.swift to watchOS Target

1. **Open Xcode**
2. **Navigate to the file**: `ListAll/ListAll/Utils/LocalizationManager.swift`
3. **Select the file** in the Project Navigator
4. **Open the File Inspector** (right sidebar, or press ⌥⌘1)
5. **Under "Target Membership"**, check the box for **"ListAllWatch Watch App"**
6. **Build the project** to verify it compiles

### Step 2: Verify the Changes

After adding the file to the watchOS target:

1. **Build the watchOS app**:
   ```bash
   cd /Users/aleksi/source/ListAllApp/ListAll
   xcodebuild -scheme "ListAllWatch Watch App" -destination 'generic/platform=watchOS' build
   ```

2. **Expected result**: `** BUILD SUCCEEDED **`

### Step 3: Test Language Synchronization

1. **On iOS app**:
   - Open Settings
   - Change language to Finnish (Suomi)
   
2. **On watchOS app**:
   - Force quit the watch app (if running)
   - Relaunch the watch app
   - The UI should now display in Finnish

## How It Works

1. **iOS app** stores the selected language in shared UserDefaults:
   - Container: `group.io.github.chmc.ListAll`
   - Key: `AppLanguage`
   - Value: `"fi"` or `"en"`

2. **watchOS app** reads the language on launch:
   - Initializes `LocalizationManager.shared` in `ListAllWatchApp.swift`
   - Reads from shared UserDefaults
   - Applies the language setting using `AppleLanguages` key

3. **Both apps** use the same `Localizable.xcstrings` file for translations

## Files Modified

1. **LocalizationManager.swift** - Updated to use shared App Groups UserDefaults
2. **ListAllWatchApp.swift** - Added LocalizationManager initialization
3. All watchOS view files - Already using NSLocalizedString()

## Verification

After completing the steps above, verify:
- ✅ Build succeeds for watchOS target
- ✅ Watch app launches without errors
- ✅ Watch app UI displays in the language selected in iOS app
- ✅ Language changes on iOS are reflected on watch after relaunch

## Troubleshooting

**If the watch app is still in English:**

1. **Check App Groups entitlement** on watchOS target:
   - Open `ListAllWatch Watch App.entitlements`
   - Verify `group.io.github.chmc.ListAll` is present

2. **Force quit both apps** and relaunch

3. **Check UserDefaults** in iOS Settings:
   - Settings → General → Language & Region
   - Verify the language is set correctly

4. **Debug logging** (optional):
   - Add print statement in LocalizationManager.init():
   ```swift
   print("📱 Current language: \(currentLanguage.rawValue)")
   ```

## Additional Notes

- The watchOS app will automatically follow the iOS app's language selection
- No separate language selector is needed on watchOS
- Language changes require restarting the watch app to take effect
- The localization uses Apple's standard `AppleLanguages` mechanism
