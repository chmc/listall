# macOS Screenshot Helper Library Implementation

**Date:** January 2, 2026
**Phase:** Phase 1 - Core Processing

## Problem

Need to create a reusable helper library for processing raw macOS screenshots into Apple App Store format (2880x1800 with radial gradient background and drop shadow).

## Solution

Created `.github/scripts/lib/macos-screenshot-helper.sh` with:

1. **Constants** for all processing parameters (dimensions, colors, shadow settings)
2. **check_imagemagick()** - Validates ImageMagick 7+ is installed
3. **validate_input_image()** - Validates PNG input files
4. **process_single_screenshot()** - Core ImageMagick processing
5. **validate_macos_screenshot()** - Validates output meets App Store requirements

## Key Technical Details

### ImageMagick Command Structure
```bash
magick -size 2880x1800 -depth 8 \
    radial-gradient:"#2A5F6D-#0D1F26" \
    \( "${input_file}" \
        -resize "${max_width}x${max_height}>" \
        \( +clone -background black \
           -shadow "50x30+0+15" \) \
        +swap \
        -background none \
        -layers merge \
        +repage \
    \) \
    -gravity center \
    -composite \
    -flatten \
    -alpha off \
    -strip \
    -colorspace sRGB \
    -define png:compression-level=9 \
    "${output_file}"
```

### Critical Flags
- `-resize "WxH>"` - The `>` flag prevents upscaling if input is smaller
- `-alpha off` - Ensures no alpha channel in output (required for App Store)
- `-depth 8` - Prevents 16-bit intermediate processing
- `-flatten` - Composites all layers and removes transparency
- `|| true` after arithmetic increments - Prevents errexit on zero increment

### Scaling Strategy
- Canvas: 2880x1800
- Max dimensions: 85% of canvas = 2448x1530
- Window is scaled to fit within bounds while preserving aspect ratio
- Smaller dialogs (like Settings 482x420) remain proportionally smaller

## Test Results

- Shellcheck: No errors
- Manual test: All 4 screenshots processed successfully
- Output verification:
  - Dimensions: 2880x1800
  - Channels: srgb (no alpha)
  - File size: ~290KB (well under 10MB limit)

## Lessons Learned

1. **TDD Structure:** Phase 0 created tests first, Phase 1 implements just enough to pass helper tests
2. **The resize `>` flag:** Critical for preventing upscaling of smaller images
3. **Alpha channel removal:** Use both `-flatten` and `-alpha off` for reliable alpha removal
4. **Arithmetic safety in bash:** Always use `((count++)) || true` with set -e

## Files Created/Modified

- Created: `.github/scripts/lib/macos-screenshot-helper.sh`
- Modified: `documentation/TODO_MACOS.md` (marked Phase 1 complete)
