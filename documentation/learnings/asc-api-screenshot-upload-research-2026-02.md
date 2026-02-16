---
title: App Store Connect API Screenshot Upload Research (February 2026)
date: 2026-02-01
resolved: 2026-02-16
type: guide
category: fastlane
tags:
  - asc-api
  - screenshots
  - ci-cd
  - apple-bug
  - research
  - alternatives
use_when:
  - Researching alternatives to fastlane for screenshot upload
  - Understanding App Store Connect API screenshot upload process
  - Finding workarounds for "Display Type Not Allowed" errors
files_affected:
  - .github/workflows/publish-to-appstore.yml
  - fastlane/Fastfile
related:
  - asc-ios-screenshot-api-bug-2026-02.md
  - asc-watch-screenshot-display-type.md
---

## Overview

This document summarizes research into alternatives for automating iOS/iPadOS/watchOS screenshot uploads to App Store Connect when fastlane's deliver action fails with "Display Type Not Allowed!" errors. As of February 2026, this is a known Apple API bug affecting mobile device display types.

## Quick Reference

| Approach | Status | Complexity | Notes |
|----------|--------|------------|-------|
| Fastlane deliver | BROKEN | Low | Fails for iOS/iPad/Watch with API bug |
| Direct ASC API (Python/Swift) | SAME BUG | High | Uses same API, will have same error |
| Transporter CLI | DEPRECATED | Medium | Metadata only, requires GUI for screenshots |
| Manual Web UI | WORKS | N/A | Only reliable method currently |

## Research Findings

### 1. The Root Cause

The "Display Type Not Allowed!" error occurs at the **POST /v1/appScreenshotSets** endpoint when creating screenshot sets for mobile platforms. This is not a fastlane bug - it's an Apple App Store Connect API backend issue.

**What Works:**
- macOS screenshots (APP_DESKTOP display type)
- Metadata upload for all platforms

**What Fails:**
- iPhone (APP_IPHONE_67, APP_IPHONE_65)
- iPad (APP_IPAD_PRO_3GEN_129)
- Apple Watch (APP_WATCH_SERIES_7, etc.)

**Source:** [asc-ios-screenshot-api-bug-2026-02.md](/Users/aleksi/source/listall/documentation/learnings/asc-ios-screenshot-api-bug-2026-02.md)

### 2. API Display Type Issues (Late 2024 - Present)

Apple introduced new device sizes in late 2024:
- iPhone 6.9" displays
- iPad Pro 13" displays

**Problems Identified:**

1. **Missing Display Types:** The ScreenshotDisplayType enumeration [hasn't been updated](https://developer.apple.com/forums/thread/751867) to include new device sizes
2. **Documentation Gaps:** Official [ScreenshotDisplayType documentation](https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype) doesn't list 6.9" iPhone or 13" iPad types
3. **Workaround for 13" iPad:** Uses APP_IPAD_PRO_3GEN_129 when listed via API, but no programmatic upload type exists
4. **Fastlane Updated:** [Issue #29651](https://github.com/fastlane/fastlane/issues/29651) was resolved in PR #29760 (Nov 2025) to add new display sizes

**Key Forum Threads:**
- [New iPad 13" screenshots with App Store Connect API](https://developer.apple.com/forums/thread/751867)
- [New iPhone 6.9" screenshots with App Store Connect API](https://developer.apple.com/forums/thread/763908)
- [Screenshots for 6.9" Display and 13" Display rejected by fastlane](https://github.com/fastlane/fastlane/issues/29651)

### 3. App Store Connect API Upload Process

The standard three-phase upload process:

```
1. Reserve Asset (POST /v1/appScreenshots)
   - Creates screenshot entity
   - Returns upload URLs and chunk sizes

2. Upload Chunks (PUT to upload URLs)
   - Upload file in parallel chunks
   - No authentication required for chunk uploads

3. Commit (PATCH /v1/appScreenshots/{id})
   - Send MD5 checksum
   - Set isUploaded: true
```

**Documentation:**
- [App Screenshots - Apple Developer](https://developer.apple.com/documentation/appstoreconnectapi/app-screenshots)
- [How to upload assets using the App Store Connect API - Runway](https://www.runway.team/blog/how-to-upload-assets-using-the-app-store-connect-api)
- [Uploading Assets to App Store Connect](https://developer.apple.com/documentation/appstoreconnectapi/uploading-assets-to-app-store-connect)

### 4. Alternative Upload Methods

#### A. Direct API Implementation (Python/Swift)

**Python Libraries:**
- [appstoreconnect](https://pypi.org/project/appstoreconnect/) - Token generation, resource listing
- [appstoreconnectapi](https://pypi.org/project/appstoreconnectapi/) - Python wrapper
- [Ponytech/appstoreconnectapi](https://github.com/Ponytech/appstoreconnectapi) - Full wrapper implementation

**Swift Libraries:**
- [AvdLee/appstoreconnect-swift-sdk](https://github.com/AvdLee/appstoreconnect-swift-sdk) - Type-safe SDK
- [aaronsky/asc-swift](https://github.com/aaronsky/asc-swift) - Alternative SDK with upload examples

**Why This Won't Help:**
All these libraries use the same App Store Connect API endpoints that fastlane uses. The "Display Type Not Allowed" error occurs at the **POST /v1/appScreenshotSets** endpoint, which is the FIRST step of the upload process. Using a different library or language doesn't bypass this API-level validation failure.

#### B. Transporter CLI

Apple's official command-line tool for App Store deliveries.

**Capabilities:**
- Upload app binaries (.ipa, .pkg)
- Upload metadata in bulk
- Upload screenshots (historically)

**Current Status:**
- [Transporter User Guide](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/) mentions screenshot upload
- Historical articles like [Uploading Screenshots with iTMSTransporter](https://bou.io/UploadingScreenshotsWithITMSTransporter.html) show it worked previously
- 2026 command change: Must use `-assetFile` instead of `-f` flag

**Why This Won't Help:**
1. Modern Transporter focuses on binary uploads
2. Screenshot upload capability appears deprecated
3. Would likely use same ASC API backend (same error)
4. No evidence of working around the display type bug

**References:**
- [Using iTMSTransporter - Apple Developer Forums](https://developer.apple.com/news/?id=01312018a)
- [Working with iOS App Metadata from Linux using Transporter](https://medium.com/xcblog/working-with-ios-app-metadata-from-linux-using-transporter-cd33bd60333c)

#### C. Manual Web UI Upload

**The Only Reliable Method:**

Currently, manual upload via App Store Connect web UI is the only method that works for iOS/iPad/Watch screenshots.

**Process:**
1. Navigate to App Store Connect
2. Select app version
3. Upload screenshots manually for each locale/display type

**Screenshot Locations:**
- iPhone: `fastlane/screenshots_compat/`
- iPad: `fastlane/screenshots_compat/`
- Watch: `fastlane/screenshots/watch_normalized/`

## Display Type Validation Errors

### Common Causes

From [search research](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-appscreenshotsets):

1. **Platform Mismatch**: Using iPhone display types with macOS app version
2. **Invalid Display Type**: Using display types not in ScreenshotDisplayType enum
3. **Version-Specific Constraints**: Screenshot set not linked to correct appStoreVersionLocalization

### Current Bug Behavior

The February 2026 bug shows **ALL mobile display types** being rejected:
- Error occurs during screenshot SET creation (not upload)
- Same error for fresh versions and existing versions
- macOS display types (APP_DESKTOP) work correctly
- Metadata uploads succeed for all platforms

This indicates an API-level validation bug, not a configuration issue.

## Known Display Type Values

Based on research (incomplete due to JavaScript-only documentation):

**iPhone:**
- APP_IPHONE_67 (6.7")
- APP_IPHONE_65 (6.5")
- APP_IPHONE_69 (6.9" - new, may be missing from API)
- APP_IPHONE_58 (5.8")
- APP_IPHONE_55 (5.5")
- APP_IPHONE_47 (4.7")

**iPad:**
- APP_IPAD_PRO_3GEN_129 (12.9" 3rd gen)
- APP_IPAD_PRO_129 (12.9")
- APP_IPAD_13 (13" - new, missing from API)
- APP_IPAD_PRO_11 (11")

**Watch:**
- APP_WATCH_SERIES_7
- APP_WATCH_SERIES_3
- (Other series values)

**macOS:**
- APP_DESKTOP (works correctly)

**Source:** [ScreenshotDisplayType Documentation](https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype) (requires JavaScript to view full enum)

## Attempted Solutions (All Failed)

From [asc-ios-screenshot-api-bug-2026-02.md](/Users/aleksi/source/listall/documentation/learnings/asc-ios-screenshot-api-bug-2026-02.md):

1. sync_screenshots beta feature - Same error
2. Separate metadata/screenshot uploads - Metadata succeeds, screenshots fail
3. New app version (1.1.15) - Fresh version has same error
4. Different screenshot dimensions - Error persists
5. Skip watch, upload only iPhone/iPad - All mobile types rejected

## Current Workaround Implementation

From [fastlane/Fastfile](/Users/aleksi/source/listall/fastlane/Fastfile):

```ruby
# Two-phase upload approach
# Phase 1: Metadata only (always succeeds)
deliver(
  api_key: api_key,
  app_version: version,
  skip_screenshots: true,
  skip_binary_upload: true,
  submit_for_review: false,
  force: true
)

# Phase 2: Screenshots with error handling
begin
  deliver(
    api_key: api_key,
    app_version: version,
    screenshots_path: delivery_path,
    skip_screenshots: false,
    overwrite_screenshots: true,
    skip_metadata: true,
    skip_binary_upload: true,
    submit_for_review: false,
    force: true
  )
  UI.success("Screenshots uploaded successfully!")
rescue => e
  UI.error("Screenshot upload failed: #{e.message}")
  UI.important("Screenshots must be uploaded manually via App Store Connect")
  # Don't fail the lane - metadata was uploaded successfully
end
```

This approach:
- Ensures metadata always uploads
- Catches screenshot failures gracefully
- Allows CI pipeline to succeed
- Provides clear manual upload instructions

## Recommendations

### Short Term (Current State)

1. Continue using two-phase upload approach
2. macOS screenshots work - keep automating those
3. Manual upload required for iOS/iPad/Watch
4. Monitor fastlane and Apple forums for fixes

### Long Term Options

1. **Report to Apple Developer Support**
   - File bug report in Feedback Assistant
   - Reference forum threads showing widespread impact
   - Provide API error details

2. **Monitor Community Solutions**
   - Watch [fastlane GitHub issues](https://github.com/fastlane/fastlane/issues)
   - Follow [Apple Developer Forums - ASC API](https://developer.apple.com/forums/tags/app-store-connect-api)
   - Check for Apple engineer responses

3. **Alternative Automation (Future)**
   - If Apple fixes API but fastlane lags, consider direct API implementation
   - Swift SDK options: [asc-swift](https://github.com/aaronsky/asc-swift) with [upload_screenshot example](https://github.com/aaronsky/asc-swift/blob/main/Examples/upload_screenshot/UploadScreenshot.swift)
   - Python options: [appstoreconnectapi](https://github.com/Ponytech/appstoreconnectapi)

### What Won't Work

Do NOT attempt:
- Bypassing fastlane with direct API calls (same error)
- Using Transporter CLI (deprecated for screenshots)
- Creating custom upload scripts (will hit same API validation)
- Different screenshot dimensions (not a dimension issue)
- Older fastlane versions (API error, not fastlane bug)

## Related Apple Changes (2024-2026)

### Screenshot Requirement Changes

From [search results](https://www.iwantanelephant.com/blog/2024/09/12/important-update-apple-changed-app-store-connect-screenshot-requirements/):

- **Late 2024:** Only 6.9" and 6.5" display options available for iPhone
- **2025:** 6.9" iPhone size became required if 6.5" not provided
- **iPad:** 13" display now mandatory for iPad apps
- **Older sizes:** 5.5" no longer required for submission

### Fastlane Response

- [Issue #29651](https://github.com/fastlane/fastlane/issues/29651) - "Screenshots for 6.9" and 13" Display rejected"
- Error: "Invalid screen size (Actual size is 2752x2064 / 1320x2868)"
- Fixed in [PR #29760](https://github.com/fastlane/fastlane/pull/29760) (November 2025)
- Added support for current generation device resolutions

## Troubleshooting

### "Display Type Not Allowed!" Error

**Symptom:** POST /v1/appScreenshotSets fails for mobile platforms

**Diagnosis:**
1. Check if error affects ALL mobile types or just one
2. Verify macOS screenshots work (isolates to mobile API)
3. Try fresh app version (rules out version corruption)

**Resolution:**
- If affects all mobile types: Apple API bug, manual upload required
- If affects one type: May be invalid display type, check enum
- If macOS also fails: Check platform/version linking

### Screenshot Dimension Errors (Fastlane-Specific)

**Symptom:** "Invalid screen size" from fastlane validation

**Resolution:**
1. Verify fastlane version >= 2.230.0 (includes new display support)
2. Check dimensions match [Apple specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
3. Update fastlane if on older version

### Rate Limit Exceeded

**Symptom:** API rate limit errors during upload

**Resolution:**
- App Store Connect API has rate limits
- Add delays between requests
- Upload screenshots in batches

## Sources

This research compiled information from:

### Official Apple Documentation
- [App Store Connect API - App Screenshots](https://developer.apple.com/documentation/appstoreconnectapi/app-screenshots)
- [ScreenshotDisplayType Enum](https://developer.apple.com/documentation/appstoreconnectapi/screenshotdisplaytype)
- [Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [Uploading Assets to App Store Connect](https://developer.apple.com/documentation/appstoreconnectapi/uploading-assets-to-app-store-connect)

### Apple Developer Forums
- [New iPad 13" screenshots with App Store Connect API](https://developer.apple.com/forums/thread/751867)
- [New iPhone 6.9" screenshots with App Store Connect API](https://developer.apple.com/forums/thread/763908)

### Fastlane Issues
- [Issue #29651: Screenshots for 6.9" and 13" Display rejected](https://github.com/fastlane/fastlane/issues/29651)
- [Issue #22030: Deliver does not support 13 inch iPad](https://github.com/fastlane/fastlane/issues/22030)

### Third-Party Resources
- [Runway - How to upload assets using the App Store Connect API](https://www.runway.team/blog/how-to-upload-assets-using-the-app-store-connect-api)
- [bou.io - Uploading Screenshots with iTMSTransporter](https://bou.io/UploadingScreenshotsWithITMSTransporter.html)

### Code Libraries
- [AvdLee/appstoreconnect-swift-sdk](https://github.com/AvdLee/appstoreconnect-swift-sdk)
- [aaronsky/asc-swift](https://github.com/aaronsky/asc-swift)
- [Ponytech/appstoreconnectapi](https://github.com/Ponytech/appstoreconnectapi)
- [appstoreconnect (PyPI)](https://pypi.org/project/appstoreconnect/)

## Conclusion

As of February 2026, there is **NO automated solution** for uploading iOS/iPadOS/watchOS screenshots to App Store Connect due to an Apple API bug. The error occurs at the API level, so using different tools, libraries, or languages will not help.

The two-phase upload approach (metadata first, screenshots with error handling) allows CI pipelines to succeed while providing clear manual upload instructions. This is the best current workaround until Apple fixes the underlying API issue.

macOS screenshots continue to work and should remain automated. Monitor Apple Developer Forums and fastlane GitHub issues for updates on when the API is fixed.
