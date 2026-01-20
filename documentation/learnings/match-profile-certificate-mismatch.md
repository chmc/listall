---
title: Match Provisioning Profile Certificate Mismatch from Manual Creation
date: 2026-01-05
severity: HIGH
category: fastlane
tags: [match, provisioning-profiles, certificates, code-signing]
symptoms:
  - "Provisioning profile doesn't include signing certificate"
  - Profile name shows "match Unknown..." instead of "match AppStore..."
  - Code signing fails despite valid certificate
root_cause: Provisioning profile was created manually on Apple Developer Portal instead of via Match, causing certificate mismatch
solution: Regenerate profile via Match to link it with the correct certificate
files_affected:
  - fastlane/Fastfile
  - Match repo profiles/appstore/
related:
  - macos-installer-certificate-type.md
  - match-certificate-file-formats.md
---

## Why This Happens

When a profile is created manually on Apple Developer Portal:
1. It gets associated with whichever certificate was selected at creation time
2. Match can't know which certificate was used
3. Profile name becomes "match Unknown..." instead of "match AppStore..."
4. Certificate in Match repo doesn't match the one embedded in profile

## Fix: Regenerate via Match

```bash
# Set ASC credentials
export ASC_KEY_ID="your_key_id"
export ASC_ISSUER_ID="your_issuer_id"
export ASC_KEY_BASE64="$(cat /path/to/AuthKey.p8 | base64)"

# Regenerate profile
bundle exec fastlane refresh_macos_profiles
```

This deletes the old profile and creates a new one linked to the Match certificate.

## Prevention

Always use Match to create provisioning profiles:

```bash
bundle exec fastlane match appstore --platform macos --app_identifier io.github.chmc.ListAll
```

Never create profiles manually on Apple Developer Portal when using Match.
