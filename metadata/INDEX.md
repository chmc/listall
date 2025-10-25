# App Store Metadata - Complete Index

## 📁 Folder Structure Overview

```
metadata/
├── INDEX.md                          ← You are here
├── README.md                         ← Start here for overview
├── SUBMISSION_GUIDE.md               ← Step-by-step submission instructions
├── QUICK_REFERENCE.md                ← Quick reference card (print this!)
├── validate_metadata.sh              ← Validation script
│
├── app_info.txt                      ← App metadata (name, category, etc.)
├── app_privacy_questionnaire.txt     ← Privacy answers for App Store
├── routing_app_coverage.geojson      ← Not needed (placeholder only)
│
└── en-US/                            ← English (U.S.) localization
    ├── description.txt               ← App Store description (4000 chars)
    ├── promotional_text.txt          ← Promotional text (170 chars)
    ├── keywords.txt                  ← Search keywords (100 chars)
    ├── support_url.txt               ← Support URL (required)
    ├── marketing_url.txt             ← Marketing URL (optional)
    ├── privacy_policy_url.txt        ← Privacy policy URL (required)
    ├── release_notes.txt             ← What's new in this version
    └── screenshots/                  ← Screenshots for all devices
        └── README.md                 ← Screenshot guide

Additional file (root directory):
../PRIVACY.md                         ← Full privacy policy (public)
```

---

## 🚀 Quick Start Paths

### Path 1: I'm Ready to Submit Right Now
1. Read: `QUICK_REFERENCE.md` (5 min)
2. Run: `./validate_metadata.sh` (1 min)
3. Create screenshots (see `en-US/screenshots/README.md`) (2-3 hours)
4. Follow: `SUBMISSION_GUIDE.md` (2-3 hours)
5. Submit! 🎉

### Path 2: I Want to Understand Everything First
1. Read: `README.md` - Overview and concepts
2. Read: `SUBMISSION_GUIDE.md` - Detailed walkthrough
3. Review: `app_info.txt` - All metadata
4. Review: `app_privacy_questionnaire.txt` - Privacy details
5. Read: `en-US/screenshots/README.md` - Screenshot requirements
6. Use: `QUICK_REFERENCE.md` during submission

### Path 3: I Just Need Specific Information
- **App description**: `en-US/description.txt`
- **Keywords**: `en-US/keywords.txt`
- **URLs**: `en-US/support_url.txt`, `en-US/privacy_policy_url.txt`
- **Privacy answers**: `app_privacy_questionnaire.txt`
- **Testing notes**: `app_info.txt` (Review Notes section)
- **Screenshot guide**: `en-US/screenshots/README.md`

---

## 📄 File Reference Guide

### Core Documentation Files

| File | Purpose | When to Use |
|------|---------|-------------|
| **README.md** | Overview and general information | First time setup, understanding structure |
| **SUBMISSION_GUIDE.md** | Complete step-by-step submission process | During actual submission |
| **QUICK_REFERENCE.md** | Quick access to all copy/paste content | Keep open during submission |
| **INDEX.md** | This file - navigation guide | Finding what you need |

### Metadata Content Files

| File | Content | Character Limit | Required |
|------|---------|-----------------|----------|
| **app_info.txt** | App name, category, pricing, copyright, age rating, review notes | N/A | ✓ Reference |
| **app_privacy_questionnaire.txt** | Complete privacy questionnaire answers | N/A | ✓ Reference |
| **description.txt** | Full App Store description | 4000 | ✓ Required |
| **promotional_text.txt** | Short promotional text | 170 | Optional |
| **keywords.txt** | Search keywords (comma-separated) | 100 | ✓ Required |
| **support_url.txt** | Customer support URL | N/A | ✓ Required |
| **marketing_url.txt** | Marketing website URL | N/A | Optional |
| **privacy_policy_url.txt** | Privacy policy URL | N/A | ✓ Required |
| **release_notes.txt** | What's new in this version | 4000 | ✓ Required |

### Utility Files

| File | Purpose | Usage |
|------|---------|-------|
| **validate_metadata.sh** | Validates all files and checks limits | Run before submission: `./metadata/validate_metadata.sh` |
| **routing_app_coverage.geojson** | Not needed for ListAll | Ignore (only for navigation apps) |

### Additional Files

| File | Location | Purpose |
|------|----------|---------|
| **PRIVACY.md** | Root directory | Full privacy policy (must be publicly accessible) |
| **en-US/screenshots/README.md** | Screenshots folder | Detailed guide for creating screenshots |

---

## 🎯 Task-Specific Guide

### Task: "I need to fill out App Store Connect"

**What to do:**
1. Keep `QUICK_REFERENCE.md` open - it has all copy/paste content
2. Follow `SUBMISSION_GUIDE.md` step-by-step
3. Copy content from files in `en-US/` folder as needed

**Files you'll use:**
- `en-US/description.txt` → App Store description field
- `en-US/keywords.txt` → Keywords field
- `en-US/promotional_text.txt` → Promotional text field
- `en-US/support_url.txt` → Support URL field
- `en-US/privacy_policy_url.txt` → Privacy Policy URL field
- `app_info.txt` → App name, category, copyright, review notes
- `app_privacy_questionnaire.txt` → Privacy section answers

### Task: "I need to answer the privacy questions"

**What to do:**
1. Open `app_privacy_questionnaire.txt`
2. The answers are simple:
   - Does your app collect data? **No**
   - Third-party code? **No**
   - Track users? **No**
3. That's it! Details in the file explain why.

### Task: "I need to create screenshots"

**What to do:**
1. Read `en-US/screenshots/README.md` completely
2. Use Xcode simulators for all required sizes
3. Save screenshots to `en-US/screenshots/` with proper naming:
   - `iPhone_6.9_1.png`, `iPhone_6.9_2.png`, etc.
   - `iPhone_6.7_1.png`, `iPhone_6.7_2.png`, etc.
   - `Watch_46mm_1.png`, `Watch_Ultra_1.png`, etc.

**Required:**
- iPhone 6.9" (16 Pro Max): 3-10 screenshots
- iPhone 6.7" (15 Pro Max): 3-10 screenshots
- iPhone 6.5" (11 Pro Max): 3-10 screenshots
- iPhone 5.5" (8 Plus): 3-10 screenshots
- Apple Watch (all sizes): 3-5 screenshots each

### Task: "I need to write review notes for Apple"

**What to do:**
1. Open `app_info.txt`
2. Scroll to "REVIEW NOTES" section
3. Copy the entire section to App Store Connect "Notes for Reviewer" field

It includes:
- Testing instructions
- watchOS testing steps
- Permission explanations
- Special notes

### Task: "I need to validate everything before submission"

**What to do:**
```bash
cd /Users/aleksi/source/ListAllApp
./metadata/validate_metadata.sh
```

This will check:
- All required files exist
- Character limits are not exceeded
- URLs are valid format
- Screenshots are present (with count)
- Content preview

### Task: "I need to add another language"

**What to do:**
1. Copy `en-US/` folder to new language code:
   ```bash
   cp -r metadata/en-US/ metadata/fr-FR/  # For French
   ```
2. Translate all .txt files in new folder
3. Create localized screenshots
4. In App Store Connect:
   - Add new localization
   - Upload translated metadata
   - Upload localized screenshots

Common language codes:
- `en-US` - English (U.S.)
- `en-GB` - English (U.K.)
- `fr-FR` - French
- `de-DE` - German
- `es-ES` - Spanish
- `ja` - Japanese
- `zh-Hans` - Chinese (Simplified)

---

## 📋 Submission Checklist Reference

Quick checklist of what you need:

### Before You Start
- [ ] Apple Developer Program membership ($99/year)
- [ ] Xcode with valid distribution certificate
- [ ] App tested on physical devices

### Metadata Ready
- [ ] All files in `en-US/` folder created ✓
- [ ] Character limits checked (run `validate_metadata.sh`)
- [ ] Privacy policy accessible at URL
- [ ] Contact information prepared

### Screenshots Ready
- [ ] iPhone 6.9" - at least 3 screenshots
- [ ] iPhone 6.7" - at least 3 screenshots
- [ ] iPhone 6.5" - at least 3 screenshots
- [ ] iPhone 5.5" - at least 3 screenshots
- [ ] Apple Watch - at least 3 screenshots per size

### Build Ready
- [ ] App builds successfully
- [ ] All tests pass (378/378)
- [ ] Archive created and validated
- [ ] Uploaded to App Store Connect
- [ ] Build processed and available

### Submission Complete
- [ ] Metadata copied to App Store Connect
- [ ] Screenshots uploaded
- [ ] Privacy questions answered
- [ ] Age rating completed
- [ ] Review notes provided
- [ ] Submitted for review

---

## 🔍 Common Questions

### Q: Which file do I start with?
**A:** Start with `README.md` for overview, then `SUBMISSION_GUIDE.md` for step-by-step instructions.

### Q: What if I just want to copy/paste everything quickly?
**A:** Use `QUICK_REFERENCE.md` - it has all copy/paste ready content.

### Q: How do I know if my metadata is valid?
**A:** Run `./metadata/validate_metadata.sh` from the project root.

### Q: Where do I put screenshots?
**A:** In `en-US/screenshots/` folder with specific naming (see `en-US/screenshots/README.md`).

### Q: What's the privacy policy URL?
**A:** `https://github.com/chmc/ListAllApp/blob/main/PRIVACY.md` (from `en-US/privacy_policy_url.txt`)

### Q: Do I need the routing_app_coverage.geojson file?
**A:** No! ListAll is not a routing/navigation app. You can ignore or delete that file.

### Q: How long will this take?
**A:**
- Metadata preparation: 1 hour (already done!)
- Screenshot creation: 2-3 hours
- App Store Connect form filling: 1-2 hours
- Review time: 1-3 days
- **Total: 2-4 days to launch**

### Q: What if I get rejected?
**A:** Don't worry! Read the rejection reason, fix the issue, and resubmit. Common issues are clearly explained in `SUBMISSION_GUIDE.md`.

---

## 🎓 Learning Resources

### Apple Official Documentation
- [App Store Connect Guide](https://developer.apple.com/app-store-connect/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [Privacy Guidelines](https://developer.apple.com/app-store/review/guidelines/#privacy)

### Project Documentation
- `docs/appstore_submission_checklist.md` - Comprehensive technical checklist
- `docs/appstore_quick_start.md` - Quick start guide
- `PRIVACY.md` - Full privacy policy

---

## 📊 Metadata Statistics

**Total Files Created:** 15 files + 1 folder structure

**Content Statistics:**
- Description: ~1,800 characters (limit: 4,000) ✓
- Keywords: 99 characters (limit: 100) ✓
- Promotional Text: 154 characters (limit: 170) ✓
- Release Notes: ~900 characters (limit: 4,000) ✓

**Languages Supported:** 1 (en-US)
- Easy to add more languages by copying folder

**Screenshot Slots Available:** 0 (need to create)
- iPhone 6.9": 0/10 needed
- iPhone 6.7": 0/10 needed
- iPhone 6.5": 0/10 needed
- iPhone 5.5": 0/10 needed
- Apple Watch: 0/15 needed

---

## 🔄 Maintenance

### When to Update These Files

**For every app update (1.1, 1.2, etc.):**
- Update `release_notes.txt` with what's new
- Update `description.txt` if features changed
- Update screenshots if UI changed significantly
- Increment version number in `app_info.txt`

**Rarely changed:**
- `keywords.txt` - Only if app focus changes
- `promotional_text.txt` - Only for marketing refresh
- Privacy files - Only if data handling changes
- Support/marketing URLs - Only if URLs change

### Version Control

All these files are tracked in Git:
```bash
git add metadata/
git commit -m "chore: update metadata for v1.1"
git tag v1.1-submitted
git push origin main --tags
```

---

## 📞 Getting Help

**For submission issues:**
1. Check `SUBMISSION_GUIDE.md` troubleshooting section
2. Review `QUICK_REFERENCE.md` for quick answers
3. Check Apple's documentation links above

**For privacy questions:**
1. Read `app_privacy_questionnaire.txt` (has detailed explanations)
2. Review `PRIVACY.md` for full policy
3. Reference is clear: we don't collect data = answer "No"

**For screenshot issues:**
1. Read `en-US/screenshots/README.md` completely
2. Check resolution requirements
3. Use Xcode's native screenshot feature (Cmd+S)

**For validation issues:**
1. Run `./metadata/validate_metadata.sh`
2. Fix any errors or warnings shown
3. Re-run to verify fixes

---

## ✅ Final Pre-Submission Checklist

Before you click "Submit for Review":

- [ ] Read `SUBMISSION_GUIDE.md` completely
- [ ] Run `./metadata/validate_metadata.sh` - all green
- [ ] All screenshots created and in place
- [ ] Privacy policy URL accessible in browser
- [ ] Support URL accessible in browser
- [ ] Build uploaded and processed in App Store Connect
- [ ] All metadata copied to App Store Connect
- [ ] Review notes filled in
- [ ] Contact information filled in
- [ ] Age rating completed (should be 4+)
- [ ] Export compliance answered (standard encryption)
- [ ] Privacy questions answered (all "No")
- [ ] Reviewed everything one final time

**Ready?** Click "Submit for Review" and wait 1-3 days! 🚀

---

**Document Version:** 1.0  
**Last Updated:** October 25, 2025  
**Maintained By:** Aleksi Sutela  
**Status:** Ready for App Store submission

---

## 🎯 TL;DR - Super Quick Start

1. **Want to submit now?** 
   → Read `QUICK_REFERENCE.md` (5 min)
   → Follow `SUBMISSION_GUIDE.md` (2-3 hours)

2. **Need to create screenshots?**
   → Read `en-US/screenshots/README.md`
   → Use Xcode simulators
   → Save to `en-US/screenshots/`

3. **Want to validate?**
   → Run `./metadata/validate_metadata.sh`

4. **Need specific text?**
   → Open files in `en-US/` folder
   → Copy/paste to App Store Connect

**Everything is ready to go!** 🎉

