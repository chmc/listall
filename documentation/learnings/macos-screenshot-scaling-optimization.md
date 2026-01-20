---
title: macOS Screenshot Scaling Optimization
date: 2026-01-02
severity: MEDIUM
category: macos
tags: [imagemagick, scaling, resize, screenshots]
symptoms: [windows appear too small on canvas, small windows not upscaled]
root_cause: ImageMagick resize ">" flag prevents upscaling; 85% scale was too large for actual window sizes
solution: Remove ">" flag from resize command; use 65% scale for better visual balance
files_affected:
  - .github/scripts/lib/macos-screenshot-helper.sh
related:
  - macos-screenshot-helper-implementation.md
  - macos-screenshot-rounded-corners.md
---

## Problem

Processed macOS screenshots had windows that appeared too small on the 2880x1800 canvas.

## Root Causes

1. **The ">" flag bug**: `-resize "WxH>"` prevents upscaling. Small windows (800x652) remained at original size.
2. **Original scale too large**: 85% meant max bounds of 2448x1530, but windows weren't being upscaled to reach it.

## Solution

### 1. Remove the ">" Flag

```bash
# BAD: Windows stay at original 800x652
-resize "${max_width}x${max_height}>"

# GOOD: Windows scale to fit bounds
-resize "${max_width}x${max_height}"
```

### 2. Optimize Scale to 65%

After testing 65%, 70%, 75%, 80%, 85%, 90%, 65% provided best balance:

| Scale | Max Bounds | Window Size | H-Margin | V-Margin |
|-------|-----------|-------------|----------|----------|
| 65% | 1872x1170 | 1435x1169 | 722px | 315px |
| 85% | 2448x1530 | 1877x1530 | 501px | 135px |

65% provides:
- Comfortable breathing room around window
- Visible gradient background creating depth
- Room for drop shadow without clipping

## ImageMagick Resize Flags

| Flag | Behavior |
|------|----------|
| `WxH` | Scale to fit (may enlarge or shrink) |
| `WxH>` | Only shrink to fit (never enlarge) |
| `WxH<` | Only enlarge to fit (never shrink) |
| `WxH!` | Force exact dimensions (ignores aspect ratio) |
| `WxH^` | Fill bounds (may exceed one dimension) |

## Key Learnings

1. **Verify resize actually happens** - ">" flag silently prevents upscaling
2. **Test samples are invaluable** - visual samples at different scales made optimal choice obvious
3. **Don't trust default settings** - empirical testing found 65% better than 85%
4. **Document ImageMagick flags** - subtle differences cause unexpected behavior
