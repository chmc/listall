# Quick Reference Card - App Store Submission

## Essential Information at a Glance

### App Identity
- **Name**: ListAll
- **Subtitle**: Smart Lists with Sync
- **Bundle ID**: io.github.chmc.ListAll
- **SKU**: listall-ios-2025
- **Version**: 1.0 (Build 1)

### Categories
- **Primary**: Productivity
- **Secondary**: Utilities
- **Age Rating**: 4+

### URLs (Copy/Paste Ready)
```
Support URL:
https://github.com/chmc/ListAllApp

Marketing URL:
https://github.com/chmc/ListAllApp

Privacy Policy URL:
https://github.com/chmc/ListAllApp/blob/main/PRIVACY.md
```

### Keywords (100 chars - Copy/Paste Ready)
```
list,shopping,todo,tasks,organize,checklist,grocery,watch,sync,smart,suggestions,photos,items,inventory,packing
```

### Promotional Text (170 chars - Copy/Paste Ready)
```
Smart lists that learn from you. Create, organize, and manage any type of list with intelligent suggestions, photos, and Apple Watch support. Privacy-first, no ads, no subscriptions.
```

### Copyright
```
© 2025 Aleksi Sutela. All rights reserved.
```

---

## Required Screenshots

| Device | Resolution | Count | File Pattern |
|--------|-----------|-------|--------------|
| iPhone 6.9" (16 Pro Max) | 1320×2868 | 3-10 | `iPhone_6.9_*.png` |
| iPhone 6.7" (15 Pro Max) | 1290×2796 | 3-10 | `iPhone_6.7_*.png` |
| iPhone 6.5" (11 Pro Max) | 1242×2688 | 3-10 | `iPhone_6.5_*.png` |
| iPhone 5.5" (8 Plus) | 1242×2208 | 3-10 | `iPhone_5.5_*.png` |
| Apple Watch (All sizes) | Varies | 3-5 each | `Watch_*.png` |

---

## Privacy Answers (Quick Fill)

**Does your app collect data?** → **No**

**Does this app use third-party code?** → **No**

**Do you or your third-party partners track users?** → **No**

**That's it!** ✓

---

## Age Rating Quick Answers

All categories: **None**
- Violence: None
- Sexual Content: None
- Profanity: None
- Alcohol/Drugs: None
- Gambling: None
- Medical Info: None

**Result**: 4+ (All Ages)

---

## Export Compliance Quick Answers

**Does your app use encryption?** → **Yes**

**Is it exempt from regulations?** → **Yes**

**Reason**: Standard encryption (HTTPS, iCloud)

**Select**: "Your app uses standard encryption"

---

## App Review Testing Notes (Copy/Paste Ready)

```
ListAll is a privacy-focused list management app with iOS and watchOS support.

KEY TESTING INSTRUCTIONS:
1. Create a new list by tapping the + button on main screen
2. Add items to the list with title, description, and quantity
3. Test adding photos to items using camera or photo library
4. Type similar item names multiple times to see smart suggestions appear
5. Cross out items by tapping the checkbox
6. Archive the list from the list menu (3 dots)
7. Test Face ID/Touch ID lock from Settings (if available on test device)

WATCHOS TESTING:
1. Open the watchOS app on paired Apple Watch
2. Lists should sync automatically from iPhone
3. Tap items to mark as complete
4. Changes sync back to iPhone immediately

PRIVACY PERMISSIONS:
- Camera: Used to attach photos to list items
- Photo Library: Used to select existing photos for list items
- Face ID/Touch ID: Optional security feature to lock the app
- iCloud: Optional sync feature (disabled by default)

NO THIRD-PARTY SERVICES:
- All data stored locally or in user's iCloud
- No analytics or tracking
- No ads, subscriptions, or in-app purchases

SPECIAL NOTES:
- App works completely offline
- No account creation required
- All features available immediately
- Sample data can be generated from Settings for testing
```

---

## Common Xcode Build Commands

### Clean Build
```bash
cd /Users/aleksi/source/ListAllApp/ListAll
xcodebuild clean -project ListAll.xcodeproj -scheme ListAll
```

### Archive for Distribution
```bash
xcodebuild archive \
  -project ListAll.xcodeproj \
  -scheme ListAll \
  -configuration Release \
  -archivePath build/ListAll.xcarchive \
  -destination "generic/platform=iOS"
```

### Validate Before Upload
```bash
xcodebuild -exportArchive \
  -archivePath build/ListAll.xcarchive \
  -exportPath build/ListAll-IPA \
  -exportOptionsPlist ExportOptions.plist
```

---

## Metadata Files Quick Check

### Validate Metadata
```bash
cd /Users/aleksi/source/ListAllApp
./metadata/validate_metadata.sh
```

### Check Character Counts
```bash
# Description (max 4000)
wc -c metadata/en-US/description.txt

# Keywords (max 100)
wc -c metadata/en-US/keywords.txt

# Promotional text (max 170)
wc -c metadata/en-US/promotional_text.txt
```

### View Files
```bash
# Description
cat metadata/en-US/description.txt

# Keywords
cat metadata/en-US/keywords.txt

# URLs
cat metadata/en-US/support_url.txt
cat metadata/en-US/privacy_policy_url.txt
```

---

## Screenshot Checklist

### Suggested Screenshot Order

**iPhone Screenshots (7 total)**
1. ✓ Main lists view (multiple lists)
2. ✓ List detail with items
3. ✓ Item with photos (swipeable gallery)
4. ✓ Smart suggestions in action
5. ✓ Archive view
6. ✓ Settings with Face ID
7. ✓ Export/share options

**Apple Watch Screenshots (3 total)**
1. ✓ Watch lists view
2. ✓ Watch items view
3. ✓ Item completion

### Capture Screenshots
```bash
# Launch simulator
xcrun simctl list devices | grep "iPhone 16 Pro Max"

# Take screenshot (Cmd+S in Simulator)
# Or programmatically:
xcrun simctl io booted screenshot ~/Desktop/screenshot.png
```

---

## Status Checklist

### Before Submission
- [ ] Build compiles without errors
- [ ] All tests pass (378/378)
- [ ] Tested on physical iPhone
- [ ] Tested on physical Apple Watch
- [ ] All metadata files created
- [ ] Screenshots captured
- [ ] Privacy policy accessible online
- [ ] Character limits checked
- [ ] Contact info filled in

### During Submission
- [ ] Build uploaded to App Store Connect
- [ ] Build processed successfully
- [ ] Metadata copied from files
- [ ] Screenshots uploaded
- [ ] Privacy questions answered
- [ ] Age rating completed
- [ ] Export compliance answered
- [ ] Review notes provided
- [ ] Submitted for review

### After Submission
- [ ] Status: "Waiting for Review"
- [ ] Monitor App Store Connect daily
- [ ] Ready to respond to questions
- [ ] Prepared for potential rejection
- [ ] Plan for post-launch monitoring

---

## Important Links (Quick Access)

| Service | URL |
|---------|-----|
| App Store Connect | https://appstoreconnect.apple.com |
| Developer Portal | https://developer.apple.com |
| Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| Screenshot Specs | https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications |
| GitHub Repo | https://github.com/chmc/ListAllApp |
| Privacy Policy | https://github.com/chmc/ListAllApp/blob/main/PRIVACY.md |

---

## Timeline Estimate

| Phase | Duration |
|-------|----------|
| Metadata preparation | 1 hour |
| Screenshot creation | 2-3 hours |
| App Store Connect setup | 1 hour |
| Build upload | 30 min |
| Form filling | 1 hour |
| **Total preparation** | **5-6 hours** |
| Review time | 1-3 days |
| **Total to launch** | **2-4 days** |

---

## Contact Information Template

```
First Name: Aleksi
Last Name: Sutela
Phone Number: [YOUR_PHONE]
Email Address: [YOUR_EMAIL]

Demo Account: Not required (no login system)
```

---

## Emergency Contacts

**If stuck during submission:**
1. Check `SUBMISSION_GUIDE.md` for detailed steps
2. Review `app_info.txt` for all metadata
3. Check `app_privacy_questionnaire.txt` for privacy answers
4. See `en-US/screenshots/README.md` for screenshot help

**Apple Support:**
- Developer Forums: https://developer.apple.com/forums/
- App Review: https://developer.apple.com/contact/app-store/

---

## Version History Quick Log

### Version 1.0 (Current)
- **Status**: Ready for submission
- **Build**: 1
- **Date**: October 25, 2025
- **Notes**: Initial release

### Future Versions
```
v1.1 - [Feature updates]
v1.2 - [Bug fixes]
```

---

## Quick Validation Commands

```bash
# Full validation
./metadata/validate_metadata.sh

# Quick checks
ls -la metadata/en-US/*.txt
wc -c metadata/en-US/{description,keywords,promotional_text}.txt
cat metadata/en-US/support_url.txt

# Screenshot count
ls metadata/en-US/screenshots/*.png | wc -l

# Build and test
cd ListAll && xcodebuild test -project ListAll.xcodeproj -scheme ListAll
```

---

**Print this card for quick reference during submission!**

Last Updated: October 25, 2025

