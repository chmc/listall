---
title: TestFlight Upload Fails When Version Train Is Closed
date: 2026-02-05
severity: HIGH
category: ci-cd
tags:
  - testflight
  - version-train
  - app-store-connect
  - fastlane
  - pilot
  - release-workflow
symptoms:
  - "CFBundleShortVersionString must contain a higher version than previously approved"
  - "The train version is closed for new build submissions"
  - "Validation failed (409)"
  - iOS build fails but macOS succeeds (or vice versa)
  - Partial release detected in verify-release job
root_cause: Version was already approved on one platform, closing the train for new uploads with the same version string
solution: Added pre-flight version train validation using ASC API before expensive build step
files_affected:
  - fastlane/Fastfile
  - .github/workflows/release.yml
---

## Problem

Running the release workflow with `skip_version_bump:true` using version 1.1.17 failed for iOS because 1.1.17 was already approved on the iOS App Store. The iOS "train" was closed for new submissions. macOS succeeded because its version train was still open (platforms are independent in ASC).

The build itself completed (~74 seconds of wasted CI time) but the `pilot` upload was rejected by App Store Connect with HTTP 409.

## Root Cause

App Store Connect manages version "trains" per-platform. Once a version is approved/released (READY_FOR_SALE / READY_FOR_DISTRIBUTION), no new builds can be uploaded for that version string on that platform. The workflow had no pre-flight check to detect this before starting the expensive build.

## Solution

1. Added `validate_version_train()` function in Fastfile that queries ASC API before building:
   - Checks `get_live_app_store_version` (uses modern `appVersionState` field)
   - Checks all versions for `PENDING_DEVELOPER_RELEASE` and `READY_FOR_SALE` states
   - Fails early with clear error message and recovery instructions
   - Falls back gracefully if API call fails (doesn't block builds on API issues)
2. Added pre-flight check to both `beta` (iOS) and `beta_macos` lanes
3. Improved partial release recovery guidance in workflow verify-release step

## Prevention

- [ ] Always bump version before releasing (don't use `skip_version_bump:true` with an already-released version)
- [ ] Pre-flight version train check catches this automatically before build

## Key Insight

> App Store Connect version trains are per-platform: a version can be closed on iOS but open on macOS. Always validate the train is open before building.
