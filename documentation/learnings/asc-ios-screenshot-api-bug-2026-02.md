# ASC iOS Screenshot Upload API Bug (February 2026)

**Date**: 2026-02-01
**Problem**: App Store Connect API rejects iOS/iPadOS/watchOS screenshot uploads
**Tags**: #asc-api #screenshots #fastlane #ci-cd #apple-bug
**Severity**: HIGH

## Summary

The App Store Connect API is rejecting iOS/iPadOS/watchOS screenshot uploads with "Display Type Not Allowed!" error for ALL mobile display types. This is an **Apple API bug** that cannot be resolved through code changes or configuration.

## Key Findings

### What Works
- macOS screenshots (`APP_DESKTOP` display type) upload successfully via API
- Metadata upload for all platforms works correctly
- Two-phase upload approach allows metadata to succeed even when screenshots fail

### What Fails
- iPhone screenshots (`APP_IPHONE_67`)
- iPad screenshots (`APP_IPAD_PRO_3GEN_129`)
- Apple Watch screenshots (`APP_WATCH_SERIES_7`)

All fail with:
```
Error: An attribute value is invalid. - Display Type Not Allowed! - /data/attributes/screenshotDisplayType
```

## Approaches Tried (All Failed)

1. **sync_screenshots beta feature**: Same error
2. **Separate metadata/screenshot uploads**: Screenshots still fail
3. **New app version (1.1.15)**: Fresh version still has the error
4. **Different screenshot dimensions**: Error persists
5. **Skip watch, upload only iPhone/iPad**: All mobile types rejected
6. **Fastlane 2.231.1 upgrade**: Same error persists (tested 2026-02-01)

## Root Cause Analysis

This is NOT:
- A fastlane version issue (tested 2.230.0 and 2.231.1)
- A screenshot dimension issue (all dimensions are correct)
- A version-specific corruption (fresh versions fail too)

This IS:
- An Apple ASC API backend bug
- Specific to mobile device display types (macOS works)
- Occurring at screenshot SET creation, not during upload

## Current Workaround

The publish workflow now:
1. Uploads metadata first (always succeeds)
2. Attempts screenshot upload with error handling
3. macOS screenshots upload successfully
4. iOS/Watch screenshot failures are caught and reported
5. Workflow completes successfully with partial screenshot upload

## Manual Upload Required

iOS/iPadOS/watchOS screenshots must be uploaded manually via App Store Connect web UI:

| Platform | Screenshot Location |
|----------|-------------------|
| iPhone | `fastlane/screenshots_compat/` |
| iPad | `fastlane/screenshots_compat/` |
| Watch | `fastlane/screenshots/watch_normalized/` |

## Attempted Alternative Methods

1. **iTMSTransporter**: Deprecated, requires GUI-based Transporter.app
2. **sync_screenshots**: Beta feature, same API bug affects it
3. **Different upload order**: No effect on API behavior

## Resolution

This requires Apple to fix the ASC API. Options:
1. Report to Apple Developer Support
2. Monitor fastlane GitHub issues for community workarounds
3. Check Apple Developer Forums for known issues
4. Wait for Apple API fix

## Related Files

- `/Users/aleksi/source/listall/.github/workflows/publish-to-appstore.yml`
- `/Users/aleksi/source/listall/fastlane/Fastfile` (release and release_macos lanes)
- `/Users/aleksi/source/listall/documentation/learnings/asc-watch-screenshot-display-type.md`

## Commits

- `b679c30` - Attempt sync_screenshots approach
- `5b93f8a` - Separate metadata/screenshot upload phases
- `28c1503` - Fix macOS screenshot path
- `7a40630` - Document partial success findings

## Workflow Status

Latest runs tested:

| Run | Fastlane | iOS Screenshots | macOS Screenshots | Version |
|-----|----------|-----------------|-------------------|---------|
| [21560362548](https://github.com/chmc/listall/actions/runs/21560362548) | 2.230.0 | ❌ Failed | ✅ Uploaded | 1.1.16 |
| [21561056043](https://github.com/chmc/listall/actions/runs/21561056043) | 2.231.1 | ❌ Failed | ✅ Uploaded | 1.1.16 |
| [21564586670](https://github.com/chmc/listall/actions/runs/21564586670) | 2.231.1 | ❌ Failed | ✅ Uploaded | 1.1.17 |

## Deep Analysis (2026-02-01 Ralph Loop Investigation)

### API Query Research

Investigated whether querying the ASC API for allowed display types could help bypass the bug:

1. **Can query existing screenshot sets**: `GET /v1/appStoreVersionLocalizations/{id}/appScreenshotSets`
2. **Cannot query allowed types**: No endpoint exists to list valid display types before creation
3. **Error occurs at creation**: `POST /v1/appScreenshotSets` rejects all mobile types
4. **Not a mismatch issue**: Fastlane sends correct display type strings (e.g., `APP_IPHONE_67`)

### Why No Workaround Exists

| Approach | Why It Won't Work |
|----------|------------------|
| Query existing sets and upload to those types | Error is at SET creation, not screenshot upload |
| Use different display type strings | API rejects ALL mobile types, not specific ones |
| Use older display types | Same rejection error |
| Use direct API calls | Same API, same error |
| Use Transporter CLI | Deprecated for screenshots |
| Use alternative libraries | All use same ASC API |

### Verified Working

- ✅ macOS screenshots via `APP_DESKTOP` display type
- ✅ Metadata upload for all platforms
- ✅ Two-phase upload (metadata first, screenshots with error handling)
- ✅ Workflow completes "successfully" due to graceful error handling

### Still Broken (Apple API Bug)

- ❌ iPhone screenshots (`APP_IPHONE_67`)
- ❌ iPad screenshots (`APP_IPAD_PRO_3GEN_129`)
- ❌ Watch screenshots (`APP_WATCH_SERIES_7`, `APP_WATCH_SERIES_10`)

## Community Research

Based on Apple Developer Forums research (2026-02-01):

1. **New display types not in API**: The ASC API documentation doesn't list new 6.9" iPhone and 13" iPad display types (forum threads 763908, 751867)
2. **Fastlane fix already applied**: PR #29760 added support for latest device resolutions in fastlane 2.230.0
3. **API-level rejection**: The error occurs at `POST /v1/appScreenshotSets` endpoint, rejecting valid display types

This is a known Apple ASC API issue affecting developers using automated screenshot uploads.

## Blocked - Cannot Complete Automated Upload

**Task Completion Status**: BLOCKED by Apple ASC API bug

This task cannot be fully completed because:
- The ASC API rejects ALL mobile device screenshot display types
- This is a server-side Apple issue, not a code/configuration issue
- Manual upload via App Store Connect web UI is the only current workaround

**Recommended Actions**:
1. Report bug to Apple via Feedback Assistant
2. Monitor [fastlane/fastlane GitHub issues](https://github.com/fastlane/fastlane/issues) for community workarounds
3. Re-test automated upload after Apple fixes the API
4. Upload iOS/iPad/Watch screenshots manually via App Store Connect web UI

## Manual Upload Instructions

For version 1.1.16 (or any pending version), upload screenshots manually:

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select ListAll app → App Store → iOS/iPadOS version
3. For each locale (en-US, fi):
   - Upload iPhone 6.9" screenshots from `fastlane/screenshots_compat/{locale}/iPhone 16 Pro Max-*.png`
   - Upload iPad 13" screenshots from `fastlane/screenshots_compat/{locale}/iPad Pro 13-inch (M4)-*.png`
4. Go to watchOS version:
   - Upload Watch screenshots from `fastlane/screenshots/watch_normalized/{locale}/Apple Watch Series 10 (46mm)-*.png`
5. macOS screenshots should already be uploaded via automation
