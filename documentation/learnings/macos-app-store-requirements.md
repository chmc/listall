---
title: macOS App Store Requires LSApplicationCategoryType in Info.plist
date: 2026-01-05
severity: MEDIUM
category: macos
tags: [app-store, testflight, info-plist, submission]
symptoms:
  - "The product archive is invalid"
  - "Info.plist must contain a LSApplicationCategoryType key"
  - Archive succeeds but upload fails
root_cause: macOS App Store submissions require LSApplicationCategoryType key in Info.plist (iOS uses App Store Connect instead)
solution: Add LSApplicationCategoryType key with valid category value to macOS Info.plist
files_affected:
  - ListAll/ListAllMac/Info.plist
related: [macos-installer-certificate-type.md, macos-screenshot-generation.md]
---

## Fix

Add to macOS Info.plist:

```xml
<key>LSApplicationCategoryType</key>
<string>public.app-category.productivity</string>
```

## Valid Categories

- `public.app-category.productivity`
- `public.app-category.utilities`
- `public.app-category.developer-tools`
- `public.app-category.business`
- `public.app-category.finance`
- `public.app-category.education`

Full list: [Apple LSApplicationCategoryType Documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype)

## Note

This is macOS-specific. iOS apps use the primary category set in App Store Connect.
