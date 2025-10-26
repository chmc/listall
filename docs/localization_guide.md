# ListAll - Localization Guide

## Overview

ListAll uses Apple's modern String Catalog (`.xcstrings`) approach for localization. This guide explains how to work with localizations, add new languages, and maintain translations.

## Current Status

**Supported Languages:**
- 🇺🇸 English (en) - Base language
- 🇫🇮 Finnish (fi) - Complete App Store metadata, core UI strings

**Infrastructure:**
- ✅ LocalizationManager utility for language management
- ✅ In-app language selector in Settings
- ✅ String Catalog with 50+ core strings
- ✅ Finnish App Store metadata (complete)
- ⏳ Full UI localization (in progress - pattern established)

## For Users

### How to Change Language

1. Open **ListAll** app
2. Tap **Settings** from bottom tab bar
3. Go to **Language** section (first section)
4. Tap **App Language**
5. Select your preferred language:
   - 🇺🇸 English
   - 🇫🇮 Suomi (Finnish)
6. Tap **Back**
7. See confirmation alert
8. **Restart the app** for all changes to take effect

**Note:** Some strings update immediately, but for complete consistency, restart the app.

## For Developers

### Architecture

**LocalizationManager** (`ListAll/Utils/LocalizationManager.swift`)
- Centralized language management
- Persistent language selection
- Observable object for SwiftUI
- Notification system for language changes

**String Catalog** (`ListAll/Localizable.xcstrings`)
- JSON-based format (Git-friendly)
- Xcode integration for easy editing
- Supports pluralization and formatting
- Manual extraction state for control

### Adding a New Language

#### Step 1: Update LocalizationManager

```swift
// In LocalizationManager.swift
enum AppLanguage: String, CaseIterable {
    case english = "en"
    case finnish = "fi"
    case swedish = "sv"  // Add your language
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .finnish: return "Suomi"
        case .swedish: return "Svenska"  // Native name
        }
    }
    
    var nativeDisplayName: String {
        switch self {
        case .english: return "English"
        case .finnish: return "Suomi"
        case .swedish: return "Svenska"  // Same as displayName
        }
    }
    
    var flagEmoji: String {
        switch self {
        case .english: return "🇺🇸"
        case .finnish: return "🇫🇮"
        case .swedish: return "🇸🇪"  // Country flag
        }
    }
}
```

#### Step 2: Add Translations to String Catalog

1. Open `ListAll/Localizable.xcstrings` in Xcode
2. Select the file in Project Navigator
3. In the Editor pane, click **"+"** button at bottom left
4. Select **"Add Localization"**
5. Choose language code (e.g., `sv` for Swedish)
6. Translate all strings in Xcode's UI
   - English column shows source text
   - New language column is for translation
   - Add comments to help translators

**Keyboard Shortcut:** Cmd+Shift+L to add localization

#### Step 3: Create App Store Metadata

```bash
# Navigate to metadata folder
cd metadata

# Create language folder (use ISO 639-1 code)
mkdir sv  # For Swedish

# Copy English files as template
cp en-US/description.txt sv/
cp en-US/keywords.txt sv/
cp en-US/promotional_text.txt sv/
cp en-US/release_notes.txt sv/
cp en-US/support_url.txt sv/
cp en-US/privacy_policy_url.txt sv/

# Translate each file
# - description.txt: Full app description (max 4,000 chars)
# - keywords.txt: Search keywords (max 100 chars, comma-separated)
# - promotional_text.txt: Short promo (max 170 chars)
# - release_notes.txt: What's new (max 4,000 chars)
# - URLs can remain the same or be localized
```

**Important:** 
- Keep URLs pointing to English content unless you have localized pages
- Keywords should be comma-separated with NO spaces
- Test character limits with `wc -c filename.txt`

#### Step 4: Test

1. Clean build: Cmd+Shift+K
2. Build: Cmd+B
3. Run app in simulator
4. Go to Settings → Language
5. Select new language
6. Restart app
7. Verify all strings appear correctly
8. Test in different contexts (lists, items, settings, etc.)

### Localizing UI Strings

#### SwiftUI Text (Automatic)

```swift
// SwiftUI Text automatically looks up strings
Text("Settings")  // Looks up "Settings" in Localizable.xcstrings
```

**When to use:** For static UI labels, buttons, navigation titles

#### NSLocalizedString (Manual)

```swift
// For string variables, error messages, computed text
let message = NSLocalizedString("Loading lists...", comment: "Progress message")
```

**When to use:** For dynamic strings, string variables, error messages

#### Formatted Strings

```swift
// In Localizable.xcstrings, create key: "%lld Selected"
// English: "%lld Selected"
// Finnish: "%lld valittu"

// In code:
let count = 5
Text("\(count) Selected")  // Auto-looks up "%lld Selected"

// Or manually:
let text = String(format: NSLocalizedString("%lld items", comment: "Item count"), count)
```

**When to use:** For strings with numbers, plurals, or variables

#### String Extension (Convenience)

```swift
// Use .localized extension
let text = "Settings".localized

// With parameters
let message = "Error: %@".localized("Connection failed")
```

**When to use:** For quick localization in ViewModels or services

### Best Practices

#### 1. Use Meaningful Keys

```swift
// ❌ Bad: Generic keys
Text("button1")
Text("label_a")

// ✅ Good: Descriptive keys
Text("Export Data")
Text("Archive Lists")
```

#### 2. Add Context Comments

```swift
// In String Catalog, add comment for translators
NSLocalizedString("Archive", comment: "Button to archive a list (verb)")
NSLocalizedString("Archived", comment: "Status label for archived lists (adjective)")
```

#### 3. Handle Plurals Properly

```swift
// Don't concatenate
// ❌ Bad:
Text("\(count) item(s)")

// ✅ Good: Use String Catalog pluralization
// Create key: "%lld items"
// Add plural rules in Xcode String Catalog editor
Text("\(count) items")
```

#### 4. Keep Strings Short

- UI labels should be concise
- Consider length in all languages (German is often longer)
- Test UI layout with longest translation
- Use abbreviations if necessary

#### 5. Avoid Hard-Coded Strings

```swift
// ❌ Bad:
Text("Loading...")
.alert("Error", isPresented: $showError)

// ✅ Good:
Text(NSLocalizedString("Loading...", comment: ""))
.alert(NSLocalizedString("Error", comment: ""), isPresented: $showError)
```

### Testing Localization

#### Manual Testing

1. **Simulator Testing:**
   ```bash
   # Change simulator language
   Settings > General > Language & Region > Preferred Languages
   ```

2. **App Testing:**
   - Use in-app language selector
   - Test all screens
   - Verify formatted strings
   - Check text truncation
   - Test with long translations

3. **Edge Cases:**
   - Empty states
   - Error messages
   - Alerts and confirmations
   - Tooltips
   - Long list/item names

#### Automated Testing

```swift
// Test localization in unit tests
func testLocalization() {
    let manager = LocalizationManager.shared
    
    // Test language switching
    manager.setLanguage(.finnish)
    XCTAssertEqual(manager.currentLanguage, .finnish)
    
    // Test string lookup
    let text = NSLocalizedString("Settings", comment: "")
    XCTAssertNotEqual(text, "Settings") // Should be translated
}
```

### Xcode Tools

#### Export for Localization

```bash
# Export strings for translation
xcodebuild -exportLocalizations -project ListAll.xcodeproj -localizationPath ./Localizations

# This creates .xliff files for each language
# Send to professional translators
```

#### Import Localization

```bash
# Import translated .xliff files
xcodebuild -importLocalizations -project ListAll.xcodeproj -localizationPath ./Localizations
```

#### String Catalog Editor

1. Open `Localizable.xcstrings` in Xcode
2. Use visual editor to:
   - Add new strings
   - Add languages
   - Edit translations
   - Add comments
   - Configure pluralization
   - Preview strings

### Troubleshooting

#### Strings Not Updating

**Problem:** Changed translation but app still shows old text

**Solution:**
1. Clean build folder (Cmd+Shift+K)
2. Delete derived data
3. Restart Xcode
4. Rebuild project

#### String Catalog Not Recognized

**Problem:** Xcode doesn't find strings in .xcstrings

**Solution:**
1. Verify file is in target membership
2. Check build settings: `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`
3. Ensure file is UTF-8 encoded
4. Validate JSON syntax

#### Language Not Changing

**Problem:** App doesn't switch to selected language

**Solution:**
1. Verify LocalizationManager saves preference
2. Check UserDefaults key: `"AppLanguage"`
3. Ensure language code matches String Catalog
4. Restart app for complete refresh

#### Missing Translations

**Problem:** Some strings appear in English even in Finnish mode

**Solution:**
1. Check if string exists in Localizable.xcstrings
2. Verify translation is marked as "translated" state
3. Ensure key matches exactly (case-sensitive)
4. Clean build and retry

### App Store Submission

#### Adding Localization to App Store Connect

1. Log in to App Store Connect
2. Select your app
3. Go to **App Store** tab
4. Click **"+"** next to **App Store Localizations**
5. Select language (e.g., Finnish)
6. Fill in metadata:
   - Copy from `metadata/fi/description.txt`
   - Copy from `metadata/fi/keywords.txt`
   - Copy from `metadata/fi/promotional_text.txt`
   - Copy from `metadata/fi/release_notes.txt`
7. Upload screenshots (optional: can use English screenshots initially)
8. Save changes

#### Localized Screenshots

**Requirements:**
- Screenshots for each device size
- In each language
- Showing localized UI

**How to Create:**
1. Run app in simulator
2. Change app language to target language
3. Navigate to key screens
4. Take screenshots (Cmd+S in simulator)
5. Save to `metadata/[lang]/screenshots/`
6. Upload to App Store Connect

#### Metadata Validation

```bash
# Validate metadata before submission
cd metadata
./validate_metadata.sh

# Check Finnish metadata
cat fi/keywords.txt | wc -c  # Should be ≤ 100
cat fi/description.txt | wc -c  # Should be ≤ 4,000
cat fi/promotional_text.txt | wc -c  # Should be ≤ 170
```

## Language Codes

**Common ISO 639-1 Codes:**
- `en` - English
- `fi` - Finnish
- `sv` - Swedish
- `de` - German
- `fr` - French
- `es` - Spanish
- `it` - Italian
- `pt` - Portuguese
- `ja` - Japanese
- `ko` - Korean
- `zh-Hans` - Chinese (Simplified)
- `zh-Hant` - Chinese (Traditional)
- `ar` - Arabic
- `ru` - Russian

## Resources

### Apple Documentation
- [String Catalogs](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Localization](https://developer.apple.com/localization/)
- [App Store Localization](https://developer.apple.com/app-store/localization/)

### Tools
- [Xcode String Catalog Editor](https://developer.apple.com/videos/play/wwdc2023/10155/)
- [Crowdin](https://crowdin.com/) - Translation management
- [Lokalise](https://lokalise.com/) - Localization platform
- [DeepL](https://www.deepl.com/) - Translation API

## Checklist

### Adding New Language

- [ ] Update `LocalizationManager.AppLanguage` enum
- [ ] Add display name, native name, and flag emoji
- [ ] Add localization to `Localizable.xcstrings` in Xcode
- [ ] Translate all strings (50+ strings currently)
- [ ] Create `metadata/[lang]/` folder
- [ ] Translate all metadata files
- [ ] Validate character limits
- [ ] Test in app Settings → Language
- [ ] Verify UI displays correctly
- [ ] Take localized screenshots
- [ ] Add to App Store Connect
- [ ] Submit for review

### Before Release

- [ ] All strings translated
- [ ] Metadata within character limits
- [ ] Screenshots prepared
- [ ] Tested on device
- [ ] Tested language switching
- [ ] Tested formatted strings
- [ ] Tested plurals
- [ ] No hard-coded strings in UI
- [ ] Build succeeds
- [ ] App Store Connect configured

## Support

For questions or issues with localization:
1. Check this guide
2. Review `LocalizationManager.swift` implementation
3. Examine `Localizable.xcstrings` structure
4. See examples in `SettingsView.swift`
5. Consult `docs/ai_changelog.md` for implementation details

---

**Last Updated:** October 26, 2025
**Version:** 1.0
**Languages:** 2 (English, Finnish)
**Status:** Infrastructure Complete ✅

