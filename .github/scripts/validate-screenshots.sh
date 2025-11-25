#!/bin/bash
set -euo pipefail

# Validate screenshot dimensions match App Store requirements
# Usage: validate-screenshots.sh <directory> <device_type>
# device_type: iphone | ipad | watch

SCREENSHOT_DIR="${1:-}"
DEVICE_TYPE="${2:-}"

if [ -z "$SCREENSHOT_DIR" ] || [ -z "$DEVICE_TYPE" ]; then
    echo "❌ Error: Directory and device type required" >&2
    echo "Usage: $0 <directory> <iphone|ipad|watch>" >&2
    exit 1
fi

if [ ! -d "$SCREENSHOT_DIR" ]; then
    echo "❌ Error: Directory not found: $SCREENSHOT_DIR" >&2
    exit 2
fi

echo "🔍 Validating $DEVICE_TYPE screenshots in: $SCREENSHOT_DIR" >&2

# Define expected dimensions based on device type
case "$DEVICE_TYPE" in
    iphone)
        EXPECTED_WIDTH=1290
        EXPECTED_HEIGHT=2796
        DEVICE_NAME="iPhone 16 Pro Max"
        ;;
    ipad)
        EXPECTED_WIDTH=2064
        EXPECTED_HEIGHT=2752
        DEVICE_NAME="iPad Pro 13-inch"
        ;;
    watch)
        EXPECTED_WIDTH=396
        EXPECTED_HEIGHT=484
        DEVICE_NAME="Apple Watch Series 10"
        ;;
    *)
        echo "❌ Error: Unknown device type: $DEVICE_TYPE" >&2
        echo "Valid types: iphone, ipad, watch" >&2
        exit 3
        ;;
esac

# Check ImageMagick is available
if ! command -v identify &> /dev/null; then
    echo "❌ Error: ImageMagick 'identify' command not found" >&2
    echo "Install with: brew install imagemagick" >&2
    exit 4
fi

# Find all PNG files
SCREENSHOTS=$(find "$SCREENSHOT_DIR" -name "*.png" -type f)
SCREENSHOT_COUNT=$(echo "$SCREENSHOTS" | grep -c . || echo "0")

if [ "$SCREENSHOT_COUNT" -eq 0 ]; then
    echo "❌ Error: No PNG screenshots found in $SCREENSHOT_DIR" >&2
    exit 5
fi

echo "Found $SCREENSHOT_COUNT screenshot(s) to validate" >&2

# Validate each screenshot
ERRORS=0
WARNINGS=0

while IFS= read -r screenshot; do
    if [ -z "$screenshot" ]; then
        continue
    fi

    # Get dimensions
    if ! DIMENSIONS=$(identify -format '%wx%h' "$screenshot" 2>&1); then
        echo "❌ Failed to read: $(basename "$screenshot")" >&2
        echo "   Error: $DIMENSIONS" >&2
        ERRORS=$((ERRORS + 1))
        continue
    fi

    WIDTH=$(echo "$DIMENSIONS" | cut -d'x' -f1)
    HEIGHT=$(echo "$DIMENSIONS" | cut -d'x' -f2)

    # Check dimensions match expected
    if [ "$WIDTH" -ne "$EXPECTED_WIDTH" ] || [ "$HEIGHT" -ne "$EXPECTED_HEIGHT" ]; then
        echo "❌ Wrong dimensions: $(basename "$screenshot")" >&2
        echo "   Expected: ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT} ($DEVICE_NAME)" >&2
        echo "   Actual: ${WIDTH}x${HEIGHT}" >&2
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Check file size (should be > 10KB for real screenshots)
    FILE_SIZE=$(stat -f%z "$screenshot" 2>/dev/null || stat -c%s "$screenshot" 2>/dev/null || echo "0")
    FILE_SIZE_KB=$((FILE_SIZE / 1024))

    if [ "$FILE_SIZE_KB" -lt 10 ]; then
        echo "⚠️  Suspiciously small: $(basename "$screenshot") (${FILE_SIZE_KB}KB)" >&2
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check brightness to detect blank screenshots (0.0 = black, 1.0 = white)
    AVG_BRIGHTNESS=$(convert "$screenshot" -colorspace Gray -format "%[fx:mean]" info: 2>/dev/null || echo "")
    if [ -z "$AVG_BRIGHTNESS" ]; then
        echo "⚠️  Cannot check brightness: $(basename "$screenshot")" >&2
        WARNINGS=$((WARNINGS + 1))
    elif awk -v b="$AVG_BRIGHTNESS" 'BEGIN {exit !(b < 0.05)}'; then
        # Nearly black (< 5% brightness)
        echo "⚠️  Possibly blank (black): $(basename "$screenshot") (brightness: $AVG_BRIGHTNESS)" >&2
        WARNINGS=$((WARNINGS + 1))
    elif awk -v b="$AVG_BRIGHTNESS" 'BEGIN {exit !(b > 0.95)}'; then
        # Nearly white (> 95% brightness)
        echo "⚠️  Possibly blank (white): $(basename "$screenshot") (brightness: $AVG_BRIGHTNESS)" >&2
        WARNINGS=$((WARNINGS + 1))
    fi

    # Check it's a valid PNG with correct format
    FILE_FORMAT=$(identify -format '%m' "$screenshot" 2>&1)
    if [ "$FILE_FORMAT" != "PNG" ]; then
        echo "❌ Not a PNG file: $(basename "$screenshot") (format: $FILE_FORMAT)" >&2
        ERRORS=$((ERRORS + 1))
        continue
    fi

done <<< "$SCREENSHOTS"

# Summary
echo "" >&2
if [ $ERRORS -gt 0 ]; then
    echo "❌ Validation failed: $ERRORS error(s), $WARNINGS warning(s)" >&2
    echo "   $SCREENSHOT_COUNT screenshot(s) checked" >&2
    exit 6
elif [ $WARNINGS -gt 0 ]; then
    echo "⚠️  Validation passed with warnings: $WARNINGS warning(s)" >&2
    echo "   $SCREENSHOT_COUNT screenshot(s) validated" >&2
    exit 0
else
    echo "✅ All screenshots valid: $SCREENSHOT_COUNT screenshot(s) at ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}" >&2
    exit 0
fi
