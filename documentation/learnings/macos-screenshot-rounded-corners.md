# macOS Screenshot Rounded Corners Enhancement

**Date:** January 2, 2026
**Phase:** Phase 1 Enhancement - Core Processing

## Problem

macOS windows have rounded corners (10pt radius on Big Sur and later), but XCUITest captures them as rectangular images. The corners contain solid pixels instead of transparency. This made the App Store screenshots look unprofessional because the window edges appeared as sharp rectangles rather than the natural rounded macOS window style.

## Solution

Added rounded corner masking to the `process_single_screenshot()` function in `.github/scripts/lib/macos-screenshot-helper.sh`. The function now applies a rounded rectangle mask to the window before compositing onto the gradient background.

## Key Technical Details

### macOS Window Corner Radius

- **Standard macOS windows (Big Sur - Sequoia):** 10 points
- **For standard resolution (1x):** 10 pixels
- This value is consistent across macOS Big Sur (11.0) through macOS Sequoia (15.x)
- Note: macOS Tahoe (26) may use 26pt corners in the future

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
# Step 1: Apply rounded corners to temp file
magick input.png \
    \( -size WxH xc:none -fill white -draw "roundrectangle..." \) \
    -alpha set -compose DstIn -composite \
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

Example for 800x652 image with 10px radius:
```bash
-draw "roundrectangle 0,0,799,651,10,10"
```

### Composition Method

- Use `-alpha set` before compositing to ensure alpha channel exists
- Use `-compose DstIn` to keep only the parts of the image where the mask is opaque
- White areas of mask = keep the image
- Transparent areas of mask = make image transparent

## Code Changes

Added to `macos-screenshot-helper.sh`:

1. **New constant:**
```bash
readonly MACOS_CORNER_RADIUS=10  # macOS window corner radius in pixels
```

2. **Updated `process_single_screenshot()`:**
   - Get input dimensions for mask creation
   - Create temp file for intermediate rounded corners image
   - Step 1: Apply rounded corner mask
   - Step 2: Create final output with scaled window, shadow, and gradient
   - Clean up temp file

## Test Results

- Shellcheck: No errors
- All 15 unit tests: PASS
- Batch processing: 8/8 screenshots processed successfully
- Visual verification: Rounded corners visible on all windows

## Lessons Learned

1. **ImageMagick composition order matters:** Nested compositions with DstIn can cause unexpected colorspace issues. When in doubt, use temp files.

2. **Zero-based coordinates:** The `roundrectangle` command uses width-1 and height-1 for the bottom-right corner.

3. **Two-step is more reliable:** While single-command ImageMagick operations are elegant, they can have subtle bugs. Temp files add minimal overhead but greatly improve reliability.

4. **macOS corner radius is consistent:** 10pt has been the standard from Big Sur through Sequoia. This is a safe value for screenshot processing.

## Files Modified

- `.github/scripts/lib/macos-screenshot-helper.sh` - Added rounded corner processing
- `fastlane/screenshots/mac/processed/*/` - Regenerated all screenshots with rounded corners
