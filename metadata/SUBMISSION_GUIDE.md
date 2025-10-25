# App Store Submission Guide for ListAll

This guide will walk you through submitting ListAll to the App Store using the metadata files in this folder.

## Prerequisites

- [ ] Apple Developer Program membership ($99/year)
- [ ] Xcode installed with command line tools
- [ ] Valid distribution certificate and provisioning profiles
- [ ] Screenshots prepared for all required device sizes
- [ ] Physical device testing completed

## Folder Structure

```
metadata/
├── en-US/
│   ├── description.txt              # App Store description (4000 chars max)
│   ├── promotional_text.txt         # Promotional text (170 chars max)
│   ├── keywords.txt                 # Keywords (100 chars max, comma separated)
│   ├── support_url.txt              # Support URL (required)
│   ├── marketing_url.txt            # Marketing URL (optional)
│   ├── privacy_policy_url.txt       # Privacy policy URL (required)
│   ├── release_notes.txt            # What's new in this version
│   └── screenshots/                 # Screenshots for all device sizes
│       └── README.md                # Screenshot guide
├── app_info.txt                     # App metadata (name, category, pricing, etc.)
├── app_privacy_questionnaire.txt    # Privacy answers for App Store Connect
└── SUBMISSION_GUIDE.md              # This file
```

## Step-by-Step Submission Process

### Phase 1: Prepare Build (30 minutes)

1. **Update Version Numbers** (if needed)
   ```bash
   # Current: Version 1.0, Build 1
   # Open ListAll.xcodeproj in Xcode
   # Select ListAll target → General → Identity
   # Update Version and Build if needed
   ```

2. **Clean and Archive**
   ```bash
   cd /Users/aleksi/source/ListAllApp/ListAll
   
   # Clean build folder
   xcodebuild clean -project ListAll.xcodeproj -scheme ListAll
   
   # Archive for iOS (requires valid Distribution certificate)
   xcodebuild archive \
     -project ListAll.xcodeproj \
     -scheme ListAll \
     -configuration Release \
     -archivePath build/ListAll.xcarchive \
     -destination "generic/platform=iOS"
   ```

3. **Validate Archive** (optional but recommended)
   - Open Xcode → Window → Organizer
   - Select Archives tab
   - Select your archive → Validate App
   - Fix any issues before uploading

### Phase 2: Upload to App Store Connect (15 minutes)

1. **Upload via Xcode**
   - Xcode → Window → Organizer → Archives
   - Select your archive → Distribute App
   - Choose "App Store Connect"
   - Follow the wizard, select automatic signing
   - Upload

2. **Wait for Processing**
   - Check App Store Connect after 10-30 minutes
   - Build will appear in TestFlight section first
   - Then available to add to app version

### Phase 3: Create App in App Store Connect (45 minutes)

1. **Log into App Store Connect**
   - Go to: https://appstoreconnect.apple.com
   - Sign in with your Apple ID

2. **Create New App**
   - Click "My Apps" → "+" → "New App"
   - Fill in:
     - **Platform**: iOS (watchOS included)
     - **Name**: ListAll
     - **Primary Language**: English (U.S.)
     - **Bundle ID**: io.github.chmc.ListAll
     - **SKU**: listall-ios-2025
     - **User Access**: Full Access

3. **Fill App Information**
   
   Navigate to: App Information section
   
   - **Name**: ListAll
   - **Subtitle**: Smart Lists with Sync
   - **Category**:
     - Primary: Productivity
     - Secondary: Utilities
   - **Content Rights**: Check if you own rights
   
   Copy from: `metadata/app_info.txt`

4. **Set Pricing and Availability**
   
   Navigate to: Pricing and Availability
   
   - **Price**: Free (or select tier)
   - **Availability**: All territories
   - **Pre-order**: Not available for first version

5. **Fill Privacy Policy**
   
   Navigate to: App Privacy
   
   - **Privacy Policy URL**: https://github.com/chmc/ListAllApp/blob/main/PRIVACY.md
   
   Then click "Get Started" for privacy questions:
   - "Does your app collect data?": **No**
   - "Third-party code?": **No**
   - "Track users?": **No**
   - Click "Publish"
   
   Reference: `metadata/app_privacy_questionnaire.txt`

### Phase 4: Prepare Version for Submission (60 minutes)

1. **Navigate to Version Section**
   - Click on "1.0 Prepare for Submission"

2. **App Store Screenshots**
   
   Upload screenshots for all required device sizes:
   
   **iPhone 6.9" (iPhone 16 Pro Max)**
   - Upload 3-10 screenshots
   - From: `metadata/en-US/screenshots/iPhone_6.9_*.png`
   
   **iPhone 6.7" (iPhone 15 Pro Max)**
   - Upload 3-10 screenshots
   - From: `metadata/en-US/screenshots/iPhone_6.7_*.png`
   
   **iPhone 6.5" (iPhone 11 Pro Max)**
   - Upload 3-10 screenshots
   - From: `metadata/en-US/screenshots/iPhone_6.5_*.png`
   
   **iPhone 5.5" (iPhone 8 Plus)**
   - Upload 3-10 screenshots
   - From: `metadata/en-US/screenshots/iPhone_5.5_*.png`
   
   **Apple Watch**
   - Upload 3-5 screenshots for each size
   - From: `metadata/en-US/screenshots/Watch_*.png`
   
   If you haven't created screenshots yet, see: `metadata/en-US/screenshots/README.md`

3. **Promotional Text** (optional, appears above description)
   
   Copy from: `metadata/en-US/promotional_text.txt`
   
   ```
   Smart lists that learn from you. Create, organize, and manage any type 
   of list with intelligent suggestions, photos, and Apple Watch support. 
   Privacy-first, no ads, no subscriptions.
   ```

4. **Description**
   
   Copy from: `metadata/en-US/description.txt`
   
   This is your main app description (4000 chars max). Paste the entire content.

5. **Keywords**
   
   Copy from: `metadata/en-US/keywords.txt`
   
   ```
   list,shopping,todo,tasks,organize,checklist,grocery,watch,sync,smart,suggestions,photos,items,inventory,packing
   ```
   
   Note: Max 100 characters including commas. No spaces after commas.

6. **Support URL** (required)
   
   Copy from: `metadata/en-US/support_url.txt`
   
   ```
   https://github.com/chmc/ListAllApp
   ```

7. **Marketing URL** (optional)
   
   Copy from: `metadata/en-US/marketing_url.txt`
   
   ```
   https://github.com/chmc/ListAllApp
   ```

8. **What's New in This Version**
   
   Copy from: `metadata/en-US/release_notes.txt`
   
   This describes what's new in version 1.0.

9. **Build Selection**
   
   - Click "+" next to Build
   - Select the build you uploaded earlier
   - Wait for build to finish processing if not available yet

10. **App Icon**
    
    Should be automatically pulled from your uploaded build.
    - Verify it's correct (1024x1024 PNG)
    - If missing, upload from: `ListAll/ListAll/Assets.xcassets/AppIcon.appiconset/`

11. **Age Rating**
    
    Click "Edit" next to Age Rating
    
    Answer questionnaire (all should be "None"):
    - Cartoon or Fantasy Violence: **None**
    - Realistic Violence: **None**
    - Profanity or Crude Humor: **None**
    - Sexual Content or Nudity: **None**
    - Alcohol, Tobacco, or Drug Use: **None**
    - Mature/Suggestive Themes: **None**
    - Horror/Fear Themes: **None**
    - Medical/Treatment Information: **None**
    - Gambling: **None**
    
    Result: **4+** (suitable for all ages)

12. **Copyright**
    
    ```
    © 2025 Aleksi Sutela. All rights reserved.
    ```

### Phase 5: App Review Information (10 minutes)

1. **Sign-in Information**
   - **Sign-in required?**: No
   - ListAll doesn't require login

2. **Contact Information**
   - **First Name**: Aleksi
   - **Last Name**: Sutela
   - **Phone Number**: [Your phone number]
   - **Email**: [Your email]

3. **Notes for Reviewer**
   
   Copy from: `metadata/app_info.txt` (Review Notes section)
   
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

4. **Demo Account** (if needed)
   - Not needed for ListAll (no login required)

5. **Attachment** (if needed)
   - Only if you need to explain something complex
   - Can attach demo video or additional documentation

### Phase 6: Version Release Options (2 minutes)

Choose release option:

- **Manually release this version**: You control when it goes live after approval
- **Automatically release this version**: Goes live immediately after approval
- **Automatically release using App Store Connect**: Schedule specific date/time

**Recommendation**: Choose "Manually release" for first version so you can verify everything before going live.

### Phase 7: Submit for Review (5 minutes)

1. **Review All Information**
   - Go through each section and verify accuracy
   - Check all screenshots are correct
   - Verify description has no typos
   - Ensure all URLs are accessible

2. **Export Compliance**
   
   You'll be asked about encryption:
   
   - **Does your app use encryption?**: Yes
   - **Is your app exempt from regulations?**: Yes
   - **Reason**: Standard encryption (HTTPS, iCloud)
   
   Select: "Your app uses standard encryption"

3. **Advertising Identifier**
   
   - **Does this app use IDFA?**: No
   - ListAll doesn't track or advertise

4. **Content Rights and Age Rating**
   
   - Review and confirm
   - Ensure age rating is 4+

5. **Final Submission**
   
   - Click "Add for Review" at the top
   - Confirm submission
   - Status changes to "Waiting for Review"

### Phase 8: After Submission (Ongoing)

1. **Monitor Status**
   - Check App Store Connect daily
   - Status progression:
     - "Waiting for Review" (1-2 days typically)
     - "In Review" (1-2 hours)
     - "Pending Developer Release" or "Ready for Sale"

2. **Respond to Reviewers**
   - If they have questions, respond promptly
   - Be polite and helpful
   - Provide any additional information needed

3. **If Rejected**
   - Read rejection reason carefully
   - Fix issues in your app
   - Upload new build
   - Submit again
   - Reference original submission in notes

4. **If Approved**
   - Release manually if you chose that option
   - Test download from App Store
   - Share with friends/family
   - Monitor reviews and ratings
   - Plan for updates

## Common Rejection Reasons and How to Avoid

### 1. Missing or Broken Privacy Policy
- ✅ We have: `PRIVACY.md` in repo
- ✅ Accessible at: https://github.com/chmc/ListAllApp/blob/main/PRIVACY.md
- Make sure it's publicly accessible

### 2. App Not Working
- ✅ Test thoroughly before submission
- ✅ All features should work without setup
- ✅ Include clear testing instructions

### 3. Misleading Metadata
- ✅ Screenshots match actual app
- ✅ Description is accurate
- ✅ Don't promise features not in app

### 4. Insufficient Testing Instructions
- ✅ We have detailed notes in app_info.txt
- ✅ Explain all features clearly
- ✅ Note permissions and why needed

### 5. Permission Issues
- ✅ Camera usage string present in code
- ✅ Photo library usage string present
- ✅ Face ID usage string present
- ✅ All permissions have clear explanations

## Tips for Faster Approval

1. **Complete Information**: Fill everything out thoroughly
2. **Clear Screenshots**: Show actual features, high quality
3. **Good Testing Notes**: Help reviewer test quickly
4. **Responsive**: Answer questions quickly if asked
5. **Follow Guidelines**: Read App Store Review Guidelines

## Updating the App Later

When releasing version 1.1 or later:

1. Update files in `metadata/en-US/`:
   - `release_notes.txt` - What's new
   - Screenshots (if UI changed)
   - Description (if features added)

2. Create new version in App Store Connect
3. Upload new build
4. Copy metadata from these files
5. Submit for review

## Helpful Resources

- **App Store Connect**: https://appstoreconnect.apple.com
- **Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **Screenshot Specs**: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- **Privacy Policy Requirements**: https://developer.apple.com/app-store/review/guidelines/#privacy
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/

## Troubleshooting

### Build Not Appearing in App Store Connect
- Wait 10-30 minutes after upload
- Check email for errors from Apple
- Verify provisioning profiles are correct
- Try uploading again

### Screenshot Upload Fails
- Check file format (PNG only)
- Verify resolution matches exactly
- File size under 500KB (usually)
- Try different browser

### Privacy Questions Confusing
- If you don't collect data, answer "No" to first question
- Reference: `metadata/app_privacy_questionnaire.txt`
- If confused, err on side of disclosure

### Metadata Won't Save
- Check character limits (Description: 4000, Keywords: 100)
- No special characters in keywords
- URLs must be valid and accessible
- Try different browser

## Checklist Before Submitting

- [ ] App builds without errors
- [ ] All tests pass (378/378)
- [ ] Tested on physical iPhone
- [ ] Tested on physical Apple Watch
- [ ] All screenshots prepared
- [ ] Privacy policy accessible online
- [ ] Support URL works
- [ ] Description proofread
- [ ] Keywords within 100 char limit
- [ ] Contact information correct
- [ ] Review notes comprehensive
- [ ] Age rating appropriate
- [ ] Build uploaded and processed
- [ ] Metadata copied correctly

## Post-Launch Checklist

- [ ] Download app from App Store
- [ ] Test basic functionality
- [ ] Monitor crash reports
- [ ] Respond to user reviews
- [ ] Plan first update
- [ ] Share on social media
- [ ] Collect user feedback

---

**Good luck with your submission!**

If you have questions, refer to:
- `docs/appstore_submission_checklist.md` - Detailed technical checklist
- `PRIVACY.md` - Privacy policy
- `metadata/app_info.txt` - All app metadata
- `metadata/app_privacy_questionnaire.txt` - Privacy answers

**Estimated Total Time**: 3-4 hours for first submission
**Estimated Review Time**: 1-3 days
**Total Time to App Store**: 4-7 days from start to live

Last Updated: October 25, 2025

