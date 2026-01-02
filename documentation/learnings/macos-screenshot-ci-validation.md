# macOS Screenshot CI Validation Workflow

**Date:** January 2, 2026
**Phase:** Phase 4 - Validation & CI

## Problem

The macOS screenshot processing pipeline needed CI validation to ensure:
1. Processed screenshots exist in the repository
2. All screenshots meet App Store dimension requirements (2880x1800)
3. All screenshots have no alpha channel (required by App Store)
4. All screenshots are under the 10MB size limit

## Solution

Created a GitHub Actions workflow at `.github/workflows/validate-macos-screenshots.yml` that:

1. **Triggers on** PR and push events affecting `fastlane/screenshots/mac/**`
2. **Runs on** `macos-14` runner (Apple Silicon)
3. **Validates** processed screenshots against App Store requirements

### Workflow Structure

```yaml
name: Validate macOS Screenshots

on:
  pull_request:
    paths:
      - 'fastlane/screenshots/mac/**'
  push:
    branches: [main]
    paths:
      - 'fastlane/screenshots/mac/**'

jobs:
  validate-macos-screenshots:
    runs-on: macos-14
    timeout-minutes: 5
    steps:
      - Checkout
      - Install ImageMagick
      - Check processed screenshots exist
      - Validate dimensions (2880x1800)
      - Validate no alpha channel
      - Validate file size (<10MB)
      - Summary (always runs)
```

## Key Technical Details

### 1. Path-Based Triggering

The workflow only runs when files under `fastlane/screenshots/mac/**` change, avoiding unnecessary CI runs for unrelated changes.

### 2. Concurrency Control

```yaml
concurrency:
  group: validate-macos-${{ github.ref }}
  cancel-in-progress: true
```

This cancels in-progress runs when new commits are pushed to the same branch, saving CI minutes.

### 3. Error Reporting

Uses GitHub Actions annotations to highlight specific files with issues:

```bash
echo "::error file=$f::Invalid dimensions for $(basename "$f"): $dims"
```

### 4. ImageMagick Validation Commands

```bash
# Dimensions check
dims=$(magick identify -format "%wx%h" "$f")

# Alpha channel check
channels=$(magick identify -format "%[channels]" "$f")

# File size check (macOS stat syntax)
size=$(stat -f%z "$f")
```

### 5. Summary Generation

The workflow always generates a summary with screenshot counts per locale, even if validation fails:

```bash
echo "## macOS Screenshot Validation Results" >> $GITHUB_STEP_SUMMARY
```

## Validation Requirements

| Requirement | Value | Reason |
|-------------|-------|--------|
| Dimensions | 2880x1800 | App Store requirement for macOS |
| Alpha Channel | None | App Store rejects images with alpha |
| Max File Size | 10MB | App Store limit per screenshot |
| Format | PNG | Standard format for screenshots |

## Error Handling

Each validation step:
1. Uses `set -e` to exit on first error
2. Counts all errors before exiting (to report all issues)
3. Uses `((error_count++)) || true` to prevent errexit on zero increment
4. Reports errors with `::error::` annotation for GitHub UI

## Lessons Learned

1. **Use path-based triggers**: Only run validation when screenshots change
2. **Add concurrency control**: Cancel old runs to save CI minutes
3. **Report all errors**: Don't exit on first error, collect all issues
4. **Use annotations**: `::error file=$f::` shows errors inline in PR
5. **Always run summary**: Use `if: always()` to show results even on failure
6. **Short timeout**: Screenshot validation is fast (5 min is plenty)
7. **macOS stat syntax**: Use `stat -f%z` on macOS, not `stat -c%s` (Linux)

## Files Created

- `.github/workflows/validate-macos-screenshots.yml` - CI validation workflow

## Related Files

- `.github/scripts/process-macos-screenshots.sh` - Processing script
- `.github/scripts/lib/macos-screenshot-helper.sh` - Helper library
- `fastlane/screenshots/mac/processed/` - Processed screenshots directory
