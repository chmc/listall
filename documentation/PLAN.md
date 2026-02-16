# Plan: Diagnose and Fix ASC Screenshot Upload "Display Type Not Allowed" Error

## Context

The `publish-to-appstore` workflow fails to upload iOS/iPadOS/watchOS screenshots with "Display Type Not Allowed!" at `POST /v1/appScreenshotSets`. macOS screenshots (`APP_DESKTOP`) work fine. Nobody else reports this exact error publicly, suggesting it's specific to the ListAll app's configuration.

**Most likely root cause (from critic review):** Apple may have introduced NEW display type enum values (e.g., `APP_IPHONE_69` for 6.9" screens, `APP_IPAD_13` for 13" iPad) that Fastlane doesn't know about. The old `APP_IPHONE_67` and `APP_IPAD_PRO_3GEN_129` may no longer be accepted. Fastlane PR #29760 only expanded dimension mappings, NOT display type strings.

**Goal:** Use direct API calls to determine what display types ASC actually accepts, then fix the upload pipeline.

## Steps

### 1. Create feature branch
- `git checkout -b fix/asc-screenshot-upload`

### 2. Query existing screenshot sets from ASC (5 min)

If screenshots were manually uploaded via ASC web UI, query what display types those sets use:
```bash
# Get app store version localizations
curl -H "Authorization: Bearer $JWT" \
  "https://api.appstoreconnect.apple.com/v1/apps/{appId}/appStoreVersions?filter[platform]=IOS"

# Get screenshot sets for a localization
curl -H "Authorization: Bearer $JWT" \
  "https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{locId}/appScreenshotSets"
```

**This is the most informative step.** If the web UI created sets with `APP_IPHONE_69` instead of `APP_IPHONE_67`, that's the answer.

We can use Fastlane's `spaceship` Ruby API instead of raw curl since we already have API key configuration:
```ruby
# Quick Ruby script using spaceship
require 'spaceship'
Spaceship::ConnectAPI.token = ... # from existing API key
app = Spaceship::ConnectAPI::App.find("io.github.chmc.ListAll")
version = app.get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)
localizations = version.get_app_store_version_localizations
localizations.each { |loc|
  sets = loc.get_app_screenshot_sets
  sets.each { |s| puts "#{loc.locale}: #{s.screenshot_display_type}" }
}
```

### 3. Test new display type strings via direct API (15 min)

Try `POST /v1/appScreenshotSets` with hypothetical new display types:
- `APP_IPHONE_69` (6.9" iPhone)
- `APP_IPAD_13` (13" iPad)
- `APP_IPAD_PRO_M4_13` (alternative naming)
- `APP_WATCH_SERIES_10` (may already be correct)

Also re-test `APP_IPHONE_67` as control to confirm it's still rejected.

### 4. Check Apple's ScreenshotDisplayType documentation

Open https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype in browser (requires JavaScript) to check if Apple has added new enum values not visible in the text-only API docs.

### 5. Fix based on findings

**If new display type strings are needed:**
- Monkey-patch Fastlane locally to use the correct strings
- Update `prepare_screenshots_for_delivery` if filename-to-type mapping needs changes
- Generate correct dimension screenshots (1320x2868 for 6.9" iPhone) if needed
- Submit upstream Fastlane PR

**If version/app corruption:**
- Document the recovery steps
- Test creating a clean version

**If truly an Apple issue:**
- File Feedback Assistant with full API request/response logs

### 6. Update learnings documentation

Update `documentation/learnings/asc-ios-screenshot-api-bug-2026-02.md` with actual findings — either correcting the "Apple bug" conclusion or confirming it with better evidence.

## Key Files

- `fastlane/Fastfile` — release lane (lines 694-733), may need display type updates
- `fastlane/screenshots_compat/en-US/` — current screenshots (1290x2796 iPhone, 2064x2752 iPad)
- `documentation/learnings/asc-ios-screenshot-api-bug-2026-02.md` — update with findings
- `documentation/learnings/asc-watch-screenshot-display-type.md` — original corruption report

## Verification

1. API query reveals which display types ASC currently uses/accepts
2. If fix found: test full screenshot upload via `bundle exec fastlane release version:X.X.X`
3. Confirm screenshots appear in App Store Connect web UI
4. All existing tests pass (`bundle exec rspec`)

## Risk Assessment

- **Low risk**: Direct API queries are read-only, no side effects
- **Feature branch**: Changes isolated from main
- **Quick feedback**: Steps 2-3 take ~20 minutes total before committing to any code changes
