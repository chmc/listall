# macOS App Store Signing: Certificate Types Matter

## Problem

macOS TestFlight/App Store submission was failing with:
```
Provisioning profile "match AppStore io.github.chmc.ListAllMac macos" doesn't include signing certificate "Apple Distribution: Aleksi Sutela (M9BR5FY93A)"
```

And later:
```
No signing certificate "Mac Installer Distribution" found
```

## Root Cause

The `mac_installer_distribution` certificate in the Match repo was **incorrectly created as "Apple Distribution"** instead of **"3rd Party Mac Developer Installer"**.

This caused:
1. Two certificates with identical names ("Apple Distribution: ...") in the keychain
2. Xcode picking the wrong one during signing
3. Profile/certificate mismatch errors

## Key Insight: macOS App Store Requires TWO Certificates

For macOS App Store/TestFlight distribution, you need:

| Certificate Type | Common Name | Purpose |
|-----------------|-------------|---------|
| Apple Distribution | `Apple Distribution: Name (TEAM_ID)` | Signs the .app bundle |
| Mac Installer Distribution | `3rd Party Mac Developer Installer: Name (TEAM_ID)` | Signs the .pkg installer |

These are DIFFERENT certificate types with DIFFERENT names. Having two "Apple Distribution" certs is wrong.

## Solution

1. Delete the incorrect certificate from Match repo
2. Create the correct "Mac Installer Distribution" certificate on Apple Developer Portal:
   - Go to Certificates, Identifiers & Profiles
   - Create new certificate → "Mac Installer Distribution"
   - Download and install locally
3. Run `bundle exec fastlane match mac_installer_distribution --platform macos` to add it to Match

## Prevention

When running `match mac_installer_distribution`, verify the generated certificate has the correct name:
- ✅ `3rd Party Mac Developer Installer: Name (TEAM_ID)`
- ❌ `Apple Distribution: Name (TEAM_ID)`

## Related Files

- `fastlane/Fastfile` - Uses `additional_cert_types: ["mac_installer_distribution"]` in match calls
- Match repo: `certs/mac_installer_distribution/` folder should contain installer certs

## Date

2026-01-05
