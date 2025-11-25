#!/bin/bash
set -euo pipefail

# Generate release checklist after successful pipeline run
# Usage: release-checklist.sh <run-id> <version>
#        release-checklist.sh --latest <version>
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments or gh command failed

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

RUN_ID="${1:-}"
VERSION="${2:-}"

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_task() {
    echo -e "- [ ] $1"
}

print_done() {
    echo -e "- [x] $1"
}

# Check dependencies
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) not installed"
    echo "Install: brew install gh" >&2
    exit 1
fi

# Handle --latest flag
if [ "$RUN_ID" == "--latest" ]; then
    print_info "Fetching latest workflow run..."
    RUN_ID=$(gh run list --workflow=prepare-appstore.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    if [ -z "$RUN_ID" ]; then
        print_error "No workflow runs found"
        exit 1
    fi
    print_info "Using run #$RUN_ID"
fi

if [ -z "$RUN_ID" ] || [ -z "$VERSION" ]; then
    print_error "Run ID and version required"
    echo "Usage: $0 <run-id> <version>" >&2
    echo "       $0 --latest <version>" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  $0 19667213668 1.2.0" >&2
    echo "  $0 --latest 1.2.0" >&2
    exit 1
fi

# Validate version format (semantic versioning)
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    print_warning "Version doesn't follow semantic versioning (x.y.z): $VERSION"
    print_info "Continuing anyway..."
fi

print_header "📋 App Store Release Checklist for v${VERSION}"

# Fetch run details
print_info "Fetching run details..."

RUN_JSON=$(gh run view "$RUN_ID" --json databaseId,number,status,conclusion,createdAt,url 2>/dev/null || echo "")

if [ -z "$RUN_JSON" ]; then
    print_error "Failed to fetch run details"
    exit 1
fi

STATUS=$(echo "$RUN_JSON" | jq -r '.status // "unknown"')
CONCLUSION=$(echo "$RUN_JSON" | jq -r '.conclusion // "unknown"')
RUN_URL=$(echo "$RUN_JSON" | jq -r '.url // ""')

# Create checklist file
CHECKLIST_FILE="release-checklist-v${VERSION}.md"

cat > "$CHECKLIST_FILE" <<EOF
# 🚀 App Store Release Checklist - v${VERSION}

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')
**Pipeline Run:** [#$RUN_ID]($RUN_URL)
**Status:** $STATUS ($CONCLUSION)

---

## ✅ Pre-Release Verification

### 1. Pipeline Status
EOF

if [ "$CONCLUSION" == "success" ]; then
    echo "- [x] ✅ Pipeline completed successfully" >> "$CHECKLIST_FILE"
    print_success "Pipeline completed successfully"
else
    echo "- [ ] ❌ Pipeline status: $CONCLUSION" >> "$CHECKLIST_FILE"
    print_error "Pipeline did not succeed: $CONCLUSION"
    print_warning "Fix pipeline issues before proceeding"
fi

cat >> "$CHECKLIST_FILE" <<EOF

### 2. Screenshot Validation
- [ ] Review iPhone screenshots (EN + FI)
  - [ ] Welcome screen
  - [ ] Main functionality
  - [ ] Settings/preferences
  - [ ] All text readable and correct locale
- [ ] Review iPad screenshots (EN + FI)
  - [ ] Layout looks good on large screen
  - [ ] All elements properly positioned
  - [ ] Text and images clear
- [ ] Review Watch screenshots (EN + FI)
  - [ ] Complications visible and correct
  - [ ] UI elements sized appropriately
  - [ ] All screens captured correctly

**How to review:**
\`\`\`bash
# Download screenshots from run
gh run download $RUN_ID

# Or view artifacts in browser
gh run view $RUN_ID --web
\`\`\`

### 3. Quality Checks
- [ ] Run screenshot comparison with previous release
  \`\`\`bash
  .github/scripts/compare-screenshots.sh <previous-run> $RUN_ID
  \`\`\`
- [ ] Review any visual differences (expected vs regression)
- [ ] Check performance metrics
  \`\`\`bash
  .github/scripts/track-performance.sh $RUN_ID
  \`\`\`
- [ ] Verify no performance degradation (>20%)

---

## 📱 App Store Connect

### 4. Create New Version
- [ ] Go to [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Navigate to ListAll app
- [ ] Click "+" to create new version: **$VERSION**
- [ ] Select platform: iOS

### 5. Select Build
- [ ] Go to "Build" section
- [ ] Select the TestFlight build for v$VERSION
- [ ] Verify build number matches expected
- [ ] Check build upload date is recent

### 6. Review Screenshots
Screenshots should have been uploaded by the pipeline.

**Verify:**
- [ ] iPhone 16 Pro Max (1290x2796)
  - [ ] English: 4 screenshots
  - [ ] Finnish: 4 screenshots
- [ ] iPad Pro 13" (2064x2752)
  - [ ] English: 4 screenshots
  - [ ] Finnish: 4 screenshots
- [ ] Apple Watch Series 10 (396x484)
  - [ ] English: 10 screenshots
  - [ ] Finnish: 10 screenshots

**If screenshots missing or incorrect:**
\`\`\`bash
# Re-run pipeline
gh workflow run prepare-appstore.yml -f version=$VERSION

# Or upload manually using fastlane
bundle exec fastlane release version:$VERSION
\`\`\`

### 7. Update Metadata
- [ ] What's New section
  - [ ] English: Describe changes/improvements
  - [ ] Finnish: Finnish translation of changes
  - [ ] Keep concise and user-friendly
- [ ] App Description (if changed)
  - [ ] English: Review and update if needed
  - [ ] Finnish: Review Finnish version
- [ ] Keywords (if optimizing)
  - [ ] Review keyword list
  - [ ] Ensure compliance with guidelines
- [ ] Support URL: Verify still valid
- [ ] Marketing URL: Verify still valid
- [ ] Privacy Policy URL: Verify still valid

### 8. App Review Information
- [ ] Contact Information
  - [ ] First Name, Last Name
  - [ ] Phone Number
  - [ ] Email Address
- [ ] Sign-In Required
  - [ ] If yes, provide demo account credentials
  - [ ] Ensure demo account works
- [ ] Notes for Reviewer
  - [ ] Any special instructions
  - [ ] Features that need explanation
  - [ ] Known issues (if any)

### 9. Version Release Options
Choose release strategy:
- [ ] **Automatic:** Release immediately after approval
- [ ] **Manual:** Release manually after approval
- [ ] **Scheduled:** Release on specific date

**Recommendation:** Manual release for control

### 10. Rating & Review
- [ ] Age Rating: Verify correct rating
- [ ] Content Rights: Confirm you have rights
- [ ] Export Compliance: Verify encryption status

---

## 🧪 Final Verification

### 11. Pre-Submit Checklist
- [ ] All required fields filled in App Store Connect
- [ ] No validation errors in App Store Connect
- [ ] Build is signed and uploaded to TestFlight
- [ ] Internal testing completed successfully
- [ ] External beta testing completed (if applicable)
- [ ] All TestFlight feedback reviewed and addressed

### 12. Technical Checks
- [ ] App tested on physical devices
  - [ ] iPhone (latest iOS)
  - [ ] iPad (latest iPadOS)
  - [ ] Apple Watch (latest watchOS)
- [ ] App tested on iOS simulators
- [ ] No crashes in production
- [ ] Analytics show no critical errors
- [ ] All API integrations working
- [ ] Network connectivity tested
- [ ] Offline mode tested (if applicable)

### 13. Legal & Compliance
- [ ] Privacy Policy reviewed and up-to-date
- [ ] Terms of Service reviewed (if applicable)
- [ ] GDPR compliance verified (EU users)
- [ ] App Store Guidelines compliance checked
  - [ ] No prohibited content
  - [ ] No guideline violations
  - [ ] Accurate app description
- [ ] Export compliance declaration completed

---

## 🚀 Submission

### 14. Submit for Review
- [ ] Review all checklist items above
- [ ] Click "Add for Review" in App Store Connect
- [ ] Click "Submit for Review"
- [ ] Confirm submission

**Expected review time:** 1-3 days (typically)

### 15. Post-Submission
- [ ] Monitor App Review status in App Store Connect
- [ ] Check email for any App Review questions
- [ ] Prepare for potential rejection
  - [ ] Have fix ready for common issues
  - [ ] Test resolution process

---

## 📊 Post-Release

### 16. After Approval
- [ ] Release app (if manual release selected)
- [ ] Verify app appears in App Store
- [ ] Test downloading from App Store
- [ ] Check all regions/countries
- [ ] Update app on personal devices

### 17. Monitoring
- [ ] Monitor crash reports (first 24 hours critical)
- [ ] Check App Store reviews
  - [ ] Respond to reviews (especially negative ones)
  - [ ] Thank users for feedback
- [ ] Monitor analytics
  - [ ] Download numbers
  - [ ] User engagement
  - [ ] Feature usage
- [ ] Social media announcement
  - [ ] Twitter/X
  - [ ] Blog post
  - [ ] Newsletter

### 18. Documentation
- [ ] Update CHANGELOG.md with v$VERSION
- [ ] Tag release in Git
  \`\`\`bash
  git tag -a v$VERSION -m "Release version $VERSION"
  git push origin v$VERSION
  \`\`\`
- [ ] Create GitHub release with notes
- [ ] Archive this checklist for records

---

## 🆘 Common Issues

### If App Review Rejects:
1. Read rejection reason carefully
2. Review App Store Guidelines for that section
3. Fix the issue
4. Increment build number
5. Re-submit with resolution notes

### If Screenshots Don't Upload:
\`\`\`bash
# Re-run pipeline
gh workflow run prepare-appstore.yml -f version=$VERSION

# Or upload manually
bundle exec fastlane release version:$VERSION
\`\`\`

### If Performance Issues Detected:
\`\`\`bash
# Check recent runs
.github/scripts/track-performance.sh --history 10

# Analyze specific run
.github/scripts/analyze-ci-failure.sh $RUN_ID
\`\`\`

---

## 📞 Support

- **CI Issues:** See [.github/workflows/TROUBLESHOOTING.md](../.github/workflows/TROUBLESHOOTING.md)
- **Local Testing:** See [.github/DEVELOPMENT.md](../.github/DEVELOPMENT.md)
- **App Store Guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **App Store Connect Help:** https://developer.apple.com/support/app-store-connect/

---

**Pipeline Run:** [View run #$RUN_ID]($RUN_URL)
**Generated by:** \`.github/scripts/release-checklist.sh\`

Good luck with the release! 🚀
EOF

print_header "📄 Checklist Generated"

print_success "Release checklist saved to: $CHECKLIST_FILE"
echo ""

# Print summary
cat "$CHECKLIST_FILE" | head -50
echo ""
echo "... (see $CHECKLIST_FILE for complete checklist)"
echo ""

print_header "🎯 Next Steps"

if [ "$CONCLUSION" == "success" ]; then
    print_success "Pipeline succeeded - ready to proceed!"
    echo ""
    echo "1. Review the checklist: cat $CHECKLIST_FILE"
    echo "2. Download screenshots: gh run download $RUN_ID"
    echo "3. Go to App Store Connect: https://appstoreconnect.apple.com"
    echo "4. Follow the checklist step by step"
    echo ""
else
    print_error "Pipeline status: $CONCLUSION"
    echo ""
    echo "1. Fix pipeline issues first"
    echo "2. Analyze failure: .github/scripts/analyze-ci-failure.sh $RUN_ID"
    echo "3. Re-run pipeline when fixed"
    echo ""
fi

print_info "Track performance: .github/scripts/track-performance.sh $RUN_ID"
print_info "View run: gh run view $RUN_ID --web"

exit 0
