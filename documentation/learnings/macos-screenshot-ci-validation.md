---
title: macOS Screenshot CI Validation Workflow
date: 2026-01-02
severity: MEDIUM
category: ci-cd
tags: [github-actions, imagemagick, validation, app-store, macos]
symptoms: [need CI validation for screenshots, ensure App Store requirements met]
root_cause: Screenshots need automated validation for dimensions, alpha channel, and file size
solution: Created GitHub Actions workflow with path-based triggers and error annotations
files_affected:
  - .github/workflows/validate-macos-screenshots.yml
related:
  - macos-screenshot-pipeline-integration.md
  - macos-batch-screenshot-processing.md
---

## Problem

macOS screenshot processing pipeline needed CI validation to ensure:
1. Processed screenshots exist in repository
2. All screenshots meet App Store dimension requirements (2880x1800)
3. All screenshots have no alpha channel
4. All screenshots are under 10MB size limit

## Solution

Created `.github/workflows/validate-macos-screenshots.yml`:

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

### Path-Based Triggering

Only runs when files under `fastlane/screenshots/mac/**` change.

### Concurrency Control

```yaml
concurrency:
  group: validate-macos-${{ github.ref }}
  cancel-in-progress: true
```

### GitHub Actions Error Annotations

```bash
echo "::error file=$f::Invalid dimensions for $(basename "$f"): $dims"
```

### ImageMagick Validation Commands

```bash
# Dimensions
dims=$(magick identify -format "%wx%h" "$f")

# Alpha channel
channels=$(magick identify -format "%[channels]" "$f")

# File size (macOS stat syntax)
size=$(stat -f%z "$f")
```

## Validation Requirements

| Requirement | Value | Reason |
|-------------|-------|--------|
| Dimensions | 2880x1800 | App Store requirement |
| Alpha Channel | None | App Store rejects alpha |
| Max File Size | 10MB | App Store limit |
| Format | PNG | Standard format |

## Key Learnings

1. **Use path-based triggers** - only run when screenshots change
2. **Add concurrency control** - cancel old runs to save CI minutes
3. **Report all errors** - don't exit on first error
4. **Use annotations** - `::error file=$f::` shows errors inline in PR
5. **Always run summary** - use `if: always()` for results even on failure
6. **macOS stat syntax** - use `stat -f%z` not `stat -c%s` (Linux)
