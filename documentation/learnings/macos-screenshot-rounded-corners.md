# macOS Screenshot Rounded Corners Enhancement

**Date:** January 2, 2026
**Phase:** Phase 1 Enhancement - Core Processing
**Updated:** January 2, 2026 (proportional corner radius)

## Problem

macOS windows have rounded corners, but XCUITest captures them as rectangular images. The corners contain the desktop background pixels instead of transparency. This made the App Store screenshots look unprofessional because the window edges showed visible desktop artifacts in the corners.

### Initial Issue (10px radius)

The first implementation used 10px corner radius based on Apple's documented "10pt" standard. However, pixel analysis revealed:
- Desktop background visible 16-21 pixels into the corners
- The actual macOS window corner curve extends further than 10 pixels
- macOS uses "continuous corners" (squircles), not perfect circular arcs

## Solution

Added rounded corner masking with anti-aliasing to the `process_single_screenshot()` function in `.github/scripts/lib/macos-screenshot-helper.sh`.

### Key Changes

1. **Increased corner radius from 10px to 22px** - Based on pixel analysis showing 16-21px of visible desktop
2. **Added anti-aliasing** - Using `-blur 0x0.5 -level 50%,100%` for smooth edge transitions
3. **Documentation of squircle vs circle difference** - ImageMagick uses circular arcs, macOS uses squircles
4. **Proportional corner radius** - Scale radius based on window width to ensure consistent visual appearance

### Proportional Corner Radius Fix

A subsequent issue: the fixed 22px radius worked for 800px-wide windows but over-cropped smaller windows like Settings (482px).

**The problem:**
| Window | Width | Fixed 22px Radius | After Upscaling |
|--------|-------|-------------------|-----------------|
| Main | 800px | 22px | ~51px (6.4% of width) |
| Settings | 482px | 22px | ~86px (17.8% of width) |

The Settings window appeared heavily cropped because the same radius, when applied before scaling, resulted in proportionally larger corners after upscaling.

**The solution:** Scale corner radius based on window width:

```bash
# Constants
readonly MACOS_CORNER_RADIUS_BASE=22       # Radius for 800px-wide window
readonly MACOS_CORNER_RADIUS_REF_WIDTH=800 # Reference width
readonly MACOS_CORNER_RADIUS_MIN=8         # Minimum radius

# Calculate proportional radius
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

**Result after fix:**
| Window | Width | Calculated Radius | After Upscaling |
|--------|-------|-------------------|-----------------|
| Main | 800px | 22px | ~51px |
| Settings | 482px | 13px | ~51px |

Both windows now have consistent visual corner appearance after processing

## Key Technical Details

### macOS Window Corner Radius

**Effective Masking Radius:**
- **Recommended value:** 22 pixels
- **Why not 10pt:** The documented 10pt is for the inner content radius. The actual window chrome corner extends further due to:
  - Window shadow integration
  - Title bar styling
  - The "squircle" (superellipse) curve used by macOS vs ImageMagick's circular arc

**Squircle vs Circle:**
- macOS uses "continuous corner curves" (superellipse/squircle)
- ImageMagick's `roundrectangle` uses circular arcs
- Circular arcs are "tighter" than squircles at the same nominal radius
- Using a larger radius (22px) compensates for this geometric difference

### Anti-Aliasing Technique

```bash
-blur 0x0.5 -level 50%,100%
```

This creates a subtle feathered edge:
- `-blur 0x0.5` - Applies 0.5px Gaussian blur to soften the mask edge
- `-level 50%,100%` - Remaps the gray values, keeping the soft transition but sharpening the overall boundary

Result: ~1px soft edge that blends smoothly with the background gradient.

### ImageMagick Two-Step Processing

A critical discovery: nested composition with `-compose DstIn` inside parentheses causes colorspace issues in ImageMagick when combined with gradient creation. The image converts to grayscale.

**Broken single-command approach:**
```bash
# This produces grayscale output!
magick -size 2880x1800 radial-gradient:... \
    \( input.png \
        \( -size WxH xc:none -fill white -draw "roundrectangle..." \) \
        -compose DstIn -composite \
        ...
    \) -composite output.png
```

**Working two-step approach:**
```bash
# Step 1: Apply rounded corners with anti-aliasing to temp file
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

### Rounded Rectangle Syntax

```bash
-draw "roundrectangle x1,y1,x2,y2,rx,ry"
```

Where:
- `x1,y1` = top-left corner (0,0)
- `x2,y2` = bottom-right corner (width-1, height-1)
- `rx,ry` = corner radius in both directions

Example for 800x652 image with 22px radius:
```bash
-draw "roundrectangle 0,0,799,651,22,22"
```

### Composition Method

- Use `-alpha set` before compositing to ensure alpha channel exists
- Use `-compose DstIn` to keep only the parts of the image where the mask is opaque
- White areas of mask = keep the image
- Transparent areas of mask = make image transparent

## Code Changes

Updated in `macos-screenshot-helper.sh`:

1. **Updated constant:**
```bash
readonly MACOS_CORNER_RADIUS=22  # macOS window corner radius (measured: 16-21px visible desktop)
```

2. **Updated `process_single_screenshot()`:**
   - Get input dimensions for mask creation
   - Create temp file for intermediate rounded corners image
   - Step 1: Apply rounded corner mask with anti-aliasing
   - Step 2: Create final output with scaled window, shadow, and gradient
   - Clean up temp file

## Test Results

- Shellcheck: No errors
- All 15 unit tests: PASS
- Batch processing: Screenshots processed successfully
- Visual verification: Desktop background no longer visible in corners

## Lessons Learned

1. **Pixel analysis is essential:** Don't trust documentation alone. The actual visible pixels tell the true story.

2. **Squircle vs circle matters:** macOS continuous corners are mathematically different from circular arcs. Use a larger radius to compensate.

3. **Anti-aliasing improves quality:** A subtle blur+level technique creates professional-looking soft edges without noticeable blurriness.

4. **ImageMagick composition order matters:** Nested compositions with DstIn can cause unexpected colorspace issues. When in doubt, use temp files.

5. **Two-step is more reliable:** While single-command ImageMagick operations are elegant, they can have subtle bugs. Temp files add minimal overhead but greatly improve reliability.

6. **Test visually at actual size:** Corner masking issues may not be visible in thumbnails. Always verify at 100% zoom.

7. **Consider scaling effects:** When applying effects before scaling, the effect magnitude changes with the scale factor. Smaller images scaled up more will have proportionally larger effects. Either apply effects after scaling, or scale the effect parameters inversely.

8. **Test with varied inputs:** A parameter tuned for one input size may not work for all sizes. Test with the smallest and largest expected inputs.

## Files Modified

- `.github/scripts/lib/macos-screenshot-helper.sh` - Updated corner radius to 22px, added anti-aliasing
- `fastlane/screenshots/mac/processed/*/` - Regenerate all screenshots with improved rounded corners
