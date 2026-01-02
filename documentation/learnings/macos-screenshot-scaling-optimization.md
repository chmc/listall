# macOS Screenshot Scaling Optimization

**Date:** January 2, 2026
**Phase:** Phase 1 Enhancement - Scaling Fix

## Problem

The processed macOS screenshots had windows that appeared too small on the 2880x1800 canvas. Investigation revealed two issues:

1. **The ">" flag bug**: The resize command used `-resize "WxH>"` which prevents upscaling. Small windows (800x652) remained at their original size instead of scaling up.

2. **Original scale too large**: The 85% scale setting meant max bounds of 2448x1530, but since windows weren't being upscaled, this was never reached.

## Solution

### 1. Remove the ">" Flag

The ">" flag in ImageMagick resize means "only shrink, never enlarge":

```bash
# Before (buggy - windows stay at original 800x652)
-resize "${max_width}x${max_height}>"

# After (correct - windows scale to fit bounds)
-resize "${max_width}x${max_height}"
```

### 2. Optimize Scale to 65%

After creating test samples at various percentages (65%, 70%, 75%, 80%, 85%, 90%), 65% provided the best balance:

| Scale | Max Bounds | Window Size | Horizontal Margin | Vertical Margin |
|-------|-----------|-------------|-------------------|-----------------|
| 65%   | 1872x1170 | 1435x1169   | 722px             | 315px           |
| 70%   | 2016x1260 | 1547x1260   | 666px             | 270px           |
| 75%   | 2160x1350 | 1657x1350   | 611px             | 225px           |
| 80%   | 2304x1440 | 1767x1440   | 556px             | 180px           |
| 85%   | 2448x1530 | 1877x1530   | 501px             | 135px           |

65% provides:
- Comfortable breathing room around the window
- Visible gradient background creating depth
- Professional App Store appearance
- Room for the drop shadow without clipping

## Key Technical Details

### ImageMagick Resize Flags

```bash
-resize "WxH"    # Scale to fit within bounds (may enlarge or shrink)
-resize "WxH>"   # Only shrink to fit (never enlarge)
-resize "WxH<"   # Only enlarge to fit (never shrink)
-resize "WxH!"   # Force exact dimensions (ignores aspect ratio)
-resize "WxH^"   # Fill bounds (may exceed one dimension)
```

### Scale Calculation

```bash
max_width=$((MACOS_CANVAS_WIDTH * MACOS_SCALE_PERCENT / 100))   # 2880 * 65 / 100 = 1872
max_height=$((MACOS_CANVAS_HEIGHT * MACOS_SCALE_PERCENT / 100)) # 1800 * 65 / 100 = 1170
```

## Test Results

- Shellcheck: No errors
- All 15 unit tests: PASS
- Batch processing: All 8 screenshots processed successfully
- Visual verification: Windows now properly scaled with good margins

## Lessons Learned

1. **Verify resize actually happens**: The ">" flag silently prevents upscaling. Always check actual output dimensions match expectations.

2. **Test samples are invaluable**: Creating visual samples at different scales made the optimal choice obvious.

3. **Don't trust default settings**: The 85% was a reasonable default, but empirical testing found 65% better for actual window sizes.

4. **Document ImageMagick flags**: The subtle differences between resize flags can cause unexpected behavior.

## Files Modified

- `.github/scripts/lib/macos-screenshot-helper.sh` - Changed MACOS_SCALE_PERCENT to 65, removed ">" from resize
