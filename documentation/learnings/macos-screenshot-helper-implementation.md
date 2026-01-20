---
title: macOS Screenshot Helper Library Implementation
date: 2026-01-02
severity: MEDIUM
category: macos
tags: [imagemagick, bash, screenshots, app-store, gradient, shadow]
symptoms: [need reusable screenshot processing, App Store format conversion]
root_cause: Raw XCUITest screenshots need processing for App Store (gradient background, drop shadow, 2880x1800)
solution: Created macos-screenshot-helper.sh with ImageMagick processing functions
files_affected:
  - .github/scripts/lib/macos-screenshot-helper.sh
related:
  - macos-batch-screenshot-processing.md
  - macos-screenshot-scaling-optimization.md
  - macos-screenshot-rounded-corners.md
---

## Problem

Need reusable helper library for processing raw macOS screenshots into App Store format (2880x1800 with radial gradient background and drop shadow).

## Solution

Created `.github/scripts/lib/macos-screenshot-helper.sh` with:

1. **check_imagemagick()** - Validates ImageMagick 7+ installed
2. **validate_input_image()** - Validates PNG input files
3. **process_single_screenshot()** - Core ImageMagick processing
4. **validate_macos_screenshot()** - Validates App Store requirements

## ImageMagick Command

```bash
magick -size 2880x1800 -depth 8 \
    radial-gradient:"#2A5F6D-#0D1F26" \
    \( "${input_file}" \
        -resize "${max_width}x${max_height}" \
        \( +clone -background black -shadow "50x30+0+15" \) \
        +swap -background none -layers merge +repage \
    \) \
    -gravity center -composite \
    -flatten -alpha off -strip \
    -colorspace sRGB \
    -define png:compression-level=9 \
    "${output_file}"
```

## Critical Flags

| Flag | Purpose |
|------|---------|
| `-resize "WxH"` | Scale to fit (note: no `>` to allow upscaling) |
| `-alpha off` | Required for App Store |
| `-depth 8` | Prevents 16-bit intermediate processing |
| `-flatten` | Removes transparency |
| `\|\| true` after `((count++))` | Prevents errexit on zero increment |

## Scaling Strategy

- Canvas: 2880x1800
- Max dimensions: 65% of canvas = 1872x1170
- Window scaled to fit within bounds, preserving aspect ratio

## Validation Output

- Dimensions: 2880x1800
- Channels: srgb (no alpha)
- File size: ~290KB (well under 10MB limit)
