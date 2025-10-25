# ListAll - App Store Metadata

This folder contains all the information needed to submit ListAll to the App Store Connect.

## Quick Start

1. Read `SUBMISSION_GUIDE.md` for step-by-step instructions
2. Prepare screenshots (see `en-US/screenshots/README.md`)
3. Follow the submission guide to upload to App Store Connect

## What's In This Folder

### Core Files

| File | Purpose | Required |
|------|---------|----------|
| `SUBMISSION_GUIDE.md` | Complete submission walkthrough | - |
| `app_info.txt` | App metadata (name, category, etc.) | ✓ |
| `app_privacy_questionnaire.txt` | Privacy answers for App Store | ✓ |

### en-US Folder (English Localization)

| File | Purpose | Char Limit | Required |
|------|---------|------------|----------|
| `description.txt` | App Store description | 4000 | ✓ |
| `promotional_text.txt` | Short promotional text | 170 | - |
| `keywords.txt` | Search keywords | 100 | ✓ |
| `support_url.txt` | Customer support URL | - | ✓ |
| `marketing_url.txt` | Marketing website URL | - | - |
| `privacy_policy_url.txt` | Privacy policy URL | - | ✓ |
| `release_notes.txt` | What's new in this version | 4000 | ✓ |
| `screenshots/` | Screenshots for all devices | - | ✓ |

### Additional Files

- `../PRIVACY.md` - Full privacy policy (must be publicly accessible)
- `routing_app_coverage.geojson` - Only needed if this were a routing/navigation app (not applicable)

## How to Use

### For Initial Submission (Version 1.0)

1. **Review all content**
   ```bash
   # Check description
   cat en-US/description.txt
   
   # Check keywords length
   wc -c en-US/keywords.txt  # Must be ≤ 100 chars
   
   # Verify URLs work
   cat en-US/support_url.txt
   cat en-US/privacy_policy_url.txt
   ```

2. **Prepare screenshots**
   - Follow instructions in `en-US/screenshots/README.md`
   - Use Xcode simulators for all required device sizes
   - Save in `en-US/screenshots/` with proper naming

3. **Upload to App Store Connect**
   - Follow `SUBMISSION_GUIDE.md` step by step
   - Copy/paste content from these text files
   - Upload screenshots from `screenshots/` folder

### For Updates (Version 1.1+)

1. **Update relevant files**
   ```bash
   # Update what's new
   nano en-US/release_notes.txt
   
   # Update description if features changed
   nano en-US/description.txt
   
   # Update keywords if needed
   nano en-US/keywords.txt
   
   # Add new screenshots if UI changed
   # Save to en-US/screenshots/
   ```

2. **Submit new version**
   - Create new version in App Store Connect
   - Upload new build
   - Copy updated metadata from files
   - Submit for review

## Adding Localizations

To support additional languages:

1. Create new folder: `metadata/[language-code]/`
   - Example: `fr-FR/` for French
   - Example: `de-DE/` for German
   - Example: `ja/` for Japanese

2. Copy structure from `en-US/`:
   ```bash
   cp -r en-US/ fr-FR/
   ```

3. Translate all .txt files in new language folder

4. Take localized screenshots (with translated UI)

5. In App Store Connect:
   - Add new localization
   - Upload translated metadata
   - Upload localized screenshots

### Supported Localizations

Check App Store Connect for full list. Common ones:
- `en-US` - English (U.S.)
- `en-GB` - English (U.K.)
- `fr-FR` - French (France)
- `de-DE` - German (Germany)
- `es-ES` - Spanish (Spain)
- `ja` - Japanese
- `zh-Hans` - Chinese (Simplified)
- `pt-BR` - Portuguese (Brazil)

## Content Guidelines

### Description Best Practices
- ✓ Start with compelling hook
- ✓ Use bullet points for features
- ✓ Include keywords naturally
- ✓ Highlight unique features
- ✓ End with call-to-action
- ✗ Don't mention competitors
- ✗ Don't mention pricing (if free)
- ✗ Don't include future features

### Keywords Best Practices
- ✓ Use relevant, specific terms
- ✓ Include synonyms
- ✓ Think like users searching
- ✓ Research competitor keywords
- ✗ Don't repeat app name
- ✗ Don't use category name
- ✗ Don't use spaces after commas
- ✗ Don't exceed 100 characters

### Screenshot Best Practices
- ✓ Show actual app features
- ✓ Use high-quality images
- ✓ First 2-3 are most important
- ✓ Add text overlays if helpful
- ✓ Show variety of features
- ✗ Don't show outdated UI
- ✗ Don't use placeholder content
- ✗ Don't include device frames (optional)

## Version Control

This metadata folder is tracked in Git, so:

- ✓ Commit changes when updating metadata
- ✓ Tag releases (e.g., `v1.0-submitted`)
- ✓ Keep history of all changes
- ✓ Document major description changes

Example workflow:
```bash
# After preparing for submission
git add metadata/
git commit -m "chore: prepare v1.0 App Store metadata"
git tag v1.0-submitted
git push origin main --tags

# After approval
git tag v1.0-approved
git push origin main --tags
```

## Automation (Future)

These files are structured for potential automation with tools like:
- **fastlane**: iOS deployment automation
- **deliver**: App Store metadata management
- **snapshot**: Automated screenshot generation

Example fastlane Deliverfile:
```ruby
# Can reference these files
app_identifier "io.github.chmc.ListAll"
metadata_path "./metadata"
screenshots_path "./metadata/en-US/screenshots"
```

## Character Limits Reference

| Field | Limit | File |
|-------|-------|------|
| App Name | 30 chars | app_info.txt |
| Subtitle | 30 chars | app_info.txt |
| Promotional Text | 170 chars | promotional_text.txt |
| Description | 4000 chars | description.txt |
| Keywords | 100 chars | keywords.txt |
| What's New | 4000 chars | release_notes.txt |
| Support URL | - | support_url.txt |

Check character count:
```bash
wc -c en-US/description.txt      # Should be ≤ 4000
wc -c en-US/keywords.txt         # Should be ≤ 100
wc -c en-US/promotional_text.txt # Should be ≤ 170
```

## Validation Checklist

Before submission, verify:

- [ ] All required files exist
- [ ] No file exceeds character limits
- [ ] All URLs are accessible (test in browser)
- [ ] Privacy policy URL works and shows policy
- [ ] Screenshots exist for all required devices
- [ ] Keywords don't contain spaces after commas
- [ ] Description has no typos (spellcheck)
- [ ] Contact information is correct
- [ ] App name matches Xcode project
- [ ] Bundle ID matches Xcode project

Run validation:
```bash
# Check all required files exist
ls -la metadata/en-US/*.txt
ls -la metadata/app_info.txt
ls -la metadata/app_privacy_questionnaire.txt

# Verify character counts
echo "Description:" && wc -c metadata/en-US/description.txt
echo "Keywords:" && wc -c metadata/en-US/keywords.txt
echo "Promo:" && wc -c metadata/en-US/promotional_text.txt

# Check URLs are valid
cat metadata/en-US/support_url.txt
cat metadata/en-US/privacy_policy_url.txt
```

## Getting Help

- **Submission Issues**: See `SUBMISSION_GUIDE.md`
- **Screenshot Help**: See `en-US/screenshots/README.md`
- **Privacy Questions**: See `app_privacy_questionnaire.txt`
- **General Info**: See `../docs/appstore_submission_checklist.md`

## Resources

- [App Store Connect](https://appstoreconnect.apple.com)
- [Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [Metadata Field Reference](https://developer.apple.com/help/app-store-connect/reference/app-store-connect-fields)

---

**Last Updated**: October 25, 2025  
**App Version**: 1.0  
**Status**: Ready for submission


