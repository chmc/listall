# Publish Workflow macOS Fixes

**Date**: 2026-02-01
**Problem**: Publish to App Store workflow failing for macOS metadata upload
**Tags**: #fastlane #deliver #macos #asc-api #rating-config

## Root Causes

The publish-to-appstore workflow was failing due to multiple issues with the macOS release fastlane lane:

### 1. Wrong Parameter Name for Platform
- **Error**: `Could not find option 'app_platform'`
- **Root Cause**: Used `app_platform: "osx"` instead of `platform: "osx"`
- **Fix**: Change to `platform: "osx"` in deliver call

### 2. Rating Config Path Issues
- **Error**: `Could not find config file at path`
- **Root Cause**: Relative path `./metadata/macos/rating_config.json` resolved incorrectly
- **Fix**: Use `File.expand_path("metadata/macos/rating_config.json", __dir__)`

### 3. Deprecated Rating Config Keys
- **Error**: Multiple deprecation warnings for old key names
- **Root Cause**: Old keys like `CARTOON_FANTASY_VIOLENCE`, `GAMBLING_CONTESTS`
- **Fix**: Use new camelCase keys like `violenceCartoonOrFantasy`, `gambling`, `contests`

### 4. Rating Config Value Types
- **Error**: `Unexpected json type provided for attribute`
- **Root Cause**: Mixed up string/boolean types for different fields
- **Correct Types**:
  - Violence/content fields: STRING (`"NONE"`, `"INFREQUENT_OR_MILD"`, `"FREQUENT_OR_INTENSE"`)
  - `unrestrictedWebAccess`: BOOLEAN (`false`)
  - `gambling`: BOOLEAN (`false`)
  - `contests`: STRING (`"NONE"`)
  - `gamblingSimulated`: STRING (`"NONE"`)

### 5. Category Name Format
- **Error**: `Category 'Productivity' has been deprecated`
- **Root Cause**: Used title case instead of uppercase
- **Fix**: Use `"PRODUCTIVITY"`, `"UTILITIES"` instead of `"Productivity"`, `"Utilities"`

### 6. Screenshot Upload API Issues
- **Error**: `Display Type Not Allowed! - /data/attributes/screenshotDisplayType`
- **Root Cause**: App Store Connect API rejects screenshot display types (known issue)
- **Fix**: Pass `skip_screenshots:true` to both iOS and macOS release lanes

## Working Rating Config Format (2026)

```json
{
  "violenceCartoonOrFantasy": "NONE",
  "violenceRealistic": "NONE",
  "violenceRealisticProlongedGraphicOrSadistic": "NONE",
  "profanityOrCrudeHumor": "NONE",
  "matureOrSuggestiveThemes": "NONE",
  "horrorOrFearThemes": "NONE",
  "medicalOrTreatmentInformation": "NONE",
  "alcoholTobaccoOrDrugUseOrReferences": "NONE",
  "gamblingSimulated": "NONE",
  "sexualContentOrNudity": "NONE",
  "sexualContentGraphicAndNudity": "NONE",
  "unrestrictedWebAccess": false,
  "gambling": false,
  "contests": "NONE",
  "ageRatingOverride": "NONE"
}
```

## Commits

1. `f35b6dd` - Skip screenshots in publish workflow due to ASC API issue
2. `3349c1c` - Use correct 'platform' parameter for deliver
3. `7de6113` - Use string values in macOS rating_config.json
4. `db95934` - Use absolute path for macOS rating_config.json
5. `6258237` - Update rating config and categories to new ASC API format
6. `76d79d8` - Use STRING values for gambling and contests
7. `912c2fb` - gambling field needs BOOLEAN, contests needs STRING

## Successful Workflow Run

- Run ID: 21559781385
- URL: https://github.com/chmc/listall/actions/runs/21559781385
- Result: SUCCESS

## Note on Screenshots

Screenshots must be uploaded manually via App Store Connect web UI due to persistent ASC API issues with display type rejection. See `asc-watch-screenshot-display-type.md` for details.
