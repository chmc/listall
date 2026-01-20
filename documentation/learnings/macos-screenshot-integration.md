---
title: macOS Screenshot Integration with generate-screenshots-local.sh
date: 2026-01-02
severity: MEDIUM
category: macos
tags: [bash, integration, fastlane, mktemp, screenshots]
symptoms: [need automated post-processing after Fastlane, summary shows wrong paths]
root_cause: Processing script needed integration with existing screenshot generation pipeline
solution: Add post-processing call after Fastlane in generate_macos_screenshots(); update summary paths
files_affected:
  - .github/scripts/generate-screenshots-local.sh
  - .github/scripts/lib/macos-screenshot-helper.sh
related:
  - macos-batch-screenshot-processing.md
  - macos-screenshot-helper-implementation.md
---

## Problem

The macOS screenshot processing script needed integration with `generate-screenshots-local.sh` so:
1. Post-processing runs automatically after Fastlane
2. Users don't need separate command
3. Output paths display correctly in summary

## Solution

### 1. Updated generate_macos_screenshots()

```bash
generate_macos_screenshots() {
    if ! bundle exec fastlane ios screenshots_macos; then
        return "${EXIT_GENERATION_FAILED}"
    fi

    # NEW: Post-process for App Store format
    log_info "Processing screenshots for App Store dimensions..."
    if ! "${SCRIPT_DIR}/process-macos-screenshots.sh"; then
        log_error "macOS screenshot processing failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}
```

### 2. Updated show_summary()

```bash
# Before
echo "  macOS (unframed):"
echo "    fastlane/screenshots/mac/en-US/"

# After
echo "  macOS (processed with gradient background):"
echo "    fastlane/screenshots/mac/processed/en-US/"
```

### 3. Updated git add Command

```bash
git add fastlane/screenshots/mac/processed/
```

## macOS mktemp Quirk

On macOS, `mktemp /tmp/pattern_XXXXXX.png` doesn't work - XXXXXX must be at end:

```bash
# BAD: Fails on macOS
temp_file=$(mktemp /tmp/macos_rounded_XXXXXX.png)

# GOOD: Create without extension, then rename
temp_base=$(mktemp /tmp/macos_rounded_XXXXXX)
temp_rounded="${temp_base}.png"
mv "${temp_base}" "${temp_rounded}"
```

## Key Learnings

1. **Keep integration simple** - just call existing script
2. **Use ${SCRIPT_DIR}** for portability
3. **Update all summary locations** - same path shown in multiple places
4. **macOS mktemp differs from Linux** - extension must be added separately
5. **Always run actual script** - unit tests may pass but real script can fail
