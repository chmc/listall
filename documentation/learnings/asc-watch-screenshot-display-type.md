---
title: App Store Connect Screenshot Display Type Rejection
date: 2026-01-29
resolved: 2026-02-16
severity: RESOLVED
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
root_cause: ASC API entered corrupted state after display type switching (transient Apple bug, resolved 2026-02-16)
solution: Bug resolved. Fastfile simplified to single deliver call. See asc-ios-screenshot-api-bug-2026-02.md for full resolution.
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

The release lanes now handle this gracefully:
1. First upload metadata only to ensure version exists
2. Then attempt screenshot upload with error handling
3. If screenshot upload fails, continue with metadata-only success
4. Report clear status about what was uploaded vs what failed

Current behavior (as of February 2026):
- ✅ **macOS screenshots (APP_DESKTOP)**: Upload works via API
- ❌ **iOS/iPadOS/Watch screenshots**: Rejected with "Display Type Not Allowed!" error
- iOS screenshots must be uploaded manually via App Store Connect web UI

## Fastlane Configuration

```ruby
# Two-phase upload approach in release lane
# Phase 1: Upload metadata only (always succeeds)
deliver(
  api_key: api_key,
  skip_screenshots: true,
  # ...
)

# Phase 2: Attempt screenshot upload (catches failures)
begin
  deliver(
    api_key: api_key,
    skip_screenshots: false,
    skip_metadata: true,  # Already uploaded
    # ...
  )
rescue => e
  UI.error("Screenshot upload failed: #{e.message}")
  # Continue - metadata was uploaded successfully
end
```

## Prevention

- [ ] Avoid switching screenshot display types mid-version
- [ ] Consider creating a new version if screenshot upload is corrupted
- [ ] Keep screenshots consistent across releases
- [ ] Monitor ASC API for fixes to this behavior

## Key Insight

> App Store Connect API may corrupt version state when deleting/switching screenshot display types; macOS (APP_DESKTOP) screenshots still work via API, but iOS/iPadOS/Watch display types require manual upload via web UI.
