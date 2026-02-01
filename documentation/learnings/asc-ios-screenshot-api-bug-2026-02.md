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

## Root Cause Analysis

This is NOT:
- A fastlane version issue (using 2.230.0 with all fixes)
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

Run [21560362548](https://github.com/chmc/listall/actions/runs/21560362548) shows:
- Workflow: SUCCESS
- iOS metadata: Uploaded
- macOS metadata: Uploaded
- macOS screenshots: Uploaded
- iOS/Watch screenshots: Failed (manual upload required)
