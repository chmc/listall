# Local Screenshot Generation & App Store Deployment Plan

> **Status**: PLANNING PHASE
> **Created**: 2025-11-28
> **Last Updated**: 2025-11-28
> **Swarm Analysis**: 6 specialized agents (Apple Dev, Pipeline, Testing, Shell, Integration, Critical Reviewer)

---

## Executive Summary

This document outlines a comprehensive plan to enable **local screenshot generation** with **verified App Store dimensions**, followed by a **new deployment pipeline** that uploads locally-generated screenshots to App Store Connect.

### Goals
1. Generate correct-size App Store screenshots locally using simulators
2. Validate screenshot dimensions match exact App Store requirements
3. Add screenshots to project codebase (committed to git)
4. Create new pipeline for App Store deployment using local screenshots

### Key Metrics
- **Supported Platforms**: iPhone 6.7", iPad 13", Apple Watch 45mm
- **Supported Locales**: en-US, fi
- **Screenshot Count**: (2 iPhone + 2 iPad + 5 Watch) × 2 locales = 18 total
- **Estimated Local Runtime**: 60-90 minutes (all platforms)

---

## Phase 1: Environment Setup

### 1.1 Prerequisites Checklist

Before local screenshot generation can work, validate:

| Requirement | Validation Command | Expected Output |
|-------------|-------------------|-----------------|
| Xcode 16.1+ | `xcodebuild -version` | `Xcode 16.1` or higher |
| iOS 18.1 Simulators | `xcrun simctl list devices \| grep "iPhone 16 Pro Max"` | Device listed as available |
| iPad Simulator | `xcrun simctl list devices \| grep "iPad Pro 13-inch (M4)"` | Device listed |
| Watch Simulator | `xcrun simctl list devices \| grep "Apple Watch Series 10 (46mm)"` | Device listed |
| ImageMagick | `convert -version` | `ImageMagick 7.x` |
| Ruby 3.2+ | `ruby --version` | `ruby 3.2.x` or higher |
| Bundler | `bundle check` | Dependencies satisfied |
| Disk Space | `df -h .` | 5GB+ free |

### 1.2 App Store Connect API Credentials

**Action Required**: Set up local ASC API credentials

#### Step 1: Generate API Key (if not already done)
1. Log into [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to **Users and Access** → **Keys** → **App Store Connect API**
3. Click **Generate API Key** with "App Manager" or higher role
4. Download the `.p8` file (AuthKey_XXXXXXXXXX.p8)
5. Note the **Key ID** and **Issuer ID** shown on the page

#### Step 2: Create Local Environment File
```bash
# Create .env file in fastlane directory
cat > fastlane/.env << 'EOF'
# App Store Connect API Credentials
# DO NOT COMMIT THIS FILE TO GIT
ASC_KEY_ID=YOUR_KEY_ID_HERE
ASC_ISSUER_ID=YOUR_ISSUER_ID_HERE
ASC_KEY_BASE64=YOUR_BASE64_KEY_HERE
EOF

# Convert .p8 file to base64
base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
# Copy output to ASC_KEY_BASE64 in .env
```

#### Step 3: Verify .gitignore
```bash
# Ensure .env is ignored
grep -q "fastlane/.env" .gitignore || echo "fastlane/.env" >> .gitignore
```

#### Step 4: Validate Credentials
```bash
bundle exec fastlane ios asc_dry_run
```

### 1.3 Simulator Preparation

#### iPhone/iPad Simulators
```bash
# Shutdown all running simulators
xcrun simctl shutdown all

# Delete unavailable simulators
xcrun simctl delete unavailable

# List available devices
xcrun simctl list devices available
```

#### Watch Simulator Pairing (Critical)

The Watch simulator must be paired with an iPhone simulator:

```bash
# Find Watch simulator UDID
WATCH_UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'watchOS' in runtime and '11' in runtime:
        for d in devices:
            if 'Apple Watch Series 10 (46mm)' in d['name'] and d['isAvailable']:
                print(d['udid'])
                sys.exit(0)
")

# Find iPhone simulator UDID
IPHONE_UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' in runtime and '18' in runtime:
        for d in devices:
            if 'iPhone 16 Pro Max' in d['name'] and d['isAvailable']:
                print(d['udid'])
                sys.exit(0)
")

# Check if already paired
xcrun simctl listpairs | grep -A5 "$WATCH_UDID"

# Create pairing if needed
xcrun simctl pair "$WATCH_UDID" "$IPHONE_UDID"
```

---

## Phase 2: Local Screenshot Generation

### 2.1 Screenshot Specifications

| Platform | Device | Raw Capture | Normalized | App Store Slot |
|----------|--------|-------------|------------|----------------|
| iPhone | iPhone 16 Pro Max | 1290x2796 | 1290x2796 | 6.7" display |
| iPad | iPad Pro 13" (M4) | 2064x2752 | 2064x2752 | 13" display |
| Watch | Apple Watch Series 10 (46mm) | 416x496 | 396x484 | 45mm display |

### 2.2 Screenshot Content

| # | Screenshot Name | Content Description |
|---|----------------|---------------------|
| 01 | Welcome | Empty state with template suggestions |
| 02 | MainScreen | Populated view with 4 test lists |

**watchOS Additional Screenshots:**
| # | Screenshot Name | Content Description |
|---|----------------|---------------------|
| 01 | Watch_Lists_Home | Main lists view |
| 02 | Watch_List_Detail | Single list with items |
| 03 | Watch_Item_Detail | Item detail view |
| 04 | Watch_Add_Item | Add item interface |
| 05 | Watch_Settings | Settings screen |

### 2.3 Generation Commands

#### Option A: Generate All Platforms (Full Pipeline)
```bash
# Full pipeline - generates iPhone, iPad, Watch screenshots
# Includes normalization and validation
# Estimated time: 60-90 minutes
bundle exec fastlane ios prepare_appstore
```

#### Option B: Generate by Platform (Recommended for Iteration)

**iPhone Only** (~20 minutes):
```bash
bundle exec fastlane ios screenshots_iphone
```

**iPad Only** (~35 minutes):
```bash
bundle exec fastlane ios screenshots_ipad
```

**Watch Only** (~20 minutes):
```bash
bundle exec fastlane ios watch_screenshots
```

#### Option C: Single Locale for Quick Testing
```bash
# iPhone only, English only (~10 minutes)
bundle exec fastlane ios screenshots_iphone_locale locale:en-US
```

### 2.4 Output Directory Structure

After generation, screenshots are organized as:

```
fastlane/
├── screenshots/                      # Raw captures
│   ├── en-US/
│   │   ├── iPhone 16 Pro Max-01_Welcome.png
│   │   ├── iPhone 16 Pro Max-02_MainScreen.png
│   │   ├── iPad Pro 13-inch (M4)-01_Welcome.png
│   │   └── iPad Pro 13-inch (M4)-02_MainScreen.png
│   ├── fi/
│   │   └── (same structure)
│   └── watch/
│       ├── en-US/
│       │   └── (5 screenshots)
│       └── fi/
│
├── screenshots_compat/               # Normalized (App Store ready)
│   ├── en-US/
│   │   ├── iPhone 16 Pro Max-01_Welcome.png (1290x2796)
│   │   ├── iPhone 16 Pro Max-02_MainScreen.png
│   │   ├── iPad Pro 13-inch (M4)-01_Welcome.png (2064x2752)
│   │   └── iPad Pro 13-inch (M4)-02_MainScreen.png
│   └── fi/
│
└── screenshots/watch_normalized/     # Normalized Watch
    ├── en-US/ (396x484)
    └── fi/
```

---

## Phase 3: Screenshot Validation

### 3.1 Dimension Validation

**Run validation after generation:**
```bash
bundle exec fastlane ios validate_delivery_screenshots
```

This checks:
- iPhone screenshots are exactly 1290x2796
- iPad screenshots are exactly 2064x2752
- Watch screenshots are exactly 396x484
- Correct count per locale (2 iPhone + 2 iPad + 5 Watch)

### 3.2 Manual Validation Checklist

Before proceeding to upload, manually verify:

- [ ] **iPhone 6.7" screenshots** (4 total: 2 per locale)
  - [ ] en-US: 01_Welcome, 02_MainScreen
  - [ ] fi: 01_Welcome, 02_MainScreen
  - [ ] Dimensions: 1290x2796 pixels

- [ ] **iPad 13" screenshots** (4 total: 2 per locale)
  - [ ] en-US: 01_Welcome, 02_MainScreen
  - [ ] fi: 01_Welcome, 02_MainScreen
  - [ ] Dimensions: 2064x2752 pixels

- [ ] **Watch 45mm screenshots** (10 total: 5 per locale)
  - [ ] en-US: 5 screenshots
  - [ ] fi: 5 screenshots
  - [ ] Dimensions: 396x484 pixels

- [ ] **Content verification**
  - [ ] Finnish screenshots show Finnish text
  - [ ] English screenshots show English text
  - [ ] No placeholder/debug text visible
  - [ ] Status bar shows 9:41, full battery

### 3.3 Dimension Verification Commands

```bash
# Check all screenshot dimensions
find fastlane/screenshots_compat -name "*.png" -exec identify -format "%f: %wx%h\n" {} \;

# Check Watch screenshots
find fastlane/screenshots/watch_normalized -name "*.png" -exec identify -format "%f: %wx%h\n" {} \;
```

---

## Phase 4: Add Screenshots to Codebase

### 4.1 Git Strategy

Screenshots should be committed to the repository for:
- Version control of App Store assets
- Easy rollback if issues arise
- Team visibility and review

**Recommended approach:**
```bash
# Stage validated screenshots
git add fastlane/screenshots_compat/
git add fastlane/screenshots/watch_normalized/

# Create descriptive commit
git commit -m "Update App Store screenshots for version X.Y.Z

- iPhone 6.7\" (1290x2796): 2 screenshots × 2 locales
- iPad 13\" (2064x2752): 2 screenshots × 2 locales
- Watch 45mm (396x484): 5 screenshots × 2 locales
- Generated locally with Xcode 16.1 simulators
- All dimensions validated for App Store Connect"
```

### 4.2 Files to Commit

| Directory | Content | Git Status |
|-----------|---------|------------|
| `fastlane/screenshots_compat/` | Normalized iPhone/iPad | COMMIT |
| `fastlane/screenshots/watch_normalized/` | Normalized Watch | COMMIT |
| `fastlane/screenshots/` (raw) | Raw captures | .gitignore |
| `fastlane/screenshots/delivery/` | Ephemeral delivery | .gitignore |
| `fastlane/screenshots/framed/` | Framed versions | Optional |

### 4.3 .gitignore Updates

```gitignore
# Screenshot generation (raw/intermediate)
fastlane/screenshots/en-US/
fastlane/screenshots/fi/
fastlane/screenshots/watch/
fastlane/screenshots/delivery/

# Keep normalized screenshots (committed)
!fastlane/screenshots_compat/
!fastlane/screenshots/watch_normalized/
```

---

## Phase 5: App Store Deployment Pipeline

### 5.1 New Workflow: Publish to App Store

This workflow does **exactly what `prepare-appstore.yml` does, except it skips screenshot generation** and uses pre-committed screenshots from the repository instead.

**Comparison:**

| Step | `prepare-appstore.yml` | `publish-to-appstore.yml` |
|------|------------------------|---------------------------|
| Generate iPhone screenshots | ✅ CI generates | ⏭️ Skip (use committed) |
| Generate iPad screenshots | ✅ CI generates | ⏭️ Skip (use committed) |
| Generate Watch screenshots | ✅ CI generates | ⏭️ Skip (use committed) |
| Validate dimensions | ✅ | ✅ |
| Upload to App Store Connect | ✅ | ✅ |
| Create/update version | ✅ | ✅ |
| Upload metadata | ✅ | ✅ |

**File: `.github/workflows/publish-to-appstore.yml`**

```yaml
name: Publish to App Store

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'App version for this release (e.g., 1.2.0)'
        required: true
        type: string
      skip_validation:
        description: 'Skip screenshot validation'
        required: false
        default: false
        type: boolean

permissions:
  contents: read

jobs:
  publish:
    name: Upload Metadata & Screenshots
    runs-on: macos-14
    timeout-minutes: 30
    env:
      ASC_KEY_ID: ${{ secrets.ASC_KEY_ID }}
      ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
      ASC_KEY_BASE64: ${{ secrets.ASC_KEY_BASE64 }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Install ImageMagick (required for screenshot validation)
        run: brew install imagemagick

      - name: Verify screenshots exist in repository
        run: |
          echo "=== Checking committed screenshots ==="
          echo ""
          echo "iPhone/iPad screenshots (screenshots_compat):"
          find fastlane/screenshots_compat -name "*.png" -type f | wc -l | xargs echo "  Total files:"
          ls -la fastlane/screenshots_compat/en-US/ || { echo "❌ Missing en-US screenshots"; exit 1; }
          ls -la fastlane/screenshots_compat/fi/ || { echo "❌ Missing fi screenshots"; exit 1; }
          echo ""
          echo "Watch screenshots (watch_normalized):"
          find fastlane/screenshots/watch_normalized -name "*.png" -type f | wc -l | xargs echo "  Total files:"
          ls -la fastlane/screenshots/watch_normalized/en-US/ || { echo "❌ Missing en-US Watch screenshots"; exit 1; }
          ls -la fastlane/screenshots/watch_normalized/fi/ || { echo "❌ Missing fi Watch screenshots"; exit 1; }

      - name: Validate screenshot dimensions
        if: ${{ !inputs.skip_validation }}
        run: bundle exec fastlane ios validate_delivery_screenshots

      - name: Upload metadata and screenshots to App Store Connect
        run: bundle exec fastlane release version:${{ inputs.version }}

      - name: Summary
        run: |
          echo "## 🎉 App Store Publication Complete!" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Screenshots Uploaded (from repository)" >> $GITHUB_STEP_SUMMARY
          echo "- ✅ iPhone (EN + FI): 4 screenshots (1290x2796)" >> $GITHUB_STEP_SUMMARY
          echo "- ✅ iPad 13\" (EN + FI): 4 screenshots (2064x2752)" >> $GITHUB_STEP_SUMMARY
          echo "- ✅ Watch (EN + FI): 10 screenshots (396x484)" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Next Steps" >> $GITHUB_STEP_SUMMARY
          echo "1. Go to [App Store Connect](https://appstoreconnect.apple.com)" >> $GITHUB_STEP_SUMMARY
          echo "2. Review version: **${{ inputs.version }}**" >> $GITHUB_STEP_SUMMARY
          echo "3. Select the TestFlight build you want to release" >> $GITHUB_STEP_SUMMARY
          echo "4. Review the uploaded screenshots and metadata" >> $GITHUB_STEP_SUMMARY
          echo "5. Submit for review" >> $GITHUB_STEP_SUMMARY
```

**Key differences from `prepare-appstore.yml`:**
- **No screenshot generation jobs** - uses screenshots already committed to repo
- **Single job** - no parallel jobs needed (no generation)
- **Much faster** - ~5 minutes vs ~90 minutes (skips screenshot generation)
- **Screenshots from git** - not from CI artifacts

**What this workflow does:**
1. **Uses committed screenshots** (from `screenshots_compat/` and `watch_normalized/`)
2. **Validates dimensions** (same validation as prepare-appstore)
3. **Creates/updates App Store version** (specified version number)
4. **Uploads screenshots** (iPhone, iPad, Watch - all locales)
5. **Uploads metadata** (description, keywords, release notes, promotional text, URLs)
6. **Does NOT submit for review** (manual step in App Store Connect)
7. **Does NOT upload binary** (handled separately via Xcode or other workflow)

### 5.2 Local Upload Command

For direct local upload (without CI):

```bash
# Dry run first (validates without uploading)
bundle exec fastlane ios release_dry_run

# Upload to App Store Connect
bundle exec fastlane ios release version:1.2.0
```

### 5.3 Upload Process Flow

```
┌─────────────────────────────────────────────────────────────┐
│                 LOCAL SCREENSHOT DEPLOY                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  1. VALIDATE SCREENSHOTS EXIST                              │
│     - Check screenshots_compat/{locale}/ for iPhone/iPad    │
│     - Check screenshots/watch_normalized/{locale}/ for Watch│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  2. VALIDATE DIMENSIONS                                     │
│     - iPhone: 1290x2796                                     │
│     - iPad: 2064x2752                                       │
│     - Watch: 396x484                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  3. PREPARE DELIVERY                                        │
│     - Merge iPhone/iPad from screenshots_compat/            │
│     - Merge Watch from watch_normalized/                    │
│     - Output to screenshots/delivery/{locale}/              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  4. AUTHENTICATE & UPLOAD                                   │
│     - Authenticate with ASC API key                         │
│     - Create/update app version                             │
│     - Upload screenshots                                    │
│     - Upload metadata                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  5. VERIFY IN APP STORE CONNECT                            │
│     - Check screenshots appear in correct slots             │
│     - Verify metadata updated                               │
│     - Ready for manual review submission                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 6: New Helper Scripts

### 6.1 Local Preflight Check Script

**File: `.github/scripts/local-preflight-check.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Local Screenshot Preflight Check ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

check() {
    local name="$1"
    local cmd="$2"
    local expected="$3"

    if eval "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        ((PASS++))
    else
        echo -e "${RED}✗${NC} $name - Expected: $expected"
        ((FAIL++))
    fi
}

echo ""
echo "Checking Xcode..."
check "Xcode 16.1+" "xcodebuild -version | grep -E 'Xcode (16\.[1-9]|17\.)'" "Xcode 16.1 or higher"

echo ""
echo "Checking Simulators..."
check "iPhone 16 Pro Max" "xcrun simctl list devices available | grep 'iPhone 16 Pro Max'" "iPhone 16 Pro Max simulator"
check "iPad Pro 13-inch (M4)" "xcrun simctl list devices available | grep 'iPad Pro 13-inch (M4)'" "iPad Pro 13-inch simulator"
check "Apple Watch Series 10" "xcrun simctl list devices available | grep 'Apple Watch Series 10'" "Watch Series 10 simulator"

echo ""
echo "Checking Tools..."
check "ImageMagick" "which convert" "ImageMagick installed"
check "Ruby 3.2+" "ruby --version | grep -E 'ruby 3\.[2-9]'" "Ruby 3.2 or higher"
check "Bundle dependencies" "bundle check" "bundle install completed"

echo ""
echo "Checking Credentials..."
if [ -f "fastlane/.env" ]; then
    check "ASC_KEY_ID" "grep -q 'ASC_KEY_ID=' fastlane/.env" "Key ID configured"
    check "ASC_ISSUER_ID" "grep -q 'ASC_ISSUER_ID=' fastlane/.env" "Issuer ID configured"
    check "ASC_KEY_BASE64" "grep -q 'ASC_KEY_BASE64=' fastlane/.env" "API key configured"
else
    echo -e "${RED}✗${NC} fastlane/.env file not found"
    ((FAIL++))
fi

echo ""
echo "Checking Disk Space..."
FREE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/Gi//')
if [ "${FREE_SPACE%.*}" -ge 5 ]; then
    echo -e "${GREEN}✓${NC} Disk space: ${FREE_SPACE}GB free"
    ((PASS++))
else
    echo -e "${RED}✗${NC} Disk space: ${FREE_SPACE}GB free (need 5GB+)"
    ((FAIL++))
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Please fix the failed checks before proceeding.${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}All checks passed! Ready for screenshot generation.${NC}"
    exit 0
fi
```

### 6.2 Local Screenshot Generation Script

**File: `.github/scripts/generate-screenshots-local.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Local Screenshot Generation ==="
echo "Start time: $(date)"

# Parse arguments
PLATFORM="${1:-all}"
LOCALE="${2:-all}"

case "$PLATFORM" in
    iphone)
        echo "Generating iPhone screenshots..."
        bundle exec fastlane ios screenshots_iphone
        ;;
    ipad)
        echo "Generating iPad screenshots..."
        bundle exec fastlane ios screenshots_ipad
        ;;
    watch)
        echo "Generating Watch screenshots..."
        bundle exec fastlane ios watch_screenshots
        ;;
    all)
        echo "Generating all screenshots..."
        bundle exec fastlane ios prepare_appstore
        ;;
    *)
        echo "Usage: $0 [iphone|ipad|watch|all] [en-US|fi|all]"
        exit 1
        ;;
esac

echo ""
echo "=== Validation ==="
bundle exec fastlane ios validate_delivery_screenshots

echo ""
echo "=== Complete ==="
echo "End time: $(date)"
echo ""
echo "Screenshots ready in:"
echo "  - fastlane/screenshots_compat/ (iPhone/iPad)"
echo "  - fastlane/screenshots/watch_normalized/ (Watch)"
```

---

## Phase 7: Implementation Tasks

### 7.1 Task Checklist

#### Environment Setup (Priority: HIGH)
- [ ] Create `.env.template` file with placeholder credentials
- [ ] Update `.gitignore` to exclude `fastlane/.env`
- [ ] Create `local-preflight-check.sh` script
- [ ] Document ImageMagick installation (`brew install imagemagick`)

#### Screenshot Generation (Priority: HIGH)
- [ ] Verify existing Fastlane lanes work locally
- [ ] Create `generate-screenshots-local.sh` wrapper script
- [ ] Test iPhone screenshot generation
- [ ] Test iPad screenshot generation (watch for flakiness)
- [ ] Test Watch screenshot generation
- [ ] Test full pipeline with both locales

#### Validation (Priority: HIGH)
- [ ] Verify `validate_delivery_screenshots` lane works
- [ ] Test dimension validation catches wrong sizes
- [ ] Create manual validation checklist document

#### Git Integration (Priority: MEDIUM)
- [ ] Define which screenshot directories to commit
- [ ] Update `.gitignore` appropriately
- [ ] Create commit message template
- [ ] Test git workflow with sample screenshots

#### Deployment Pipeline (Priority: MEDIUM)
- [ ] Create `publish-to-appstore.yml` workflow
- [ ] Test dry-run upload locally
- [ ] Test actual upload to App Store Connect
- [ ] Document rollback procedure

#### Documentation (Priority: MEDIUM)
- [ ] Create SCREENSHOTS.md guide
- [ ] Update CLAUDE.md with local screenshot commands
- [ ] Add troubleshooting section
- [ ] Document expected runtimes

### 7.2 Estimated Timeline

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| Phase 1: Environment | Setup scripts, credentials | 2 hours |
| Phase 2: Generation | Test all platforms locally | 4 hours |
| Phase 3: Validation | Verify dimensions, content | 1 hour |
| Phase 4: Git Integration | Define workflow, test | 1 hour |
| Phase 5: Pipeline | Create workflow, test deploy | 2 hours |
| Phase 6: Scripts | Create helper scripts | 2 hours |
| Phase 7: Documentation | Write guides | 2 hours |
| **Total** | | **14 hours** |

---

## Phase 8: Risk Mitigation

### 8.1 Known Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| iPad simulator flakiness | 30% | HIGH | Retry logic, pre-boot, reset between attempts |
| Locale switching failure | 20% | HIGH | Verify locale after switch, test content |
| ImageMagick version mismatch | 15% | MEDIUM | Pin version, validate output |
| Watch pairing issues | 25% | HIGH | Document pairing, verify before tests |
| ASC API credential expiry | 10% | MEDIUM | Document refresh process |

### 8.2 Rollback Procedures

**If upload fails:**
1. Check App Store Connect for partial upload
2. If partial: Delete version, recreate
3. If complete but wrong: Re-run `release` lane (overwrites)

**If screenshots wrong:**
1. Fix issue locally
2. Regenerate affected platform
3. Validate dimensions
4. Re-upload with same version

**If need previous version:**
1. Git checkout previous screenshot commit
2. Re-run upload process

---

## Appendix A: Quick Reference Commands

### Environment
```bash
# Preflight check
.github/scripts/local-preflight-check.sh

# Validate ASC credentials
bundle exec fastlane ios asc_dry_run
```

### Screenshot Generation
```bash
# All platforms
bundle exec fastlane ios prepare_appstore

# Individual platforms
bundle exec fastlane ios screenshots_iphone
bundle exec fastlane ios screenshots_ipad
bundle exec fastlane ios watch_screenshots

# Quick test (single locale)
bundle exec fastlane ios screenshots_iphone_locale locale:en-US
```

### Validation
```bash
# Validate dimensions
bundle exec fastlane ios validate_delivery_screenshots

# Check dimensions manually
find fastlane/screenshots_compat -name "*.png" -exec identify -format "%f: %wx%h\n" {} \;
```

### Upload
```bash
# Dry run (no upload)
bundle exec fastlane ios release_dry_run

# Upload to App Store Connect
bundle exec fastlane ios release version:1.2.0
```

---

## Appendix B: Expected Screenshot Dimensions

| Platform | Width | Height | Aspect Ratio |
|----------|-------|--------|--------------|
| iPhone 6.7" | 1290 | 2796 | 0.46:1 |
| iPad 13" | 2064 | 2752 | 0.75:1 |
| Watch 45mm | 396 | 484 | 0.82:1 |

---

## Appendix C: File Structure After Implementation

```
ListAllApp/
├── .github/
│   ├── scripts/
│   │   ├── local-preflight-check.sh    # NEW: Environment validation
│   │   ├── generate-screenshots-local.sh # NEW: Generation wrapper
│   │   └── (existing scripts)
│   └── workflows/
│       ├── publish-to-appstore.yml      # NEW: Publish to App Store
│       └── (existing workflows)
│
├── documentation/
│   ├── todo.localsc.md                  # This plan document
│   └── SCREENSHOTS.md                   # NEW: Screenshot workflow guide
│
├── fastlane/
│   ├── .env                             # NEW: Local credentials (gitignored)
│   ├── .env.template                    # NEW: Credential template
│   ├── screenshots_compat/              # Committed: Normalized screenshots
│   │   ├── en-US/
│   │   └── fi/
│   └── screenshots/
│       └── watch_normalized/            # Committed: Watch screenshots
│           ├── en-US/
│           └── fi/
│
└── .gitignore                           # Updated: Exclude .env, raw screenshots
```

---

## Appendix D: Swarm Agent Contributions

This plan was created using a 6-agent swarm analysis:

| Agent | Role | Key Contributions |
|-------|------|-------------------|
| **Apple Dev Expert** | Technical Lead | Screenshot dimensions, Fastlane configuration, simulator setup |
| **Pipeline Specialist** | CI/CD Design | Workflow architecture, artifact handling, performance benchmarks |
| **Testing Specialist** | Test Architecture | UI test structure, flakiness mitigation, locale handling |
| **Shell Script Specialist** | Automation | Helper scripts, simulator commands, validation |
| **Integration Specialist** | ASC Integration | API authentication, upload process, metadata handling |
| **Critical Reviewer** | Quality Assurance | Risk analysis, gap identification, recommendations |

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-28 | 1.0 | Initial plan created from 6-agent swarm analysis |

---

*End of Planning Document*
