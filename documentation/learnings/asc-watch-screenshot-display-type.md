---
title: App Store Connect Watch Screenshot Display Type Rejection
date: 2026-01-29
severity: HIGH
category: fastlane
tags:
  - app-store-connect
  - watch-screenshots
  - display-type
  - deliver
  - asc-api
symptoms:
  - "Display Type Not Allowed! - /data/attributes/screenshotDisplayType"
  - Screenshot upload fails after deleting existing watch screenshots
  - Both APP_WATCH_SERIES_7 and APP_WATCH_SERIES_10 rejected
root_cause: ASC API rejects watch screenshot display type changes after version state corruption
solution: Skip watch screenshots in automated uploads; upload manually via ASC web UI
files_affected:
  - fastlane/Fastfile
  - .github/workflows/publish-to-appstore.yml
  - fastlane/lib/normalize_watch_screenshots.rb
---

## Problem

App Store Connect API rejects both `APP_WATCH_SERIES_7` (396x484) and `APP_WATCH_SERIES_10` (416x496) display types when creating screenshot sets via fastlane deliver. The error occurs after attempting to switch between watch display types.

Error message:
```
An attribute value is invalid. - Display Type Not Allowed! - /data/attributes/screenshotDisplayType
```

## Root Cause

The ASC API enters a broken state when:
1. Screenshots with display type A (e.g., SERIES_7) exist in ASC
2. Fastlane deletes them via `overwrite_screenshots: true`
3. Fastlane attempts to upload screenshots with display type B (e.g., SERIES_10)
4. API rejects the new display type

Once this happens, the API may reject BOTH display types for that version, creating a state where:
- Version has 0 watch screenshots
- Neither SERIES_7 nor SERIES_10 can be uploaded via API

This appears to be an ASC API bug or limitation around watch screenshot display type consistency.

## Solution

1. Add `skip_watch` option to fastlane release lane:
```ruby
lane :release do |options|
  skip_watch = options[:skip_watch] == true
  delivery_path = prepare_screenshots_for_delivery(compat_path, skip_watch: skip_watch)
  # ...
end
```

2. Enable skip_watch in CI workflow:
```yaml
run: bundle exec fastlane release version:${{ inputs.version }} skip_watch:true
```

3. Upload watch screenshots manually via App Store Connect web UI

## Prevention

- [ ] Monitor ASC API for watch display type support changes
- [ ] Consider keeping watch screenshots at a consistent display type
- [ ] Test screenshot uploads in dry-run before live uploads
- [ ] Keep watch screenshots in repository at native capture resolution

## Key Insight

> App Store Connect API may reject display type changes for watch screenshots; when automated uploads fail, manual upload via web UI is the workaround.
