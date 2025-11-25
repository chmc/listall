#!/bin/bash
set -euo pipefail

# Compare screenshots between two CI runs to detect visual regressions
# Usage: compare-screenshots.sh <run-id-1> <run-id-2> [--threshold N]
#
# Exit codes:
#   0 - Comparison completed successfully (check report for differences)
#   1 - Invalid arguments or missing dependencies
#   2 - Failed to download artifacts
#   3 - Comparison failed

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

RUN_ID_1="${1:-}"
RUN_ID_2="${2:-}"
THRESHOLD="${3:-5}"  # Default 5% difference threshold

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Validate arguments
if [ -z "$RUN_ID_1" ] || [ -z "$RUN_ID_2" ]; then
    print_error "Two run IDs required"
    echo "Usage: $0 <run-id-1> <run-id-2> [--threshold N]" >&2
    echo "" >&2
    echo "Example:" >&2
    echo "  $0 19660858956 19667213668" >&2
    echo "  $0 19660858956 19667213668 --threshold 10  # Allow 10% difference" >&2
    exit 1
fi

# Parse threshold option
if [ "$THRESHOLD" == "--threshold" ]; then
    THRESHOLD="${4:-5}"
fi

# Check dependencies
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) not installed"
    echo "Install: brew install gh" >&2
    exit 1
fi

if ! command -v magick &> /dev/null && ! command -v convert &> /dev/null; then
    print_error "ImageMagick not installed"
    echo "Install: brew install imagemagick" >&2
    exit 1
fi

print_header "📸 Screenshot Comparison Tool"

print_info "Comparing runs:"
print_info "  Run 1 (baseline): $RUN_ID_1"
print_info "  Run 2 (current):  $RUN_ID_2"
print_info "  Threshold:        ${THRESHOLD}% difference"

# Create temporary directories
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

RUN1_DIR="$TEMP_DIR/run1"
RUN2_DIR="$TEMP_DIR/run2"
DIFF_DIR="$TEMP_DIR/diff"
REPORT_FILE="$TEMP_DIR/comparison-report.md"

mkdir -p "$RUN1_DIR" "$RUN2_DIR" "$DIFF_DIR"

# Download artifacts
print_header "1️⃣ Downloading Screenshots"

download_screenshots() {
    local run_id=$1
    local output_dir=$2

    print_info "Downloading artifacts from run $run_id..."

    # Download all screenshot artifacts
    for artifact in "screenshots-iphone" "screenshots-ipad" "screenshots-watch"; do
        print_info "  Downloading $artifact..."

        # Check if artifact exists
        if ! gh run view "$run_id" --json artifacts --jq ".artifacts[] | select(.name == \"$artifact\") | .name" &>/dev/null; then
            print_warning "$artifact not found in run $run_id"
            continue
        fi

        # Download and extract
        if gh run download "$run_id" --name "$artifact" --dir "$output_dir/$artifact" 2>/dev/null; then
            ARTIFACT_COUNT=$(find "$output_dir/$artifact" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
            print_success "$artifact: $ARTIFACT_COUNT screenshots"
        else
            print_warning "Failed to download $artifact"
        fi
    done
}

download_screenshots "$RUN_ID_1" "$RUN1_DIR"
download_screenshots "$RUN_ID_2" "$RUN2_DIR"

# Count screenshots
RUN1_COUNT=$(find "$RUN1_DIR" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
RUN2_COUNT=$(find "$RUN2_DIR" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')

if [ "$RUN1_COUNT" -eq 0 ] || [ "$RUN2_COUNT" -eq 0 ]; then
    print_error "No screenshots found in one or both runs"
    exit 2
fi

print_info "Total screenshots: Run1=$RUN1_COUNT, Run2=$RUN2_COUNT"

# Compare screenshots
print_header "2️⃣ Comparing Screenshots"

# Initialize report
cat > "$REPORT_FILE" <<EOF
# Screenshot Comparison Report

**Baseline Run:** $RUN_ID_1
**Current Run:** $RUN_ID_2
**Threshold:** ${THRESHOLD}%
**Generated:** $(date '+%Y-%m-%d %H:%M:%S')

---

## Summary

EOF

IDENTICAL=0
SIMILAR=0
DIFFERENT=0
MISSING=0
NEW=0

# Compare each screenshot
while IFS= read -r screenshot1; do
    if [ -z "$screenshot1" ]; then
        continue
    fi

    BASENAME=$(basename "$screenshot1")

    # Find corresponding screenshot in run2
    SCREENSHOT2=$(find "$RUN2_DIR" -name "$BASENAME" -type f | head -1)

    if [ -z "$SCREENSHOT2" ] || [ ! -f "$SCREENSHOT2" ]; then
        print_warning "Missing in run 2: $BASENAME"
        MISSING=$((MISSING + 1))
        echo "- ❌ **Missing in current:** \`$BASENAME\`" >> "$REPORT_FILE"
        continue
    fi

    # Compare using ImageMagick
    # Calculate structural similarity metric
    COMPARE_RESULT=$(magick compare -metric RMSE "$screenshot1" "$SCREENSHOT2" null: 2>&1 || true)

    # Extract the difference percentage
    # Output format: "XXXX (0.YYYY)" where YYYY is the normalized error
    if echo "$COMPARE_RESULT" | grep -qE '[0-9]+\.[0-9]+'; then
        # Extract normalized error (0.0 to 1.0)
        NORMALIZED_ERROR=$(echo "$COMPARE_RESULT" | grep -oE '\([0-9]+\.[0-9]+\)' | tr -d '()' || echo "0.0")
        DIFF_PERCENT=$(awk "BEGIN {print $NORMALIZED_ERROR * 100}")

        # Categorize difference
        if awk -v d="$DIFF_PERCENT" 'BEGIN {exit !(d < 0.01)}'; then
            # Less than 0.01% - identical
            IDENTICAL=$((IDENTICAL + 1))
            print_success "Identical: $BASENAME"
        elif awk -v d="$DIFF_PERCENT" -v t="$THRESHOLD" 'BEGIN {exit !(d < t)}'; then
            # Below threshold - similar
            SIMILAR=$((SIMILAR + 1))
            print_info "Similar (${DIFF_PERCENT}%): $BASENAME"
            echo "- ✅ **Similar** (${DIFF_PERCENT}%): \`$BASENAME\`" >> "$REPORT_FILE"
        else
            # Above threshold - different
            DIFFERENT=$((DIFFERENT + 1))
            print_warning "Different (${DIFF_PERCENT}%): $BASENAME"

            # Generate diff image
            DIFF_IMAGE="$DIFF_DIR/${BASENAME%.png}-diff.png"
            if magick compare "$screenshot1" "$SCREENSHOT2" -compose src "$DIFF_IMAGE" 2>/dev/null; then
                echo "- ⚠️  **Different** (${DIFF_PERCENT}%): \`$BASENAME\` - [diff image]($DIFF_IMAGE)" >> "$REPORT_FILE"
            else
                echo "- ⚠️  **Different** (${DIFF_PERCENT}%): \`$BASENAME\`" >> "$REPORT_FILE"
            fi
        fi
    else
        print_warning "Could not compare: $BASENAME"
        echo "- ❓ **Comparison failed:** \`$BASENAME\`" >> "$REPORT_FILE"
    fi

done < <(find "$RUN1_DIR" -name "*.png" -type f)

# Check for new screenshots in run2
while IFS= read -r screenshot2; do
    if [ -z "$screenshot2" ]; then
        continue
    fi

    BASENAME=$(basename "$screenshot2")
    SCREENSHOT1=$(find "$RUN1_DIR" -name "$BASENAME" -type f | head -1)

    if [ -z "$SCREENSHOT1" ] || [ ! -f "$SCREENSHOT1" ]; then
        print_info "New in run 2: $BASENAME"
        NEW=$((NEW + 1))
        echo "- ➕ **New in current:** \`$BASENAME\`" >> "$REPORT_FILE"
    fi
done < <(find "$RUN2_DIR" -name "*.png" -type f)

# Finalize report
print_header "3️⃣ Results Summary"

cat >> "$REPORT_FILE" <<EOF

---

## Statistics

| Category | Count |
|----------|-------|
| ✅ Identical | $IDENTICAL |
| 🟢 Similar (< ${THRESHOLD}%) | $SIMILAR |
| ⚠️  Different (≥ ${THRESHOLD}%) | $DIFFERENT |
| ❌ Missing in current | $MISSING |
| ➕ New in current | $NEW |
| **Total compared** | $((IDENTICAL + SIMILAR + DIFFERENT)) |

---

## Recommendation

EOF

TOTAL_COMPARED=$((IDENTICAL + SIMILAR + DIFFERENT))
ACCEPTABLE=$((IDENTICAL + SIMILAR))

if [ "$TOTAL_COMPARED" -eq 0 ]; then
    echo "❌ **No screenshots could be compared.** Check artifact availability." >> "$REPORT_FILE"
    print_error "No screenshots could be compared"
elif [ "$DIFFERENT" -eq 0 ] && [ "$MISSING" -eq 0 ]; then
    echo "✅ **All screenshots match!** No visual regressions detected." >> "$REPORT_FILE"
    print_success "All screenshots match!"
elif [ "$DIFFERENT" -gt 0 ]; then
    DIFF_RATIO=$(awk "BEGIN {print ($DIFFERENT * 100) / $TOTAL_COMPARED}")
    echo "⚠️  **Visual differences detected** in $DIFFERENT screenshot(s) (${DIFF_RATIO}%)." >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Review the screenshots above to determine if changes are:" >> "$REPORT_FILE"
    echo "- Expected (intentional UI changes)" >> "$REPORT_FILE"
    echo "- Regression (unintended visual bugs)" >> "$REPORT_FILE"
    print_warning "Visual differences detected in $DIFFERENT screenshot(s)"
fi

# Output summary
echo ""
echo -e "${GREEN}✅ Identical:${NC}    $IDENTICAL"
echo -e "${BLUE}🟢 Similar:${NC}      $SIMILAR"
echo -e "${YELLOW}⚠️  Different:${NC}   $DIFFERENT"
echo -e "${RED}❌ Missing:${NC}      $MISSING"
echo -e "${BLUE}➕ New:${NC}          $NEW"
echo ""

# Save report to current directory
OUTPUT_REPORT="screenshot-comparison-${RUN_ID_1}-vs-${RUN_ID_2}.md"
cp "$REPORT_FILE" "$OUTPUT_REPORT"
print_success "Report saved to: $OUTPUT_REPORT"

if [ "$DIFFERENT" -gt 0 ]; then
    DIFF_COUNT=$(find "$DIFF_DIR" -name "*.png" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$DIFF_COUNT" -gt 0 ]; then
        DIFF_OUTPUT_DIR="screenshot-diffs-${RUN_ID_1}-vs-${RUN_ID_2}"
        mkdir -p "$DIFF_OUTPUT_DIR"
        cp "$DIFF_DIR"/*.png "$DIFF_OUTPUT_DIR/" 2>/dev/null || true
        print_success "Diff images saved to: $DIFF_OUTPUT_DIR/"
    fi
fi

print_header "🎯 Next Steps"

if [ "$DIFFERENT" -gt 0 ] || [ "$MISSING" -gt 0 ]; then
    print_info "Review the differences and determine:"
    echo "  1. Are changes intentional (UI updates)?"
    echo "  2. Are changes regressions (bugs)?"
    echo "  3. Should threshold be adjusted?"
    echo ""
    print_info "View runs in browser:"
    echo "  gh run view $RUN_ID_1 --web"
    echo "  gh run view $RUN_ID_2 --web"
else
    print_success "No action needed - screenshots match!"
fi

exit 0
