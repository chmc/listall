# Screenshot Framing Solution - Integration Plan

**Date:** 2025-11-28
**Branch:** `feature/framed-screenshots`
**Integration Specialist:** Claude Code
**Project:** ListAll iOS/watchOS App

---

## Executive Summary

This document outlines the integration strategy for the screenshot framing solution in the ListAll project. The solution adds device frames and marketing text to App Store screenshots using Fastlane's `frameit` gem, creating visually appealing promotional materials while maintaining the normalized raw screenshots required for App Store Connect submission.

**Key Integration Points:**
1. Fastlane lane structure (existing `screenshots_framed` lane)
2. CI/CD pipeline (GitHub Actions workflows)
3. Local development workflow (shell scripts)
4. Screenshot storage and gitignore rules

**Current Status:** ✅ Core implementation exists but is **deliberately disabled** to skip framing overhead during routine screenshot generation (commit a26d0eb).

---

## 1. Current Architecture Analysis

### 1.1 Data Flow Map

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SCREENSHOT GENERATION PIPELINE                    │
└─────────────────────────────────────────────────────────────────────┘

STEP 1: Raw Screenshot Capture (UI Tests)
├─ iOS Simulators (iPhone 16 Pro Max, iPad Pro 13" M4)
├─ watchOS Simulators (Apple Watch Series 10 46mm)
├─ Output: fastlane/screenshots/{locale}/*.png
└─ Dimensions: Native simulator resolutions (varies by device)

                              ↓

STEP 2: Normalization (ImageMagick)
├─ Target: App Store Connect official dimensions
│  - iPhone 6.7": 1290x2796
│  - iPad 13": 2064x2752
│  - Watch Series 7+: 396x484
├─ Output iOS/iPad: fastlane/screenshots_compat/{locale}/*.png
├─ Output Watch: fastlane/screenshots/watch_normalized/{locale}/*.png
└─ Module: fastlane/lib/screenshot_helper.rb

                              ↓

STEP 3: Framing (Frameit) - OPTIONAL, CURRENTLY SKIPPED
├─ Input: Normalized screenshots from screenshots_compat/
├─ Process: Add device bezels + marketing text
├─ Config: fastlane/Framefile.json
├─ Output: fastlane/screenshots/framed/{locale}/*_framed.png
├─ Dimensions: Non-standard (e.g., 1421x2909 for iPhone with frame)
└─ Lane: screenshots_framed (exists but not used by default)

                              ↓

STEP 4: App Store Delivery
├─ Input: RAW NORMALIZED screenshots (NOT framed)
├─ Source: screenshots_compat/ + watch_normalized/
├─ Destination: fastlane/screenshots/delivery/{locale}/*.png
├─ Upload: Fastlane Deliver to App Store Connect
└─ Function: prepare_screenshots_for_delivery() in Fastfile
```

### 1.2 Integration Point Details

#### A. Fastlane Lanes (fastlane/Fastfile)

**Primary Lanes:**
- `screenshots_iphone` (line 587): Generate iPhone screenshots → normalize
- `screenshots_ipad` (line 628): Generate iPad screenshots → normalize
- `watch_screenshots` (line 3402): Generate Watch screenshots → normalize
- `prepare_appstore` (line 669): Orchestrates all platforms (NO FRAMING)

**Framing Lane (UNUSED):**
- `screenshots_framed` (line 701): Full pipeline INCLUDING framing
  - Status: Implemented but deliberately not invoked
  - Last used: Before commit a26d0eb (2024-11-28)
  - Reason for disabling: "Skip device framing when generating all screenshots"

**Helper Functions:**
- `prepare_screenshots_for_delivery()` (line 25): Copies normalized screenshots for ASC upload
  - **CRITICAL:** Explicitly skips `_framed.png` files (line 41)
  - **CRITICAL:** Only includes device-prefixed screenshots with correct dimensions

**Verification Lanes:**
- `verify_framed` (line 3374): Checks framed screenshot existence
- `validate_delivery_screenshots` (line 3547): Validates dimensions before ASC upload

#### B. GitHub Actions Workflows

**1. prepare-appstore.yml** (App Store screenshot preparation)
- **Jobs:** 3 parallel jobs (iPhone, iPad, Watch)
- **Lanes invoked:**
  - `screenshots_iphone` (no framing)
  - `screenshots_ipad` (no framing)
  - `watch_screenshots` (no framing)
- **Artifacts uploaded:**
  - `screenshots-iphone` → screenshots_compat/
  - `screenshots-ipad` → screenshots_compat/
  - `screenshots-watch` → watch_normalized/
- **Final step:** `release version:X.Y.Z` uploads to ASC
- **Framing:** ❌ NOT included

**2. publish-to-appstore.yml** (Publish committed screenshots)
- **Input:** Pre-committed screenshots from repository
- **Validation:** `validate_delivery_screenshots`
- **Upload:** `release version:X.Y.Z`
- **Framing:** ❌ NOT included

**3. release.yml** (TestFlight builds)
- **Purpose:** Binary uploads only (no screenshots)
- **Framing:** N/A

**4. ci.yml** (Continuous integration tests)
- **Purpose:** Build verification + unit tests
- **Framing:** N/A

#### C. Local Development Scripts

**1. .github/scripts/generate-screenshots-local.sh**
- **Wrapper:** Calls Fastlane lanes with validation
- **Modes:**
  - `iphone` → `screenshots_iphone`
  - `ipad` → `screenshots_ipad`
  - `watch` → `watch_screenshots`
  - `all` → All three in sequence
- **Framing:** ❌ NOT included
- **Cleanup:** Removes old screenshots before generation

**2. .github/scripts/local-preflight-check.sh**
- **Purpose:** Environment validation (Xcode, simulators, ImageMagick)
- **Framing dependency check:** Could be added here

#### D. Screenshot Storage Structure

```
fastlane/
├── screenshots/                    # Raw captures (gitignored)
│   ├── en-US/                      # Raw iOS/iPad (various dimensions)
│   ├── fi/                         # Raw iOS/iPad (various dimensions)
│   ├── framed/                     # FRAMED output (gitignored)
│   │   ├── en-US/
│   │   │   ├── iPhone 16 Pro Max-01_Welcome_framed.png (1421x2909)
│   │   │   ├── iPad Pro 13-inch (M4)-01_Welcome_framed.png
│   │   │   └── ... (Watch frames also here)
│   │   └── fi/
│   │       └── ... (same structure)
│   ├── watch/                      # Raw Watch screenshots
│   │   └── ... (gitignored)
│   └── watch_normalized/           # Normalized Watch (COMMITTED)
│       ├── en-US/                  # 396x484 pixels
│       └── fi/                     # 396x484 pixels
├── screenshots_compat/             # Normalized iOS/iPad (COMMITTED)
│   ├── en-US/                      # 1290x2796 (iPhone), 2064x2752 (iPad)
│   └── fi/                         # Same dimensions
├── Framefile.json                  # Frameit configuration
└── lib/
    └── screenshot_helper.rb        # Normalization + validation logic
```

**.gitignore rules:**
```
fastlane/screenshots/en-US/
fastlane/screenshots/fi/
fastlane/screenshots/framed/
fastlane/screenshots/*.html
fastlane/screenshots/test_output/
```

**Committed screenshots:**
- `fastlane/screenshots_compat/` (iPhone/iPad normalized)
- `fastlane/screenshots/watch_normalized/` (Watch normalized)

---

## 2. Integration Requirements

### 2.1 Dependencies

#### System Dependencies
| Dependency | Version | Purpose | Installation |
|------------|---------|---------|-------------|
| **ImageMagick** | Latest (brew) | Screenshot normalization + framing | `brew install imagemagick` |
| **Xcode** | 16.1+ | iOS/watchOS builds + simulators | App Store / Xcode website |
| **Ruby** | 3.2+ | Fastlane runtime | System / rbenv / asdf |
| **Bundler** | Latest | Gem management | `gem install bundler` |

#### Ruby Gems (via Bundler)
| Gem | Version | Purpose |
|-----|---------|---------|
| **fastlane** | ~> 2.x | Automation framework |
| **fastlane-plugin-frameit-fix** | (or frameit built-in) | Device frame generation |

**Note:** Frameit is typically included with Fastlane. Check with:
```bash
bundle list | grep frameit
```

If not present, add to `Gemfile`:
```ruby
gem 'fastlane-plugin-frameit-fix'  # or just rely on built-in frameit
```

### 2.2 Configuration Files

#### A. Framefile.json (EXISTING)
Location: `/Users/aleksi/source/ListAllApp/fastlane/Framefile.json`

**Current Configuration:**
```json
{
  "default": {
    "background": "#0E1117",
    "padding": 40,
    "title_color": "#FFFFFF",
    "font": "./fastlane/fonts/SF-Pro-Display-Semibold.ttf",
    "show_complete_frame": true,
    "stack_title": true,
    "title_max_width": 900,
    "title_font_size": 72,
    "subtitle_font_size": 40,
    "use_platform": true,
    "force_device_type": "generic"
  },
  "data": [
    // Screenshot-specific titles/subtitles for 01_Welcome, 02_MainScreen, Watch screens
  ]
}
```

**Status:** ✅ Already configured for all screenshots
**Font:** Requires `fastlane/fonts/SF-Pro-Display-Semibold.ttf` (check if exists)

**Validation Command:**
```bash
ls -la /Users/aleksi/source/ListAllApp/fastlane/fonts/
```

#### B. .gitignore (EXISTING - NO CHANGES NEEDED)
```
# Raw screenshots (not committed)
fastlane/screenshots/en-US/
fastlane/screenshots/fi/
fastlane/screenshots/framed/       # Framed output (gitignored)
fastlane/screenshots/*.html
fastlane/screenshots/test_output/

# Committed normalized screenshots
# (NOT ignored - these are versioned)
# fastlane/screenshots_compat/
# fastlane/screenshots/watch_normalized/
```

**Status:** ✅ Correctly configured - framed screenshots are gitignored

---

## 3. Integration Plan

### 3.1 Integration Options

#### Option A: **Dedicated Framing Lane (RECOMMENDED)**
**Status:** ✅ Already implemented (`screenshots_framed` lane)

**Pros:**
- Separation of concerns (framing is optional)
- Faster routine screenshot generation (skip framing)
- Framed screenshots only when needed (marketing, website)
- Existing implementation tested and working

**Cons:**
- Requires separate invocation
- Two-step process (generate → frame)

**Implementation:** Use existing `screenshots_framed` lane as-is

---

#### Option B: Add Framing Flag to Existing Lanes
**Status:** Would require modification

**Pros:**
- Single command for both workflows
- Flag-based control: `bundle exec fastlane screenshots_iphone framed:true`

**Cons:**
- Complicates existing lanes
- Slower default execution
- Higher risk of breaking existing workflow

**Implementation:** Add optional `framed` parameter to each lane

---

#### Option C: Separate Framing-Only Lane
**Status:** Would require new lane

**Pros:**
- Post-process existing screenshots anytime
- Very fast (no UI test execution)
- Flexible - frame only what you need

**Cons:**
- Requires normalized screenshots already exist
- Another lane to maintain

**Implementation:** New `frame_existing_screenshots` lane

---

### 3.2 Recommended Approach: **Option A with Enhancements**

**Rationale:**
1. Existing `screenshots_framed` lane already implements the full pipeline
2. Current workflow deliberately skips framing for speed (correct decision)
3. Framing is only needed for:
   - Marketing website assets
   - App Store preview images (not required for ASC submission)
   - Social media promotional materials
4. Separation allows:
   - CI/CD to generate normalized screenshots quickly
   - Developers to generate framed versions on-demand locally

**Integration Strategy:**
- **Keep** existing workflow untouched (no framing by default)
- **Enhance** `screenshots_framed` lane for better UX
- **Document** when to use framing vs. normalized screenshots
- **Add** validation checks to ensure Framefile consistency

---

## 4. Implementation Details

### 4.1 Fastlane Lane Integration

#### Current `screenshots_framed` Lane (Line 701)

**Workflow:**
1. Generate raw screenshots (all devices, all locales)
2. Normalize to App Store dimensions → `screenshots_compat/`
3. Frame with device bezels + text → `screenshots/framed/`
4. Verify framed output exists

**Status:** ✅ Fully functional (tested in commit history)

**No Changes Required** - Lane is complete.

#### Recommended Enhancement: Add Convenience Lane

**New Lane:** `frame_only` (post-process existing screenshots)

```ruby
desc "Frame existing normalized screenshots (fast - no UI test execution)"
lane :frame_only do
  UI.header("🖼️  Framing Existing Screenshots")

  # Verify normalized screenshots exist
  compat_root = File.expand_path("screenshots_compat", __dir__)
  unless Dir.exist?(compat_root)
    UI.user_error!("❌ No normalized screenshots found. Run screenshots_iphone or screenshots_ipad first.")
  end

  # Check for required screenshots
  locales = %w[en-US fi]
  missing = []
  locales.each do |locale|
    locale_dir = File.join(compat_root, locale)
    unless Dir.exist?(locale_dir) && Dir.glob(File.join(locale_dir, "*.png")).any?
      missing << locale
    end
  end

  unless missing.empty?
    UI.user_error!("❌ Missing screenshots for locales: #{missing.join(', ')}")
  end

  UI.success("✅ Found normalized screenshots for #{locales.join(', ')}")

  # Frame with Frameit
  UI.header("Framing screenshots with Frameit")
  ENV['SNAPSHOT_SCREENSHOTS_PATH'] = compat_root
  ENV['FRAMEIT_CONFIG_PATH'] = File.expand_path('Framefile.json', __dir__)

  frameit(
    path: compat_root,
    white: true
  )

  # Move framed output to dedicated directory
  framed_root = File.expand_path(File.join('screenshots', 'framed'), __dir__)
  FileUtils.rm_rf(framed_root)
  FileUtils.mkdir_p(framed_root)

  locales.each do |locale|
    src_dir = File.join(compat_root, locale)
    dst_dir = File.join(framed_root, locale)
    FileUtils.mkdir_p(dst_dir)

    # Copy framed screenshots
    Dir.glob(File.join(src_dir, '*_framed.png')).each do |framed_file|
      FileUtils.cp(framed_file, dst_dir)
    end

    # Clean up framed files from compat directory (keep it clean)
    Dir.glob(File.join(src_dir, '*_framed.png')).each do |framed_file|
      File.delete(framed_file)
    end
  end

  # Verify output
  framed_count = Dir.glob(File.join(framed_root, "**/*_framed.png")).count
  if framed_count == 0
    UI.user_error!("❌ No framed screenshots generated")
  end

  UI.success("✅ Generated #{framed_count} framed screenshots")
  UI.success("📁 Output: #{framed_root}")

  # Show example usage
  UI.message("")
  UI.message("Framed screenshots are ready for:")
  UI.message("  • Marketing website")
  UI.message("  • Social media posts")
  UI.message("  • App Store preview images (optional)")
  UI.message("")
  UI.message("Note: App Store Connect submissions use NORMALIZED screenshots")
  UI.message("      from screenshots_compat/ (without frames)")
end
```

**Usage:**
```bash
# Generate normalized screenshots first
bundle exec fastlane screenshots_iphone

# Then frame them (fast - no test execution)
bundle exec fastlane frame_only
```

---

### 4.2 Local Development Integration

#### Update: generate-screenshots-local.sh

**Add new framing mode:**

```bash
# Add to function definitions (around line 304)

generate_framed_screenshots() {
    log_info "Mode: Framing existing normalized screenshots"
    log_info "Prerequisites: Normalized screenshots must already exist"
    log_info "Estimated time: ~1-2 minutes (no UI test execution)"
    echo ""

    # Verify prerequisites
    if [[ ! -d "${PROJECT_ROOT}/fastlane/screenshots_compat/en-US" ]]; then
        log_error "Normalized screenshots not found"
        log_error "Run: ./generate-screenshots-local.sh all"
        return "${EXIT_GENERATION_FAILED}"
    fi

    if ! bundle exec fastlane ios frame_only; then
        log_error "Screenshot framing failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}
```

**Add to main() function:**

```bash
# Add to platform validation (around line 173)
validate_platform() {
    local platform="$1"

    case "${platform}" in
        iphone|ipad|watch|all|framed)  # Add 'framed'
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Add to main() switch statement (around line 422)
        framed)
            log_header "Frame Existing Screenshots"
            generate_framed_screenshots || exit $?
            ;;
```

**Update help text:**

```bash
# Add to show_help() function (around line 124)
    framed  - Frame existing normalized screenshots
              Fastlane lane: frame_only
              Prerequisites: Run 'all' or individual platforms first
              Estimated time: ~1-2 minutes
```

**New Usage:**
```bash
# Generate ALL screenshots with frames (slow - ~60-90 min)
./generate-screenshots-local.sh all
bundle exec fastlane frame_only

# OR: Two-step workflow
./generate-screenshots-local.sh all     # Generate normalized (slow)
./generate-screenshots-local.sh framed  # Add frames (fast)
```

---

### 4.3 CI/CD Integration

#### GitHub Actions: OPTIONAL Framing Workflow

**New File:** `.github/workflows/generate-framed-screenshots.yml`

```yaml
name: Generate Framed Screenshots (Marketing)

on:
  workflow_dispatch:
    inputs:
      upload_artifact:
        description: 'Upload framed screenshots as artifact'
        required: false
        default: true
        type: boolean

permissions:
  contents: read

jobs:
  frame-screenshots:
    name: Frame Existing Screenshots
    runs-on: macos-14
    timeout-minutes: 10
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true

      - name: Install ImageMagick
        run: brew install imagemagick

      - name: Verify normalized screenshots exist in repository
        run: |
          if [[ ! -d "fastlane/screenshots_compat/en-US" ]]; then
            echo "❌ Normalized screenshots not found in repository"
            echo "Run the 'Prepare App Store Release' workflow first"
            exit 1
          fi

          SCREENSHOT_COUNT=$(find fastlane/screenshots_compat -name "*.png" | wc -l | xargs)
          echo "✅ Found ${SCREENSHOT_COUNT} normalized screenshots"

      - name: Frame screenshots
        run: bundle exec fastlane ios frame_only

      - name: List framed screenshots
        run: |
          echo "=== Framed Screenshots ==="
          find fastlane/screenshots/framed -name "*_framed.png" -type f | head -20

      - name: Upload framed screenshots artifact
        if: inputs.upload_artifact
        uses: actions/upload-artifact@v4
        with:
          name: framed-screenshots
          path: fastlane/screenshots/framed/
          retention-days: 30

      - name: Summary
        run: |
          FRAMED_COUNT=$(find fastlane/screenshots/framed -name "*_framed.png" | wc -l | xargs)
          echo "## 🎉 Screenshot Framing Complete!" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Framed Screenshots Generated: ${FRAMED_COUNT}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Output Location" >> $GITHUB_STEP_SUMMARY
          echo "- Artifact: framed-screenshots" >> $GITHUB_STEP_SUMMARY
          echo "- Local path: fastlane/screenshots/framed/" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Use Cases" >> $GITHUB_STEP_SUMMARY
          echo "- 🌐 Marketing website assets" >> $GITHUB_STEP_SUMMARY
          echo "- 📱 Social media promotional images" >> $GITHUB_STEP_SUMMARY
          echo "- 🖼️  App Store preview images (optional)" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Note:** App Store Connect submissions use normalized screenshots" >> $GITHUB_STEP_SUMMARY
          echo "(without frames) from screenshots_compat/" >> $GITHUB_STEP_SUMMARY
```

**When to Run:**
- Manual trigger via GitHub Actions UI
- After screenshot generation workflows complete
- When updating marketing materials

**Benefits:**
- Fast execution (~2 minutes vs. 90 minutes for full generation)
- Reuses committed normalized screenshots
- No simulator/test overhead
- Artifact download for marketing team

---

### 4.4 Documentation Integration

#### Update: README.md

**Add section after "App Store Release":**

```markdown
## Marketing Screenshots (Framed)

For marketing materials, social media, and website assets, generate framed screenshots with device bezels and promotional text:

### Local Generation

```bash
# Option 1: Generate normalized + framed (slow - ~90 min)
.github/scripts/generate-screenshots-local.sh all
bundle exec fastlane frame_only

# Option 2: Frame existing normalized screenshots (fast - ~2 min)
bundle exec fastlane frame_only
```

**Output Location:** `fastlane/screenshots/framed/`

### CI/CD Generation

1. Go to **Actions** → **Generate Framed Screenshots (Marketing)**
2. Click **"Run workflow"**
3. Download artifact: `framed-screenshots`

**Prerequisites:** Normalized screenshots must exist in repository (run "Prepare App Store Release" first)

### Important Notes

- **Framed screenshots are NOT uploaded to App Store Connect**
- App Store submissions use normalized screenshots from `screenshots_compat/`
- Framed screenshots are gitignored (not committed to repository)
- Use framed screenshots for:
  - Marketing website
  - Social media posts
  - App Store preview images (optional - frames are not required)

### Customization

Edit `fastlane/Framefile.json` to change:
- Background color
- Title/subtitle text (per locale)
- Font sizes
- Device frame appearance

**Fonts:** Stored in `fastlane/fonts/`
```

#### Create: documentation/screenshot_framing.md (NEW FILE)

```markdown
# Screenshot Framing Guide

## Overview

ListAll uses Fastlane's `frameit` gem to add device frames and marketing text to screenshots for promotional purposes. This guide covers when to use framing, how to generate framed screenshots, and customization options.

## When to Use Framing

### ✅ Use Framed Screenshots For:
- **Marketing website:** Attractive product images with context
- **Social media posts:** Eye-catching promotional materials
- **Press kits:** Professional-looking app previews
- **App Store preview images (optional):** Enhanced visual appeal

### ❌ Do NOT Use Framed Screenshots For:
- **App Store Connect submissions:** ASC requires exact pixel dimensions
  - iPhone 6.7": 1290x2796
  - iPad 13": 2064x2752
  - Watch Series 7+: 396x484
- **Automated CI/CD uploads:** Normalized screenshots ensure compatibility

## Technical Details

### Data Flow

```
Normalized Screenshots (screenshots_compat/)
              ↓
         Frameit Processing
              ↓
     Device Frame + Text Overlay
              ↓
  Framed Screenshots (screenshots/framed/)
```

### Dimensions

| Device | Normalized (ASC) | Framed (Marketing) |
|--------|------------------|-------------------|
| iPhone 6.7" | 1290x2796 | ~1421x2909 |
| iPad 13" | 2064x2752 | Variable |
| Watch Series 10 | 396x484 | Variable |

**Note:** Framed dimensions are non-standard and vary based on frame style and padding.

### File Naming

- **Normalized:** `iPhone 16 Pro Max-01_Welcome.png`
- **Framed:** `iPhone 16 Pro Max-01_Welcome_framed.png`

## Generation Methods

### Method 1: Local (Fast - Frame Existing)

**Prerequisites:** Normalized screenshots must already exist

```bash
bundle exec fastlane frame_only
```

**Time:** ~1-2 minutes
**Output:** `fastlane/screenshots/framed/`

### Method 2: Local (Full Pipeline)

**Generates normalized + framed in one go:**

```bash
bundle exec fastlane screenshots_framed
```

**Time:** ~60-90 minutes
**Output:** Both `screenshots_compat/` and `screenshots/framed/`

### Method 3: CI/CD (GitHub Actions)

**Workflow:** "Generate Framed Screenshots (Marketing)"

1. Go to **Actions** → **Generate Framed Screenshots (Marketing)**
2. Click **"Run workflow"**
3. Wait ~2 minutes
4. Download artifact: `framed-screenshots`

**Prerequisites:** Normalized screenshots committed to repository

## Customization

### Edit Framefile.json

Location: `fastlane/Framefile.json`

#### Global Settings

```json
{
  "default": {
    "background": "#0E1117",       // Dark background color
    "padding": 40,                 // Padding around frame (pixels)
    "title_color": "#FFFFFF",      // Title text color
    "font": "./fastlane/fonts/SF-Pro-Display-Semibold.ttf",
    "title_font_size": 72,         // Title size
    "subtitle_font_size": 40,      // Subtitle size
    "show_complete_frame": true,   // Show full device frame
    "stack_title": true            // Stack title/subtitle vertically
  }
}
```

#### Per-Screenshot Text

```json
{
  "data": [
    {
      "filter": "01_Welcome",      // Matches filename
      "title": {
        "en-US": "Organize Anything Instantly",
        "fi": "Järjestä Kaikki Hetkessä"
      },
      "subtitle": {
        "en-US": "Start with smart list templates",
        "fi": "Aloita älykkäillä listapohjilla"
      }
    }
  ]
}
```

### Add New Locales

1. Add UI test support (modify `ListAllUITests_Screenshots.swift`)
2. Update `Framefile.json` with translations
3. Generate screenshots: `bundle exec fastlane frame_only`

### Change Fonts

1. Add font file to `fastlane/fonts/`
2. Update `Framefile.json`:
   ```json
   "font": "./fastlane/fonts/YourFont.ttf"
   ```
3. Regenerate: `bundle exec fastlane frame_only`

## Troubleshooting

### Issue: "No normalized screenshots found"

**Cause:** Framing requires normalized screenshots to exist first

**Solution:**
```bash
bundle exec fastlane screenshots_iphone
bundle exec fastlane screenshots_ipad
bundle exec fastlane frame_only
```

### Issue: "Frameit failed - unknown device"

**Cause:** Device name not recognized by Frameit

**Solution:** Check `Framefile.json` setting:
```json
"force_device_type": "generic"  // Use generic frame style
```

### Issue: "Font file not found"

**Cause:** Font path in Framefile.json is incorrect

**Solution:**
```bash
ls fastlane/fonts/
# Update Framefile.json with correct path
```

### Issue: Framed dimensions rejected by App Store Connect

**Cause:** Using framed screenshots instead of normalized

**Solution:** Use normalized screenshots from `screenshots_compat/` for ASC submissions

## Storage and Git

### Directory Structure

```
fastlane/
├── screenshots_compat/          # Normalized (COMMITTED)
│   ├── en-US/
│   └── fi/
├── screenshots/
│   └── framed/                  # Framed (GITIGNORED)
│       ├── en-US/
│       └── fi/
└── Framefile.json               # Configuration (COMMITTED)
```

### Git Rules

**.gitignore:**
```
fastlane/screenshots/framed/     # Framed screenshots NOT committed
```

**Rationale:**
- Framed screenshots are large files (~500KB each)
- Generated on-demand from normalized versions
- Not required for CI/CD or App Store submissions
- Reduces repository size

### CI/CD Artifact Storage

- **Normalized screenshots:** Committed to repository
- **Framed screenshots:** Generated in CI, downloaded as artifacts
- **Retention:** 30 days (configurable in workflow)

## Integration with Existing Workflow

### Current Screenshot Pipeline (No Framing)

```bash
# Local
.github/scripts/generate-screenshots-local.sh all

# CI/CD
GitHub Actions → "Prepare App Store Release" → Upload to ASC
```

**Framing is optional and separate.**

### With Framing (Marketing Materials)

```bash
# Local
.github/scripts/generate-screenshots-local.sh all  # Generate normalized
bundle exec fastlane frame_only                     # Add frames

# CI/CD
GitHub Actions → "Prepare App Store Release"        # Generate normalized
GitHub Actions → "Generate Framed Screenshots"      # Add frames
```

## Performance

| Operation | Time | Output Size |
|-----------|------|-------------|
| Generate normalized (all platforms) | ~60-90 min | ~18 screenshots |
| Frame existing screenshots | ~1-2 min | ~18 framed screenshots |
| Upload to ASC (normalized) | ~5-10 min | N/A |

**Recommendation:** Generate framed screenshots only when updating marketing materials, not on every screenshot generation run.

## References

- [Fastlane Frameit Documentation](https://docs.fastlane.tools/actions/frameit/)
- [App Store Connect Screenshot Specifications](https://help.apple.com/app-store-connect/)
- ListAll Fastfile: `fastlane/Fastfile` (lines 701-3371)
- Screenshot Helper: `fastlane/lib/screenshot_helper.rb`

---

**Last Updated:** 2025-11-28
**Maintained By:** Development Team
```

---

## 5. Environment Variables and Configuration

### 5.1 Required Environment Variables

#### Local Development

**For Framing:**
- None required (all configuration in Framefile.json)

**For Screenshot Generation (broader context):**
```bash
SNAPSHOT_SIMULATOR_WAIT_FOR_BOOT_TIMEOUT=60  # Fastlane snapshot timeout
SIMULATOR_HOST_HOME=$HOME                     # Simulator cache directory
NSUnbufferedIO=YES                            # Log output buffering
```

#### CI/CD (GitHub Actions)

**For Framing:**
- None required (ImageMagick via Homebrew)

**For ASC Upload (broader context):**
```bash
ASC_KEY_ID=<App Store Connect Key ID>
ASC_ISSUER_ID=<App Store Connect Issuer ID>
ASC_KEY_BASE64=<Base64-encoded API key>
```

### 5.2 Framefile.json Schema

**Required Fields:**
```json
{
  "default": {
    "background": "<hex color>",
    "padding": <pixels>,
    "title_color": "<hex color>",
    "font": "<path to TTF>",
    "show_complete_frame": true|false,
    "stack_title": true|false
  },
  "data": [
    {
      "filter": "<screenshot filename pattern>",
      "title": { "<locale>": "<text>" },
      "subtitle": { "<locale>": "<text>" }
    }
  ]
}
```

**Validation:**
```bash
# Check JSON syntax
jq empty fastlane/Framefile.json

# Verify font exists
ls -la $(jq -r '.default.font' fastlane/Framefile.json)
```

---

## 6. Testing and Validation

### 6.1 Pre-Integration Checklist

- [ ] ImageMagick installed: `which convert`
- [ ] Frameit available: `bundle list | grep frameit`
- [ ] Font file exists: `ls fastlane/fonts/SF-Pro-Display-Semibold.ttf`
- [ ] Framefile.json valid: `jq empty fastlane/Framefile.json`
- [ ] Normalized screenshots exist: `ls fastlane/screenshots_compat/en-US/*.png`

### 6.2 Integration Tests

#### Test 1: Local Framing (Fast Path)

```bash
# Prerequisites
bundle exec fastlane screenshots_iphone

# Test framing
bundle exec fastlane frame_only

# Verify output
ls -lh fastlane/screenshots/framed/en-US/*_framed.png
identify fastlane/screenshots/framed/en-US/iPhone\ 16\ Pro\ Max-01_Welcome_framed.png
```

**Expected:**
- Framed screenshots exist in `screenshots/framed/{locale}/`
- Dimensions are NON-STANDARD (e.g., ~1421x2909 for iPhone)
- File size: ~200-600 KB per image

#### Test 2: Full Pipeline (Slow Path)

```bash
# Test full workflow
bundle exec fastlane screenshots_framed

# Verify normalized output
ls -lh fastlane/screenshots_compat/en-US/*.png

# Verify framed output
ls -lh fastlane/screenshots/framed/en-US/*_framed.png

# Validate dimensions
bundle exec fastlane validate_delivery_screenshots  # Should pass (checks compat)
```

**Expected:**
- Normalized screenshots: Exact ASC dimensions
- Framed screenshots: Non-standard dimensions with device bezels
- Validation passes for normalized (not framed)

#### Test 3: CI/CD Workflow

```bash
# Trigger via GitHub Actions UI
# Actions → "Generate Framed Screenshots (Marketing)" → Run workflow

# OR: Local simulation
cd /Users/aleksi/source/ListAllApp
git checkout feature/framed-screenshots

# Simulate CI steps
bundle install
brew list imagemagick || brew install imagemagick
bundle exec fastlane frame_only

# Check artifacts
find fastlane/screenshots/framed -name "*_framed.png" | wc -l
```

**Expected:**
- Workflow completes in ~2 minutes
- Artifact contains all framed screenshots
- No errors in GitHub Actions logs

### 6.3 Validation Commands

**Verify dimensions:**
```bash
for img in fastlane/screenshots/framed/en-US/*.png; do
  echo "$(basename "$img"): $(identify -format '%wx%h' "$img")"
done
```

**Check file sizes:**
```bash
du -sh fastlane/screenshots/framed/
ls -lh fastlane/screenshots/framed/en-US/ | awk '{print $5, $9}'
```

**Compare normalized vs. framed:**
```bash
echo "=== Normalized (ASC-compliant) ==="
identify fastlane/screenshots_compat/en-US/iPhone\ 16\ Pro\ Max-01_Welcome.png

echo "=== Framed (Marketing) ==="
identify fastlane/screenshots/framed/en-US/iPhone\ 16\ Pro\ Max-01_Welcome_framed.png
```

---

## 7. Rollout Plan

### 7.1 Phase 1: Foundation (COMPLETE ✅)

**Status:** Already implemented in `feature/framed-screenshots` branch

- [x] `screenshots_framed` lane implemented
- [x] Framefile.json configured
- [x] .gitignore rules set
- [x] `verify_framed` lane added
- [x] Integration tested locally

**Evidence:**
- Commit a26d0eb: "Skip device framing when generating all screenshots"
- Commit 59eaea8: "Fix App Store upload: Use raw normalized screenshots (not framed)"
- Framed screenshots exist in `/Users/aleksi/source/ListAllApp/fastlane/screenshots/framed/`

### 7.2 Phase 2: Enhancement (RECOMMENDED)

**Goal:** Add convenience lane for fast framing

**Tasks:**
1. Add `frame_only` lane to Fastfile
2. Update generate-screenshots-local.sh with `framed` mode
3. Test locally: `bundle exec fastlane frame_only`
4. Document usage in README.md

**Estimated Effort:** 2-3 hours

**Risk:** Low (additive changes only)

### 7.3 Phase 3: Documentation (RECOMMENDED)

**Goal:** Comprehensive user and developer documentation

**Tasks:**
1. Create `documentation/screenshot_framing.md`
2. Update README.md with framing section
3. Add troubleshooting guide
4. Document Framefile.json schema

**Estimated Effort:** 1-2 hours

**Risk:** None (documentation only)

### 7.4 Phase 4: CI/CD Integration (OPTIONAL)

**Goal:** Automated framing in GitHub Actions

**Tasks:**
1. Create `.github/workflows/generate-framed-screenshots.yml`
2. Test workflow execution
3. Verify artifact upload
4. Add workflow badge to README

**Estimated Effort:** 2-4 hours

**Risk:** Low (separate workflow, no impact on existing pipelines)

### 7.5 Phase 5: Monitoring (ONGOING)

**Goal:** Track framing performance and usage

**Metrics:**
- Execution time (target: <5 minutes)
- Success rate (target: >95%)
- File sizes (monitor for bloat)
- Developer feedback

**Tools:**
- GitHub Actions logs
- Local execution timing
- Manual screenshot review

---

## 8. Risk Analysis

### 8.1 Integration Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Frameit gem compatibility** | High | Low | Test with current Fastlane version; fallback to fastlane-plugin-frameit-fix |
| **Font file missing** | Medium | Medium | Pre-flight check in scripts; document font installation |
| **Frame dimensions break ASC upload** | High | Low | Never use framed screenshots for ASC (documented) |
| **CI workflow timeout** | Medium | Low | Keep framing as separate optional workflow |
| **Large artifact sizes** | Low | Medium | 30-day retention; compress if needed |
| **Developer confusion (framed vs. normalized)** | Medium | High | Clear documentation; naming conventions (_framed suffix) |

### 8.2 Operational Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Slow local execution** | Low | Low | Use `frame_only` for fast iteration |
| **Git repository bloat** | High | Low | Framed screenshots gitignored (already configured) |
| **Inconsistent marketing materials** | Medium | Medium | Version control Framefile.json; document customization |
| **Stale framed screenshots** | Low | High | Regenerate when updating marketing site |

### 8.3 Dependency Risks

| Dependency | Risk | Mitigation |
|------------|------|------------|
| **ImageMagick** | Homebrew updates may break CLI | Pin version; test before CI updates |
| **Fastlane Frameit** | Gem deprecation | Monitor Fastlane releases; consider alternatives (device-frames library) |
| **SF Pro Font** | Apple license changes | Bundle font file; check redistribution rights |

---

## 9. Success Criteria

### 9.1 Integration Success Metrics

**Phase 2 (Enhancement):**
- [ ] `frame_only` lane executes in <5 minutes locally
- [ ] Framed screenshots match Framefile.json configuration
- [ ] No errors in local execution
- [ ] Script updates work with existing workflows

**Phase 3 (Documentation):**
- [ ] README.md clearly explains framing vs. normalized
- [ ] Troubleshooting guide covers common issues
- [ ] Developer can generate framed screenshots without assistance

**Phase 4 (CI/CD):**
- [ ] GitHub Actions workflow completes in <10 minutes
- [ ] Artifacts download successfully
- [ ] No impact on existing CI/CD pipelines

### 9.2 Acceptance Criteria

**User Perspective:**
- Marketing team can download framed screenshots from GitHub Actions
- Developers can generate framed screenshots locally in <5 minutes
- No confusion about when to use framed vs. normalized screenshots

**Technical Perspective:**
- Framed screenshots never uploaded to App Store Connect
- Git repository size remains stable (framed screenshots gitignored)
- CI/CD pipelines execute without failures

**Quality Perspective:**
- All screenshots include device frames and correct marketing text
- Framed dimensions are consistent across devices
- Text localization works correctly (EN, FI)

---

## 10. Maintenance Plan

### 10.1 Regular Maintenance Tasks

**Monthly:**
- [ ] Verify Framefile.json is up-to-date with latest screenshots
- [ ] Check font file integrity
- [ ] Review framed screenshot quality

**Per Release:**
- [ ] Regenerate framed screenshots if UI changes
- [ ] Update marketing text in Framefile.json if needed
- [ ] Test local and CI framing workflows

**Quarterly:**
- [ ] Review ImageMagick version compatibility
- [ ] Check Fastlane Frameit for updates/deprecation
- [ ] Audit git repository size (ensure framed screenshots not committed)

### 10.2 Troubleshooting Contacts

**ImageMagick Issues:**
- Homebrew: `brew doctor`, `brew upgrade imagemagick`
- Docs: https://imagemagick.org/

**Fastlane Frameit Issues:**
- Fastlane Docs: https://docs.fastlane.tools/actions/frameit/
- GitHub Issues: https://github.com/fastlane/fastlane/issues

**Font Issues:**
- SF Pro Download: https://developer.apple.com/fonts/
- License: Check Apple Developer Terms

### 10.3 Update Procedures

**Adding New Screenshots:**
1. Update UI tests to capture new screens
2. Add entries to `Framefile.json`:
   ```json
   {
     "filter": "03_NewScreen",
     "title": { "en-US": "...", "fi": "..." },
     "subtitle": { "en-US": "...", "fi": "..." }
   }
   ```
3. Regenerate: `bundle exec fastlane frame_only`
4. Review output in `screenshots/framed/`

**Changing Device Frames:**
1. Update `Framefile.json` → `default.show_complete_frame`
2. Test: `bundle exec fastlane frame_only`
3. Commit Framefile.json changes

**Adding New Locales:**
1. Add locale to UI tests
2. Update Framefile.json with translations
3. Update `locales` array in Fastfile (line 30, 745)
4. Regenerate all screenshots

---

## 11. Conclusion and Next Steps

### 11.1 Current State Assessment

**✅ Strengths:**
- Framing infrastructure fully implemented (`screenshots_framed` lane)
- Proper separation: normalized for ASC, framed for marketing
- Framefile.json well-configured with localized text
- Git rules correctly ignore framed screenshots
- Recent commit history shows deliberate decision to skip framing (correct for speed)

**⚠️ Gaps:**
- No convenience lane for fast framing (`frame_only`)
- Documentation scattered (needs consolidation)
- No CI/CD workflow for marketing team to download framed screenshots
- generate-screenshots-local.sh doesn't support framing mode

**❌ Risks:**
- Developer confusion: When to use framed vs. normalized?
- Manual process: Marketing team must request framed screenshots from developers

### 11.2 Recommended Next Steps

**Immediate (Phase 2 - Next Sprint):**
1. ✅ **Add `frame_only` lane** (see Section 4.1)
   - Estimated time: 1 hour
   - Risk: Low
   - Benefit: 50x faster framing (2 min vs. 90 min)

2. ✅ **Update generate-screenshots-local.sh** (see Section 4.2)
   - Estimated time: 1 hour
   - Risk: Low
   - Benefit: Consistent local development UX

**Short-term (Phase 3 - This Quarter):**
3. ✅ **Create documentation/screenshot_framing.md** (see Section 4.4)
   - Estimated time: 2 hours
   - Risk: None
   - Benefit: Self-service for developers and marketing team

4. ✅ **Update README.md** (see Section 4.4)
   - Estimated time: 30 minutes
   - Risk: None
   - Benefit: Improved onboarding

**Optional (Phase 4 - Future):**
5. ⚠️ **Create CI/CD framing workflow** (see Section 4.3)
   - Estimated time: 3 hours
   - Risk: Low
   - Benefit: Marketing team self-service

6. ⚠️ **Add pre-flight checks** to local-preflight-check.sh
   - Estimated time: 30 minutes
   - Risk: None
   - Benefit: Catch missing dependencies early

### 11.3 Decision Points

**Q: Should framing be included in default screenshot generation?**
A: **NO.** Current approach is correct - framing is slow and only needed for marketing. Keep separate.

**Q: Should framed screenshots be committed to git?**
A: **NO.** Already correctly gitignored. Framed screenshots are derived artifacts, not source of truth.

**Q: Should we add CI/CD framing workflow?**
A: **OPTIONAL.** Low priority. Marketing team can download GitHub Actions artifacts if needed. Add if marketing requests it.

**Q: Should we use Frameit or alternatives (device-frames library)?**
A: **Keep Frameit for now.** It's working and maintained by Fastlane team. Monitor for deprecation, but no urgent need to migrate.

---

## 12. References and Resources

### 12.1 External Documentation

- **Fastlane Frameit:** https://docs.fastlane.tools/actions/frameit/
- **App Store Connect Screenshot Specs:** https://help.apple.com/app-store-connect/
- **ImageMagick CLI:** https://imagemagick.org/script/command-line-processing.php
- **SF Pro Fonts:** https://developer.apple.com/fonts/

### 12.2 Internal Documentation

- **Project README:** `/Users/aleksi/source/ListAllApp/README.md`
- **Fastfile:** `/Users/aleksi/source/ListAllApp/fastlane/Fastfile`
- **Screenshot Helper:** `/Users/aleksi/source/ListAllApp/fastlane/lib/screenshot_helper.rb`
- **Framefile Config:** `/Users/aleksi/source/ListAllApp/fastlane/Framefile.json`
- **Local Generation Script:** `/Users/aleksi/source/ListAllApp/.github/scripts/generate-screenshots-local.sh`

### 12.3 Related Commits

- `a26d0eb` - Skip device framing when generating all screenshots
- `59eaea8` - Fix App Store upload: Use raw normalized screenshots (not framed)
- `b4d712e` - Split screenshot generation into parallel iPhone/iPad and Watch jobs
- `6f5aeaa` - Fix pipeline: Update verify_framed prefixes and fix all inch (M4) bugs

### 12.4 Key Contacts

**Integration Specialist:** Claude Code (this agent)
**Project Owner:** Check git blame on `fastlane/Framefile.json`
**CI/CD Maintainer:** Check `.github/workflows/` commit history

---

## Appendix A: File Paths Reference

### Critical Files

| File | Path | Purpose |
|------|------|---------|
| **Fastfile** | `/Users/aleksi/source/ListAllApp/fastlane/Fastfile` | Main automation script |
| **Framefile** | `/Users/aleksi/source/ListAllApp/fastlane/Framefile.json` | Framing configuration |
| **Screenshot Helper** | `/Users/aleksi/source/ListAllApp/fastlane/lib/screenshot_helper.rb` | Normalization + validation |
| **Local Script** | `/Users/aleksi/source/ListAllApp/.github/scripts/generate-screenshots-local.sh` | Developer wrapper |
| **CI Workflow** | `/Users/aleksi/source/ListAllApp/.github/workflows/prepare-appstore.yml` | Screenshot generation CI |

### Screenshot Directories

| Directory | Status | Purpose |
|-----------|--------|---------|
| `fastlane/screenshots/en-US/` | Gitignored | Raw captures |
| `fastlane/screenshots/fi/` | Gitignored | Raw captures |
| `fastlane/screenshots/framed/` | Gitignored | **Framed output (marketing)** |
| `fastlane/screenshots_compat/` | **Committed** | Normalized (ASC submission) |
| `fastlane/screenshots/watch_normalized/` | **Committed** | Normalized Watch (ASC submission) |

---

**Document Version:** 1.0
**Last Updated:** 2025-11-28
**Prepared By:** Integration Specialist Agent
**Review Status:** Ready for Implementation

