# macOS App Store Submission Requirements

## Date: 2026-01-05

## Status: RESOLVED

## Problem
macOS app archive passed but upload to TestFlight failed with:
```
The product archive is invalid. The Info.plist must contain a LSApplicationCategoryType key
```

## Solution
Add `LSApplicationCategoryType` to the macOS app's Info.plist:

```xml
<key>LSApplicationCategoryType</key>
<string>public.app-category.productivity</string>
```

## Valid Category Values
Common categories include:
- `public.app-category.productivity`
- `public.app-category.utilities`
- `public.app-category.developer-tools`
- `public.app-category.business`
- `public.app-category.finance`
- `public.app-category.education`

Full list: [Apple Documentation - LSApplicationCategoryType](https://developer.apple.com/documentation/bundleresources/information_property_list/lsapplicationcategorytype)

## Related Files
- `ListAll/ListAllMac/Info.plist`

## Note
This is required for macOS App Store submissions but not for iOS. iOS apps use the primary category set in App Store Connect instead.
