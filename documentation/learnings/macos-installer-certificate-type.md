---
title: macOS App Store Requires Correct Mac Installer Distribution Certificate
date: 2026-01-05
severity: HIGH
category: fastlane
tags: [code-signing, certificates, match, testflight, app-store, macos]
symptoms:
  - "Provisioning profile doesn't include signing certificate"
  - "No signing certificate Mac Installer Distribution found"
  - Two certificates with identical names in keychain
root_cause: mac_installer_distribution certificate was incorrectly created as "Apple Distribution" instead of "3rd Party Mac Developer Installer"
solution: Delete incorrect certificate from Match repo and create correct Mac Installer Distribution certificate via Apple Developer Portal
files_affected:
  - fastlane/Fastfile
  - Match repo certs/mac_installer_distribution/
related:
  - match-certificate-file-formats.md
  - match-profile-certificate-mismatch.md
---

## macOS App Store Requires TWO Certificate Types

| Certificate Type | Common Name | Purpose |
|-----------------|-------------|---------|
| Apple Distribution | `Apple Distribution: Name (TEAM_ID)` | Signs the .app bundle |
| Mac Installer Distribution | `3rd Party Mac Developer Installer: Name (TEAM_ID)` | Signs the .pkg installer |

These are DIFFERENT certificate types with DIFFERENT names. Having two "Apple Distribution" certs is wrong.

## Fix

1. Delete incorrect certificate from Match repo
2. Create "Mac Installer Distribution" certificate on Apple Developer Portal (Certificates > Create > Mac Installer Distribution)
3. Run `bundle exec fastlane match mac_installer_distribution --platform macos`

## Prevention

After running `match mac_installer_distribution`, verify certificate name:
- Correct: `3rd Party Mac Developer Installer: Name (TEAM_ID)`
- Wrong: `Apple Distribution: Name (TEAM_ID)`
