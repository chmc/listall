---
title: App Store Connect Screenshot Display Type Rejection
date: 2026-01-29
severity: HIGH
category: fastlane
tags:
  - app-store-connect
  - screenshots
  - display-type
  - deliver
  - asc-api
  - version-corruption
symptoms:
  - "Display Type Not Allowed! - /data/attributes/screenshotDisplayType"
  - Screenshot upload fails after deleting existing screenshots
  - All display types rejected (iPhone, iPad, Watch)
  - Error occurs for en-US locale immediately after deletion
root_cause: ASC API enters corrupted state after display type switching, rejects ALL screenshot uploads
solution: Skip ALL screenshots in automated uploads; upload manually via ASC web UI
files_affected:
  - fastlane/Fastfile
  - .github/workflows/publish-to-appstore.yml
  - fastlane/lib/normalize_watch_screenshots.rb
---

## Problem

App Store Connect API rejects screenshot display types when creating screenshot sets via fastlane deliver. Initially observed with watch screenshots (`APP_WATCH_SERIES_7`/`APP_WATCH_SERIES_10`), but the error persists even after skipping watch screenshots - suggesting the ASC version is in a corrupted state that rejects ALL screenshot uploads.

Error message:
```
An attribute value is invalid. - Display Type Not Allowed! - /data/attributes/screenshotDisplayType
```

## Root Cause

The ASC API enters a broken state when:
1. Screenshots with display type A exist in ASC
2. Fastlane deletes them via `overwrite_screenshots: true`
3. Fastlane attempts to upload screenshots with display type B
4. API rejects the new display type

Once triggered, the API may reject ALL display types for that version, creating a state where:
- Version has 0 screenshots
- No display types can be uploaded via API
- Manual upload via ASC web UI still works

This appears to be an ASC API bug around version state management after screenshot deletion.

## Solution

1. Add `skip_screenshots` option to fastlane release lane:
```ruby
lane :release do |options|
  skip_screenshots = options[:skip_screenshots] == true
  deliver(
    skip_screenshots: skip_screenshots,
    overwrite_screenshots: !skip_screenshots,
    # ...
  )
end
```

2. Enable skip_screenshots in CI workflow:
```yaml
run: bundle exec fastlane release version:${{ inputs.version }} skip_screenshots:true
```

3. Upload ALL screenshots manually via App Store Connect web UI

## Prevention

- [ ] Avoid switching screenshot display types mid-version
- [ ] Consider creating a new version if screenshot upload is corrupted
- [ ] Keep screenshots consistent across releases
- [ ] Monitor ASC API for fixes to this behavior

## Key Insight

> App Store Connect API may corrupt version state when deleting/switching screenshot display types; the only workaround is manual upload via web UI or creating a new app version.
