# ASC iOS Screenshot Upload API Bug (February 2026)

**Date**: 2026-02-01
**Resolved**: 2026-02-16
**Problem**: App Store Connect API rejected iOS/iPadOS/watchOS screenshot uploads
**Tags**: #asc-api #screenshots #fastlane #ci-cd #resolved

## Summary

The App Store Connect API was rejecting iOS/iPadOS/watchOS screenshot uploads with "Display Type Not Allowed!" error for ALL mobile display types. This was an Apple API bug that has been **resolved as of 2026-02-16**.

## Resolution (2026-02-16)

Direct API testing confirmed that all display types now work:

| Display Type | Status | Test |
|-------------|--------|------|
| `APP_IPHONE_67` | Working | Delete + recreate cycle succeeded |
| `APP_IPAD_PRO_3GEN_129` | Working | Delete + recreate cycle succeeded |
| `APP_WATCH_SERIES_10` | Working | Delete + recreate cycle succeeded |
| `APP_DESKTOP` | Working | Never broken |

The Fastfile two-phase workaround has been removed. Both `release` and `release_macos` lanes now use a single `deliver` call for metadata and screenshots together.

### Key Research Findings

1. **No new display type strings exist** — Apple bundles 6.7" and 6.9" iPhones under `APP_IPHONE_67`, and 12.9" and 13" iPads under `APP_IPAD_PRO_3GEN_129`. The plan's hypothesis about `APP_IPHONE_69` was incorrect.
2. **Fastlane PR #29760** (Nov 2025) added dimension mappings (1320x2868 for iPhone, 2064x2752 for iPad) but the display type strings were already correct.
3. **The bug was transient** — likely an Apple-side API issue that resolved itself between Feb 1 and Feb 16, 2026.

## Original Bug (2026-02-01 to 2026-02-16)

All mobile display types failed with:
```
Error: An attribute value is invalid. - Display Type Not Allowed! - /data/attributes/screenshotDisplayType
```

Occurred at `POST /v1/appScreenshotSets` (set creation, not screenshot upload). macOS `APP_DESKTOP` always worked.

### Approaches Tried During Bug (All Failed)

1. sync_screenshots beta feature
2. Separate metadata/screenshot uploads
3. New app version (1.1.15)
4. Different screenshot dimensions
5. Skip watch, upload only iPhone/iPad
6. Fastlane 2.231.1 upgrade

## Lesson Learned

When an API bug seems to affect all display types equally while one platform works fine, it's likely a transient server-side issue rather than a configuration problem. The correct approach:
1. Implement a workaround (two-phase upload with error handling)
2. Periodically re-test to detect when the bug is fixed
3. Remove the workaround when confirmed resolved

## Related Files

- `fastlane/Fastfile` — release and release_macos lanes (simplified)
- `.github/workflows/publish-to-appstore.yml` — workflow (stale comments removed)
- `documentation/learnings/asc-watch-screenshot-display-type.md` — original corruption report
- `documentation/learnings/asc-api-screenshot-upload-research-2026-02.md` — API research
