---
title: macOS Screenshot Rounded Corners Enhancement
date: 2026-01-02
severity: MEDIUM
category: macos
tags: [imagemagick, rounded-corners, squircle, anti-aliasing, screenshots]
symptoms: [desktop background visible in corners, rectangular window edges, unprofessional appearance]
root_cause: XCUITest captures windows as rectangular; macOS squircle corners extend further than documented 10pt
solution: Apply 22px proportional corner radius with anti-aliasing using two-step ImageMagick processing
files_affected:
  - .github/scripts/lib/macos-screenshot-helper.sh
related:
  - macos-screenshot-helper-implementation.md
  - macos-screenshot-scaling-optimization.md
---

## Problem

macOS windows have rounded corners, but XCUITest captures them as rectangular images with desktop background visible in corners (16-21 pixels).

## Solution

### Proportional Corner Radius

Fixed radius caused over-cropping on smaller windows:

| Window | Width | Fixed 22px | After Upscaling |
|--------|-------|-----------|-----------------|
| Main | 800px | 22px | ~51px (6.4% of width) |
| Settings | 482px | 22px | ~86px (17.8% of width) |

**Solution:** Scale radius based on window width:

```bash
readonly MACOS_CORNER_RADIUS_BASE=22
readonly MACOS_CORNER_RADIUS_REF_WIDTH=800
readonly MACOS_CORNER_RADIUS_MIN=8

calculate_corner_radius() {
    local input_width="$1"
    local radius
    radius=$((MACOS_CORNER_RADIUS_BASE * input_width / MACOS_CORNER_RADIUS_REF_WIDTH))
    if [[ "${radius}" -lt "${MACOS_CORNER_RADIUS_MIN}" ]]; then
        radius="${MACOS_CORNER_RADIUS_MIN}"
    fi
    echo "${radius}"
}
```

### Anti-Aliasing Technique

```bash
-blur 0x0.5 -level 50%,100%
```

Creates ~1px soft edge that blends smoothly with gradient background.

### Two-Step Processing (Required)

Single-command with `-compose DstIn` inside parentheses causes grayscale output:

```bash
# Step 1: Apply rounded corners to temp file
magick input.png \
    \( -size WxH xc:none -fill white \
       -draw "roundrectangle 0,0,W-1,H-1,22,22" \
       -blur 0x0.5 -level 50%,100% \
    \) -alpha set -compose DstIn -composite \
    temp_rounded.png

# Step 2: Composite onto gradient
magick -size 2880x1800 radial-gradient:... \
    \( temp_rounded.png -resize ... \) \
    -composite output.png
```

## Squircle vs Circle

- macOS uses "continuous corner curves" (superellipse/squircle)
- ImageMagick's `roundrectangle` uses circular arcs
- Circular arcs are "tighter" - need larger radius (22px) to compensate

## Key Learnings

1. **Pixel analysis essential** - actual visible pixels tell true story
2. **Squircle vs circle matters** - use larger radius to compensate
3. **Two-step is more reliable** - nested compositions cause colorspace issues
4. **Consider scaling effects** - effects applied before scaling change magnitude
5. **Test with varied inputs** - parameters tuned for one size may not work for all
