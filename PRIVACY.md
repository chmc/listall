# Privacy Policy for ListAll

**Effective Date:** October 25, 2025
**Last Updated:** December 10, 2025

## Overview

ListAll ("we", "our", or "the app") is committed to protecting your privacy. This Privacy Policy explains how ListAll handles your data when you use our iOS, watchOS, and macOS applications.

## Our Privacy Commitment

**ListAll is designed with privacy as a core principle:**

- We do NOT collect any personal information
- We do NOT track your usage or behavior
- We do NOT use analytics or tracking services
- We do NOT share your data with third parties
- We do NOT display advertisements
- We do NOT require account creation or login

## Data Storage and Collection

### What Data is Stored Locally

ListAll stores the following data **locally on your device only**:

1. **Lists**: Names and organization of your lists
2. **Items**: Titles, descriptions, quantities, and completion status of items
3. **Photos**: Images you attach to items (stored in app's local database)
4. **User Preferences**: App settings like Face ID lock preference, theme choice
5. **Suggestion History**: Local history of items you've created (used for smart suggestions)

All this data is stored in:
- Your device's secure storage (Core Data database)
- App Groups container (for syncing between iPhone, Apple Watch, and Mac)

### iCloud Sync

If you are signed into iCloud on your device, ListAll automatically syncs your data:

- Your list data is synchronized to **your personal iCloud account**
- Data is encrypted in transit and at rest using Apple's iCloud security
- We do NOT have access to your iCloud data
- Only you can access your synced data through your Apple ID
- Sync works automatically across your iPhone, Apple Watch, and Mac

**Note:** To disable iCloud sync, you can sign out of iCloud in System Settings (this affects all apps using iCloud).

## Data We Do NOT Collect

ListAll does NOT collect, transmit, or have access to:

- Personal identity information (name, email, phone number)
- Location data
- Device identifiers
- Usage analytics or statistics
- Crash reports (unless you explicitly send them via Apple's system)
- Search queries or browsing history
- Contact information
- Any data that leaves your device (except via iCloud if enabled)

## Permissions and Why We Need Them

### Camera Access (iOS only)
- **Purpose**: To let you take photos and attach them to list items
- **Usage**: Only activated when you tap the camera button
- **Storage**: Photos are stored locally in the app's database
- **Not Used For**: Facial recognition, location tracking, or any other purpose

### Photo Library Access (iOS only)
- **Purpose**: To let you select existing photos from your library
- **Usage**: Only activated when you tap the photo picker button
- **Storage**: Selected photos are copied to the app's database
- **Not Used For**: Browsing your library, analyzing photos, or any other purpose

### Drag-and-Drop / Clipboard (macOS only)
- **Purpose**: To add images to list items via drag-and-drop from Finder or clipboard paste
- **Usage**: Only activated when you explicitly drag an image into the app or paste from clipboard
- **Storage**: Images are copied to the app's database; original files are not retained
- **Not Used For**: Background clipboard monitoring or accessing files without your action

### Face ID / Touch ID
- **Purpose**: Optional security feature to lock the app
- **Usage**: Only used for local authentication on your device
- **Storage**: No biometric data is stored or transmitted
- **Not Used For**: Identification or any cloud service

### iCloud
- **Purpose**: Optional backup and sync across your devices
- **Usage**: Syncs your lists to your personal iCloud account
- **Storage**: Data stored in your private iCloud container
- **Not Used For**: Sharing with us or third parties

### Services Menu (macOS only)
- **Purpose**: Add items to ListAll from any app via right-click Services menu
- **Usage**: Only activated when you explicitly select text and choose ListAll from Services menu
- **Data Received**: Text you select is processed locally and stored in your lists
- **Not Used For**: Tracking which apps you use, background monitoring, or any network transmission

### Handoff (iOS and macOS)
- **Purpose**: Continue viewing your lists seamlessly across Apple devices
- **Usage**: Shares your current viewing context (list ID, item title) between your devices
- **Data Shared**: Only list/item identifiers and titles (not full content)
- **Security**: Encrypted via Apple's Continuity framework; never passes through our servers
- **Control**: Can be disabled in System Settings → General → Handoff

## Data Security

### Local Security
- All data is stored securely using iOS's and macOS's built-in data protection
- Face ID/Touch ID can be enabled for additional app lock security
- Photos and data are sandboxed within the app (App Sandbox on macOS)

### Cloud Security
- If iCloud sync is enabled, Apple's industry-standard encryption protects your data
- Data is encrypted both in transit (TLS) and at rest (AES encryption)

## Data Sharing

**ListAll does NOT share your data with anyone.**

### What About List Sharing?
When you use the app's "Share" feature:
- You explicitly choose to export a list
- Data is shared through iOS's or macOS's standard sharing system
- You control who receives the shared data
- We do not track or have access to shared data

## Children's Privacy

ListAll does not knowingly collect any information from children. The app:
- Does not require age verification
- Does not collect personal information
- Is rated 4+ (suitable for all ages)
- Does not contain inappropriate content

## Data Retention and Deletion

### How Long We Keep Data
We don't keep any data because we don't collect any data. All your information stays on your device or in your personal iCloud.

### How to Delete Your Data

**To delete all app data on iOS:**
1. Open iPhone Settings
2. Go to General → iPhone Storage
3. Find ListAll
4. Tap "Delete App"

**To delete all app data on macOS:**
1. Drag ListAll from Applications to Trash
2. For complete removal, delete `~/Library/Group Containers/group.io.github.chmc.ListAll/`

For iCloud data (all platforms):
1. Go to Settings → [Your Name] → iCloud → Manage Storage
2. Find ListAll
3. Delete Documents and Data

## Third-Party Services

ListAll does NOT use any third-party services, including:
- No analytics services (Google Analytics, Firebase, etc.)
- No advertising networks
- No crash reporting services (except Apple's opt-in system)
- No social media integrations
- No backend servers or APIs

## Changes to Privacy Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by:
- Updating the "Last Updated" date at the top of this policy
- Showing an in-app notification for significant changes

## Your Rights

Since we don't collect your data, you already have full control:
- **Access**: All your data is on your device, accessible anytime
- **Correction**: Edit any data directly in the app
- **Deletion**: Delete items, lists, or the entire app
- **Portability**: Export your data anytime in multiple formats (JSON, CSV, text)
- **iCloud Control**: Sync is automatic when signed into iCloud; disable by signing out of iCloud in System Settings

## International Users

ListAll is available worldwide and complies with:
- GDPR (European Union)
- CCPA (California)
- Other international privacy regulations

Since we don't collect data, there's minimal compliance burden. Your data stays on your device or in your iCloud (processed by Apple according to their policies).

## Contact Us

If you have questions about this Privacy Policy or ListAll's privacy practices:

- **GitHub**: https://github.com/chmc/ListAllApp
- **Issues**: https://github.com/chmc/ListAllApp/issues

## Open Source Transparency

ListAll's code is available for inspection at:
https://github.com/chmc/ListAllApp

You can verify our privacy claims by reviewing the source code.

## Summary

**In Plain English:**

✅ Your data stays on your device  
✅ We can't see your lists or items  
✅ No tracking or analytics  
✅ No ads or third parties  
✅ iCloud sync is optional and private  
✅ You control everything  

**Bottom Line:** We built ListAll to respect your privacy. Your lists are yours, and yours alone.

---

**Company Information:**
ListAll is developed by Aleksi Sutela.

**Governing Law:**
This Privacy Policy is governed by the laws of Finland.

**Last Updated:** December 10, 2025
