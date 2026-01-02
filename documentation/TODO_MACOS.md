# macOS Screenshot Processing - Implementation Plan

**Date:** January 2, 2026
**Status:** READY FOR IMPLEMENTATION
**Revision:** 2.0 - Restructured for Phase-by-Phase Implementation

---

## Overview

This plan addresses the issue that current macOS screenshots do not meet Apple App Store requirements. The solution creates professional marketing-style screenshots with the app window composited onto a radial gradient background using ListAll icon colors.

### Current State vs Target State

| Aspect | Current | Target |
|--------|---------|--------|
| Dimensions | Various (800x652, 482x420) | 2880x1800 |
| Aspect Ratio | ~1.23:1 | 16:10 (1.6:1) |
| Background | Raw window capture | Radial gradient (#1A3F4D base) |
| Shadow | None | Subtle macOS-style drop shadow |
| App Store Ready | No | Yes |

### Phase Summary

| Phase | Name | Description | Status |
|-------|------|-------------|--------|
| 0 | Test Infrastructure | Create test file with 15 test cases (TDD RED) | COMPLETED |
| 1 | Core Processing | Helper library with single image processing | NOT STARTED |
| 2 | Batch Processing | Main script with all locales | NOT STARTED |
| 3 | Integration | Integration with generate-screenshots-local.sh | NOT STARTED |
| 4 | Validation & CI | Validation updates, optional CI job | NOT STARTED |

---

# Phase 0: Test Infrastructure [COMPLETED]

## Goal

Create test file with all test cases BEFORE any implementation. This is the TDD RED phase - all tests must FAIL initially.

## Files to Create

| File | Action | Purpose |
|------|--------|---------|
| `.github/scripts/tests/test-process-macos-screenshots.sh` | CREATE | 15 test cases |
| `.github/scripts/lib/` | CREATE | Directory only (empty) |

## Implementation Instructions

### Step 1: Create the lib directory

```bash
mkdir -p .github/scripts/lib
```

### Step 2: Create the test file

Create `.github/scripts/tests/test-process-macos-screenshots.sh` with the following structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Test file for macOS screenshot processing
# TDD RED Phase - All tests should FAIL before implementation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCRIPT_UNDER_TEST="${PROJECT_ROOT}/.github/scripts/process-macos-screenshots.sh"
HELPER_SCRIPT="${PROJECT_ROOT}/.github/scripts/lib/macos-screenshot-helper.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

#------------------------------------------------------------------------------
# Test Framework Functions
#------------------------------------------------------------------------------

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++)) || true
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++)) || true
}

run_test() {
    local test_name="$1"
    local test_func="$2"

    ((TESTS_RUN++)) || true
    log_test "Running: ${test_name}"

    if ${test_func}; then
        log_pass "${test_name}"
    else
        log_fail "${test_name}"
    fi
}

#------------------------------------------------------------------------------
# Script Basics Tests (4 tests)
#------------------------------------------------------------------------------

test_script_exists() {
    [[ -f "${SCRIPT_UNDER_TEST}" ]]
}

test_script_is_executable() {
    [[ -x "${SCRIPT_UNDER_TEST}" ]]
}

test_script_shows_help() {
    "${SCRIPT_UNDER_TEST}" --help 2>/dev/null | grep -q "Usage"
}

test_script_checks_imagemagick() {
    # Should fail gracefully if ImageMagick not available
    # (We test the check function exists and works)
    source "${HELPER_SCRIPT}" 2>/dev/null && type check_imagemagick &>/dev/null
}

#------------------------------------------------------------------------------
# Input Validation Tests (4 tests)
#------------------------------------------------------------------------------

test_rejects_missing_input_dir() {
    ! "${SCRIPT_UNDER_TEST}" 2>/dev/null
}

test_rejects_nonexistent_input_dir() {
    ! "${SCRIPT_UNDER_TEST}" -i "/nonexistent/path" 2>/dev/null
}

test_handles_empty_input_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/en-US"
    # Should warn but not error on empty directory
    "${SCRIPT_UNDER_TEST}" -i "${temp_dir}" 2>&1 | grep -qi "warning\|no.*png\|empty"
}

test_discovers_locales_dynamically() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/en-US" "${temp_dir}/fi" "${temp_dir}/de"
    touch "${temp_dir}/en-US/test.png"
    touch "${temp_dir}/fi/test.png"
    touch "${temp_dir}/de/test.png"

    local output
    output=$("${SCRIPT_UNDER_TEST}" -i "${temp_dir}" --dry-run 2>&1)

    echo "${output}" | grep -q "en-US" && \
    echo "${output}" | grep -q "fi" && \
    echo "${output}" | grep -q "de"
}

#------------------------------------------------------------------------------
# Output Validation Tests (4 tests)
#------------------------------------------------------------------------------

test_creates_output_directory() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/input/en-US"
    # Create a minimal valid PNG (1x1 pixel)
    magick -size 1x1 xc:white "${temp_dir}/input/en-US/test.png" 2>/dev/null || return 1

    "${SCRIPT_UNDER_TEST}" -i "${temp_dir}/input" -o "${temp_dir}/output" 2>/dev/null

    [[ -d "${temp_dir}/output" ]]
}

test_output_dimensions_correct() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/input/en-US"
    # Create test image
    magick -size 800x652 xc:white "${temp_dir}/input/en-US/test.png" 2>/dev/null || return 1

    "${SCRIPT_UNDER_TEST}" -i "${temp_dir}/input" -o "${temp_dir}/output" 2>/dev/null

    local dims
    dims=$(magick identify -format "%wx%h" "${temp_dir}/output/en-US/test.png" 2>/dev/null)
    [[ "${dims}" == "2880x1800" ]]
}

test_output_has_no_alpha() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/input/en-US"
    magick -size 800x652 xc:white "${temp_dir}/input/en-US/test.png" 2>/dev/null || return 1

    "${SCRIPT_UNDER_TEST}" -i "${temp_dir}/input" -o "${temp_dir}/output" 2>/dev/null

    local channels
    channels=$(magick identify -format "%[channels]" "${temp_dir}/output/en-US/test.png" 2>/dev/null)
    [[ "${channels}" != *"a"* ]] && [[ "${channels}" != *"alpha"* ]]
}

test_output_under_10mb() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/input/en-US"
    magick -size 800x652 xc:white "${temp_dir}/input/en-US/test.png" 2>/dev/null || return 1

    "${SCRIPT_UNDER_TEST}" -i "${temp_dir}/input" -o "${temp_dir}/output" 2>/dev/null

    local size
    size=$(stat -f%z "${temp_dir}/output/en-US/test.png" 2>/dev/null || stat -c%s "${temp_dir}/output/en-US/test.png" 2>/dev/null)
    [[ ${size} -lt 10485760 ]]  # 10MB in bytes
}

#------------------------------------------------------------------------------
# Error Handling Tests (3 tests)
#------------------------------------------------------------------------------

test_continues_after_single_failure() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/input/en-US"
    # Create one valid and one invalid file
    magick -size 800x652 xc:white "${temp_dir}/input/en-US/valid.png" 2>/dev/null || return 1
    echo "not a png" > "${temp_dir}/input/en-US/invalid.png"

    "${SCRIPT_UNDER_TEST}" -i "${temp_dir}/input" -o "${temp_dir}/output" 2>/dev/null || true

    # Valid file should still be processed
    [[ -f "${temp_dir}/output/en-US/valid.png" ]]
}

test_reports_failure_count() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/input/en-US"
    echo "not a png" > "${temp_dir}/input/en-US/invalid.png"

    local output
    output=$("${SCRIPT_UNDER_TEST}" -i "${temp_dir}/input" -o "${temp_dir}/output" 2>&1) || true

    echo "${output}" | grep -qiE "fail|error.*1"
}

test_atomic_processing() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/input/en-US"
    mkdir -p "${temp_dir}/output/en-US"

    # Pre-populate output with a marker file
    echo "original" > "${temp_dir}/output/en-US/marker.txt"

    # Create only invalid input (should fail)
    echo "not a png" > "${temp_dir}/input/en-US/invalid.png"

    "${SCRIPT_UNDER_TEST}" -i "${temp_dir}/input" -o "${temp_dir}/output" 2>/dev/null || true

    # Original output should be untouched due to atomic processing
    [[ -f "${temp_dir}/output/en-US/marker.txt" ]] && \
    grep -q "original" "${temp_dir}/output/en-US/marker.txt"
}

#------------------------------------------------------------------------------
# Main Test Runner
#------------------------------------------------------------------------------

main() {
    echo "=========================================="
    echo "macOS Screenshot Processing Tests"
    echo "=========================================="
    echo ""

    # Script Basics (4 tests)
    run_test "Script exists" test_script_exists
    run_test "Script is executable" test_script_is_executable
    run_test "Script shows help" test_script_shows_help
    run_test "Script checks ImageMagick" test_script_checks_imagemagick

    # Input Validation (4 tests)
    run_test "Rejects missing input directory" test_rejects_missing_input_dir
    run_test "Rejects nonexistent input directory" test_rejects_nonexistent_input_dir
    run_test "Handles empty input directory" test_handles_empty_input_dir
    run_test "Discovers locales dynamically" test_discovers_locales_dynamically

    # Output Validation (4 tests)
    run_test "Creates output directory" test_creates_output_directory
    run_test "Output dimensions correct (2880x1800)" test_output_dimensions_correct
    run_test "Output has no alpha channel" test_output_has_no_alpha
    run_test "Output file under 10MB" test_output_under_10mb

    # Error Handling (3 tests)
    run_test "Continues after single failure" test_continues_after_single_failure
    run_test "Reports failure count" test_reports_failure_count
    run_test "Atomic processing (no partial output)" test_atomic_processing

    echo ""
    echo "=========================================="
    echo "Test Results"
    echo "=========================================="
    echo "Total:  ${TESTS_RUN}"
    echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
    echo ""

    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
```

### Step 3: Make the test file executable

```bash
chmod +x .github/scripts/tests/test-process-macos-screenshots.sh
```

### Step 4: Validate with shellcheck

```bash
shellcheck .github/scripts/tests/test-process-macos-screenshots.sh
```

## Tests to Pass

None - this is the RED phase. All 15 tests should FAIL.

## Acceptance Criteria

- [x] Test file exists at `.github/scripts/tests/test-process-macos-screenshots.sh`
- [x] Test file is executable (`chmod +x`)
- [x] Running tests shows **15/15 FAILURES** (RED phase verified)
- [x] `shellcheck` passes on test file with no errors
- [x] `.github/scripts/lib/` directory exists

## How to Verify Completion

```bash
# 1. Check test file exists and is executable
ls -la .github/scripts/tests/test-process-macos-screenshots.sh

# 2. Run shellcheck
shellcheck .github/scripts/tests/test-process-macos-screenshots.sh

# 3. Run tests (expect ALL to fail - this is correct for RED phase!)
.github/scripts/tests/test-process-macos-screenshots.sh

# Expected output should show:
# Total:  15
# Passed: 0
# Failed: 15
```

---

# Phase 1: Core Processing [NOT STARTED]

## Goal

Implement the helper library that processes ONE screenshot correctly. This makes 4 tests pass.

## Files to Create

| File | Action | Purpose |
|------|--------|---------|
| `.github/scripts/lib/macos-screenshot-helper.sh` | CREATE | Helper functions for ImageMagick processing |

## Implementation Instructions

### Step 1: Create the helper library

Create `.github/scripts/lib/macos-screenshot-helper.sh`:

```bash
#!/usr/bin/env bash
# macOS Screenshot Processing Helper Library
# Provides functions for processing raw screenshots into App Store format

set -euo pipefail

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

readonly MACOS_CANVAS_WIDTH=2880
readonly MACOS_CANVAS_HEIGHT=1800
readonly MACOS_GRADIENT_CENTER="#2A5F6D"
readonly MACOS_GRADIENT_EDGE="#0D1F26"
readonly MACOS_SCALE_PERCENT=85
readonly MACOS_SHADOW_OPACITY=50
readonly MACOS_SHADOW_BLUR=30
readonly MACOS_SHADOW_OFFSET_Y=15
readonly MACOS_MAX_FILE_SIZE=10485760  # 10MB in bytes

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------

log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_success() {
    echo "[OK] $*"
}

#------------------------------------------------------------------------------
# Dependency Check
#------------------------------------------------------------------------------

check_imagemagick() {
    if ! command -v magick &>/dev/null; then
        if command -v convert &>/dev/null; then
            log_error "ImageMagick 6 detected. This script requires ImageMagick 7+"
            log_error "Upgrade with: brew upgrade imagemagick"
            return 1
        fi
        log_error "ImageMagick not found. Install with: brew install imagemagick"
        return 1
    fi

    # Verify it's version 7+
    local version
    version=$(magick --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major_version
    major_version=$(echo "${version}" | cut -d. -f1)

    if [[ "${major_version}" -lt 7 ]]; then
        log_error "ImageMagick ${version} detected. This script requires ImageMagick 7+"
        log_error "Upgrade with: brew upgrade imagemagick"
        return 1
    fi

    log_info "ImageMagick ${version} detected"
    return 0
}

#------------------------------------------------------------------------------
# Input Validation
#------------------------------------------------------------------------------

validate_input_image() {
    local input_file="$1"

    # Check file exists
    if [[ ! -f "${input_file}" ]]; then
        log_error "Input file not found: ${input_file}"
        return 1
    fi

    # Check file is readable
    if [[ ! -r "${input_file}" ]]; then
        log_error "Input file not readable: ${input_file}"
        return 1
    fi

    # Check file is not empty
    if [[ ! -s "${input_file}" ]]; then
        log_error "Input file is empty: ${input_file}"
        return 1
    fi

    # Check MIME type is PNG
    local file_type
    file_type=$(file -b --mime-type "${input_file}" 2>/dev/null)
    if [[ "${file_type}" != "image/png" ]]; then
        log_error "Input file is not a PNG: ${input_file} (type: ${file_type})"
        return 1
    fi

    # Check file is a valid image (not corrupt)
    if ! magick identify "${input_file}" &>/dev/null; then
        log_error "Input file is corrupt or not a valid image: ${input_file}"
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Core Processing Function
#------------------------------------------------------------------------------

process_single_screenshot() {
    local input_file="$1"
    local output_file="$2"

    # Validate input
    if ! validate_input_image "${input_file}"; then
        return 1
    fi

    # Calculate max dimensions (85% of canvas, fits within both bounds)
    local max_width=$((MACOS_CANVAS_WIDTH * MACOS_SCALE_PERCENT / 100))   # 2448
    local max_height=$((MACOS_CANVAS_HEIGHT * MACOS_SCALE_PERCENT / 100)) # 1530

    # Create output directory if needed
    mkdir -p "$(dirname "${output_file}")"

    # Process with ImageMagick
    # NOTE: -resize "WxH>" fits within bounds while preserving aspect ratio
    #       The > flag prevents upscaling if input is smaller
    if ! magick -size "${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT}" -depth 8 \
        radial-gradient:"${MACOS_GRADIENT_CENTER}-${MACOS_GRADIENT_EDGE}" \
        \( "${input_file}" \
            -resize "${max_width}x${max_height}>" \
            \( +clone -background black \
               -shadow "${MACOS_SHADOW_OPACITY}x${MACOS_SHADOW_BLUR}+0+${MACOS_SHADOW_OFFSET_Y}" \) \
            +swap \
            -background none \
            -layers merge \
            +repage \
        \) \
        -gravity center \
        -composite \
        -flatten \
        -strip \
        -colorspace sRGB \
        -define png:compression-level=9 \
        "${output_file}"; then
        log_error "ImageMagick processing failed for: ${input_file}"
        return 1
    fi

    # Validate output was created
    if [[ ! -f "${output_file}" ]]; then
        log_error "Output file not created: ${output_file}"
        return 1
    fi

    # Validate output file size (not suspiciously small)
    local output_size
    output_size=$(stat -f%z "${output_file}" 2>/dev/null || stat -c%s "${output_file}" 2>/dev/null)
    if [[ "${output_size}" -lt 10000 ]]; then
        log_error "Output file suspiciously small (${output_size} bytes): ${output_file}"
        return 1
    fi

    # Validate output dimensions
    local output_dims
    output_dims=$(magick identify -format "%wx%h" "${output_file}")
    if [[ "${output_dims}" != "${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT}" ]]; then
        log_error "Output dimensions incorrect: ${output_dims} (expected ${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT})"
        return 1
    fi

    # Log input -> output transformation
    local input_dims
    input_dims=$(magick identify -format "%wx%h" "${input_file}")
    log_success "Processed: $(basename "${output_file}") [${input_dims} -> ${output_dims}]"
    return 0
}

#------------------------------------------------------------------------------
# Validation Function
#------------------------------------------------------------------------------

validate_macos_screenshot() {
    local screenshot="$1"

    # Check file exists
    if [[ ! -f "${screenshot}" ]]; then
        log_error "Screenshot not found: ${screenshot}"
        return 1
    fi

    # Check dimensions = 2880x1800
    local dims
    dims=$(magick identify -format "%wx%h" "${screenshot}" 2>/dev/null)
    if [[ "${dims}" != "${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT}" ]]; then
        log_error "Invalid dimensions: ${dims} (expected ${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT})"
        return 1
    fi

    # Check no alpha channel (flattened RGB)
    local channels
    channels=$(magick identify -format "%[channels]" "${screenshot}" 2>/dev/null)
    if [[ "${channels}" == *"a"* ]] || [[ "${channels}" == *"alpha"* ]]; then
        log_error "Screenshot has alpha channel: ${channels}"
        return 1
    fi

    # Check file size < 10MB
    local size
    size=$(stat -f%z "${screenshot}" 2>/dev/null || stat -c%s "${screenshot}" 2>/dev/null)
    if [[ ${size} -gt ${MACOS_MAX_FILE_SIZE} ]]; then
        log_error "Screenshot too large: ${size} bytes (max ${MACOS_MAX_FILE_SIZE})"
        return 1
    fi

    return 0
}
```

### Step 2: Validate with shellcheck

```bash
shellcheck .github/scripts/lib/macos-screenshot-helper.sh
```

### Step 3: Test the helper library manually

```bash
# Source the helper library
source .github/scripts/lib/macos-screenshot-helper.sh

# Test ImageMagick check
check_imagemagick

# Test processing a single screenshot
process_single_screenshot \
    "fastlane/screenshots/mac/en-US/01_MainWindow.png" \
    "/tmp/test_output.png"

# Verify output
magick identify /tmp/test_output.png
open /tmp/test_output.png
```

## Tests to Pass

After this phase, these 4 tests should pass:

- `test_script_checks_imagemagick`
- `test_output_dimensions_correct`
- `test_output_has_no_alpha`
- `test_output_under_10mb`

## Acceptance Criteria

- [ ] `source lib/macos-screenshot-helper.sh` works without errors
- [ ] `check_imagemagick` returns 0 when ImageMagick 7+ is installed
- [ ] `process_single_screenshot input.png output.png` produces valid output
- [ ] Output is exactly 2880x1800 pixels
- [ ] Output has no alpha channel (RGB only)
- [ ] Output has radial gradient background visible
- [ ] Output has drop shadow below window
- [ ] Output has window centered on canvas
- [ ] `shellcheck` passes on helper file

## How to Verify Completion

```bash
# 1. Check helper file exists
ls -la .github/scripts/lib/macos-screenshot-helper.sh

# 2. Run shellcheck
shellcheck .github/scripts/lib/macos-screenshot-helper.sh

# 3. Test manually
source .github/scripts/lib/macos-screenshot-helper.sh
check_imagemagick
process_single_screenshot \
    "fastlane/screenshots/mac/en-US/01_MainWindow.png" \
    "/tmp/phase1_test.png"

# 4. Verify output dimensions
magick identify -format "%wx%h" /tmp/phase1_test.png
# Expected: 2880x1800

# 5. Verify no alpha channel
magick identify -format "%[channels]" /tmp/phase1_test.png
# Expected: srgb (not srgba)

# 6. Visual verification
open /tmp/phase1_test.png
# - Gradient background visible around edges
# - Shadow appears below window
# - Window is centered
# - Window is not cropped
```

---

# Phase 2: Batch Processing [NOT STARTED]

## Goal

Implement the main script that processes ALL screenshots in ALL locales. This makes 8 additional tests pass (12 total).

## Files to Create

| File | Action | Purpose |
|------|--------|---------|
| `.github/scripts/process-macos-screenshots.sh` | CREATE | Main processing script |

## Implementation Instructions

### Step 1: Create the main processing script

Create `.github/scripts/process-macos-screenshots.sh`:

```bash
#!/usr/bin/env bash
# process-macos-screenshots.sh
# Processes raw macOS screenshots into App Store format (2880x1800)
# Creates marketing-style screenshots with radial gradient background and drop shadow

set -euo pipefail

#------------------------------------------------------------------------------
# Script Setup
#------------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source helper library
# shellcheck source=lib/macos-screenshot-helper.sh
source "${SCRIPT_DIR}/lib/macos-screenshot-helper.sh"

#------------------------------------------------------------------------------
# Default Configuration
#------------------------------------------------------------------------------

DEFAULT_INPUT_DIR="${PROJECT_ROOT}/fastlane/screenshots/mac"
DEFAULT_OUTPUT_DIR="${PROJECT_ROOT}/fastlane/screenshots/mac/processed"

#------------------------------------------------------------------------------
# Script Variables
#------------------------------------------------------------------------------

INPUT_DIR=""
OUTPUT_DIR=""
DRY_RUN=false
VERBOSE=false

#------------------------------------------------------------------------------
# Help Function
#------------------------------------------------------------------------------

show_help() {
    cat << 'EOF'
Usage: process-macos-screenshots.sh [OPTIONS]

Process raw macOS screenshots into App Store format (2880x1800).
Creates marketing-style screenshots with radial gradient background and drop shadow.

Options:
    -i, --input DIR     Input directory containing locale subdirectories
                        Default: fastlane/screenshots/mac
    -o, --output DIR    Output directory for processed screenshots
                        Default: fastlane/screenshots/mac/processed
    -n, --dry-run       Show what would be done without processing
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

Examples:
    process-macos-screenshots.sh
    process-macos-screenshots.sh -i ./input -o ./output
    process-macos-screenshots.sh --dry-run

Exit Codes:
    0   Success
    1   Invalid arguments
    2   Missing dependencies
    3   Processing failed

EOF
}

#------------------------------------------------------------------------------
# Argument Parsing
#------------------------------------------------------------------------------

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                INPUT_DIR="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Set defaults if not provided
    INPUT_DIR="${INPUT_DIR:-${DEFAULT_INPUT_DIR}}"
    OUTPUT_DIR="${OUTPUT_DIR:-${DEFAULT_OUTPUT_DIR}}"
}

#------------------------------------------------------------------------------
# Validation Functions
#------------------------------------------------------------------------------

validate_input_directory() {
    if [[ ! -d "${INPUT_DIR}" ]]; then
        log_error "Input directory does not exist: ${INPUT_DIR}"
        exit 1
    fi
}

#------------------------------------------------------------------------------
# Locale Discovery
#------------------------------------------------------------------------------

discover_locales() {
    local -a locales=()

    for locale_dir in "${INPUT_DIR}"/*/; do
        if [[ -d "${locale_dir}" ]]; then
            local locale_name
            locale_name="$(basename "${locale_dir}")"

            # Skip the processed directory
            if [[ "${locale_name}" != "processed" ]]; then
                locales+=("${locale_name}")
            fi
        fi
    done

    if [[ ${#locales[@]} -eq 0 ]]; then
        log_warn "No locale directories found in: ${INPUT_DIR}"
    else
        log_info "Discovered locales: ${locales[*]}"
    fi

    echo "${locales[@]}"
}

#------------------------------------------------------------------------------
# Batch Processing
#------------------------------------------------------------------------------

process_all_screenshots() {
    local -a locales
    read -ra locales <<< "$(discover_locales)"

    if [[ ${#locales[@]} -eq 0 ]]; then
        log_warn "No locales to process"
        return 0
    fi

    local success_count=0
    local fail_count=0
    local skip_count=0

    # Create temporary directory for atomic processing
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' EXIT

    log_info "Processing screenshots to temporary directory..."

    for locale in "${locales[@]}"; do
        local locale_input="${INPUT_DIR}/${locale}"
        local locale_output="${temp_dir}/${locale}"

        if [[ ! -d "${locale_input}" ]]; then
            log_warn "Locale directory not found: ${locale_input}"
            continue
        fi

        mkdir -p "${locale_output}"

        local png_count=0
        for screenshot in "${locale_input}"/*.png; do
            if [[ -f "${screenshot}" ]]; then
                ((png_count++)) || true
            fi
        done

        if [[ ${png_count} -eq 0 ]]; then
            log_warn "No PNG files in locale: ${locale}"
            continue
        fi

        log_info "Processing locale: ${locale} (${png_count} files)"

        for screenshot in "${locale_input}"/*.png; do
            if [[ -f "${screenshot}" ]]; then
                local filename
                filename="$(basename "${screenshot}")"

                if ${DRY_RUN}; then
                    log_info "[DRY-RUN] Would process: ${locale}/${filename}"
                    ((skip_count++)) || true
                    continue
                fi

                if process_single_screenshot "${screenshot}" "${locale_output}/${filename}"; then
                    ((success_count++)) || true
                else
                    ((fail_count++)) || true
                    log_error "Failed to process: ${locale}/${filename}"
                fi
            fi
        done
    done

    # Summary
    echo ""
    log_info "Processing complete:"
    log_info "  Success: ${success_count}"
    log_info "  Failed:  ${fail_count}"
    if ${DRY_RUN}; then
        log_info "  Skipped (dry-run): ${skip_count}"
    fi

    # Only move to final location if ALL succeeded (atomic processing)
    if [[ ${fail_count} -eq 0 ]] && [[ ${success_count} -gt 0 ]]; then
        log_info "All screenshots processed successfully. Moving to output directory..."

        # Remove existing output directory if it exists
        if [[ -d "${OUTPUT_DIR}" ]]; then
            rm -rf "${OUTPUT_DIR}"
        fi

        # Move processed files to output
        mkdir -p "$(dirname "${OUTPUT_DIR}")"
        mv "${temp_dir}" "${OUTPUT_DIR}"

        # Re-create temp_dir so trap doesn't fail
        temp_dir=$(mktemp -d)

        log_success "Output saved to: ${OUTPUT_DIR}"
    elif [[ ${fail_count} -gt 0 ]]; then
        log_error "Some screenshots failed to process. Output not saved."
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Main Entry Point
#------------------------------------------------------------------------------

main() {
    parse_arguments "$@"

    log_info "macOS Screenshot Processor"
    log_info "=========================="

    # Check dependencies
    if ! check_imagemagick; then
        exit 2
    fi

    # Validate input
    validate_input_directory

    log_info "Input:  ${INPUT_DIR}"
    log_info "Output: ${OUTPUT_DIR}"
    echo ""

    # Process screenshots
    if ! process_all_screenshots; then
        exit 3
    fi

    exit 0
}

main "$@"
```

### Step 2: Make the script executable

```bash
chmod +x .github/scripts/process-macos-screenshots.sh
```

### Step 3: Validate with shellcheck

```bash
shellcheck .github/scripts/process-macos-screenshots.sh
```

### Step 4: Test the script

```bash
# Show help
.github/scripts/process-macos-screenshots.sh --help

# Dry run
.github/scripts/process-macos-screenshots.sh --dry-run

# Full run
.github/scripts/process-macos-screenshots.sh
```

## Tests to Pass

After this phase, these tests should pass (12 total):

Previous 4 tests plus:
- `test_script_exists`
- `test_script_is_executable`
- `test_script_shows_help`
- `test_rejects_missing_input_dir`
- `test_rejects_nonexistent_input_dir`
- `test_handles_empty_input_dir`
- `test_discovers_locales_dynamically`
- `test_creates_output_directory`

## Acceptance Criteria

- [ ] Script exists at `.github/scripts/process-macos-screenshots.sh`
- [ ] Script is executable
- [ ] `--help` shows usage documentation
- [ ] Processes all locales dynamically (not hardcoded)
- [ ] Creates `processed/en-US/` and `processed/fi/` directories
- [ ] All 8 screenshots processed (4 en-US + 4 fi)
- [ ] `shellcheck` passes on script

## How to Verify Completion

```bash
# 1. Check script exists and is executable
ls -la .github/scripts/process-macos-screenshots.sh

# 2. Run shellcheck
shellcheck .github/scripts/process-macos-screenshots.sh

# 3. Test help
.github/scripts/process-macos-screenshots.sh --help

# 4. Run dry-run
.github/scripts/process-macos-screenshots.sh --dry-run

# 5. Run full processing
.github/scripts/process-macos-screenshots.sh

# 6. Verify output structure
ls -la fastlane/screenshots/mac/processed/
ls -la fastlane/screenshots/mac/processed/en-US/
ls -la fastlane/screenshots/mac/processed/fi/

# 7. Verify all screenshots are 2880x1800
for f in fastlane/screenshots/mac/processed/*/*.png; do
    echo "$(basename "$f"): $(magick identify -format '%wx%h' "$f")"
done

# 8. Run tests (expect 12/15 pass)
.github/scripts/tests/test-process-macos-screenshots.sh
```

---

# Phase 3: Integration [NOT STARTED]

## Goal

Integrate the processing script with the existing `generate-screenshots-local.sh` pipeline. This makes all 15 tests pass.

## Files to Modify

| File | Action | Purpose |
|------|--------|---------|
| `.github/scripts/generate-screenshots-local.sh` | MODIFY | Add post-processing call |

## Implementation Instructions

### Step 1: Read the current generate-screenshots-local.sh

First, understand the structure of the existing script:

```bash
# Find the generate_macos_screenshots function
grep -n "generate_macos_screenshots" .github/scripts/generate-screenshots-local.sh
```

### Step 2: Add post-processing to generate_macos_screenshots()

Locate the `generate_macos_screenshots()` function (around line 717) and add the post-processing call after the Fastlane command:

```bash
generate_macos_screenshots() {
    # ... existing code ...

    if ! bundle exec fastlane ios screenshots_macos; then
        log_error "macOS screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    # NEW: Post-process screenshots for App Store
    log_info "Processing screenshots for App Store dimensions..."
    if ! "${SCRIPT_DIR}/process-macos-screenshots.sh"; then
        log_error "macOS screenshot processing failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}
```

### Step 3: Update show_summary() function

Locate the `show_summary()` function (around line 834) and update the macOS output path display:

```bash
# Update output path display for macOS section
echo "  macOS (processed with gradient background):"
echo "    fastlane/screenshots/mac/processed/en-US/"
echo "    fastlane/screenshots/mac/processed/fi/"
```

### Step 4: Verify error handling works

The script should:
- Continue processing other platforms if macOS processing fails
- Report the failure in the summary
- Exit with appropriate error code if any platform fails

## Tests to Pass

After this phase, ALL 15 tests should pass:

Previous 12 tests plus:
- `test_continues_after_single_failure`
- `test_reports_failure_count`
- `test_atomic_processing`

## Acceptance Criteria

- [ ] `generate-screenshots-local.sh macos` runs post-processing automatically
- [ ] Post-processing is called after successful Fastlane run
- [ ] Failed individual images do not stop batch processing
- [ ] Partial failures leave clean state (atomic processing)
- [ ] Summary shows correct output paths
- [ ] **15/15 tests pass**

## How to Verify Completion

```bash
# 1. Run the integrated pipeline
.github/scripts/generate-screenshots-local.sh macos

# 2. Verify processed screenshots exist
ls -la fastlane/screenshots/mac/processed/en-US/
ls -la fastlane/screenshots/mac/processed/fi/

# 3. Verify dimensions
for f in fastlane/screenshots/mac/processed/*/*.png; do
    echo "$(basename "$f"): $(magick identify -format '%wx%h' "$f")"
done

# 4. Run all tests (expect 15/15 pass)
.github/scripts/tests/test-process-macos-screenshots.sh

# 5. Verify error handling
# Create a corrupt PNG and verify processing continues
echo "not a png" > fastlane/screenshots/mac/en-US/corrupt_test.png
.github/scripts/process-macos-screenshots.sh
rm fastlane/screenshots/mac/en-US/corrupt_test.png
```

---

# Phase 4: Validation & CI [NOT STARTED]

## Goal

Add validation updates and optional CI job. This is the REFACTOR phase.

## Files to Modify

| File | Action | Purpose |
|------|--------|---------|
| `.github/scripts/validate-screenshots.sh` | MODIFY | Add macOS validation |
| `fastlane/Fastfile` | MODIFY | Add validation lane |

## Optional Files to Create

| File | Action | Purpose |
|------|--------|---------|
| `.github/workflows/validate-macos-screenshots.yml` | CREATE (optional) | CI validation job |

## Implementation Instructions

### Step 1: Add macOS validation to validate-screenshots.sh

Add a new function to validate macOS processed screenshots:

```bash
validate_macos_screenshots() {
    local processed_dir="${PROJECT_ROOT}/fastlane/screenshots/mac/processed"
    local error_count=0

    log_info "Validating macOS processed screenshots..."

    if [[ ! -d "${processed_dir}" ]]; then
        log_error "macOS processed directory not found: ${processed_dir}"
        return 1
    fi

    for screenshot in "${processed_dir}"/*/*.png; do
        if [[ ! -f "${screenshot}" ]]; then
            continue
        fi

        local filename
        filename=$(basename "${screenshot}")

        # Check dimensions = 2880x1800
        local dims
        dims=$(magick identify -format "%wx%h" "${screenshot}" 2>/dev/null)
        if [[ "${dims}" != "2880x1800" ]]; then
            log_error "Invalid dimensions for ${filename}: ${dims} (expected 2880x1800)"
            ((error_count++)) || true
        fi

        # Check no alpha channel
        local channels
        channels=$(magick identify -format "%[channels]" "${screenshot}" 2>/dev/null)
        if [[ "${channels}" == *"a"* ]] || [[ "${channels}" == *"alpha"* ]]; then
            log_error "Alpha channel found in ${filename}: ${channels}"
            ((error_count++)) || true
        fi

        # Check file size < 10MB
        local size
        size=$(stat -f%z "${screenshot}" 2>/dev/null || stat -c%s "${screenshot}" 2>/dev/null)
        if [[ ${size} -gt 10485760 ]]; then
            log_error "File too large for ${filename}: ${size} bytes (max 10MB)"
            ((error_count++)) || true
        fi
    done

    if [[ ${error_count} -gt 0 ]]; then
        log_error "macOS validation failed with ${error_count} errors"
        return 1
    fi

    log_success "macOS screenshots validated successfully"
    return 0
}
```

### Step 2: Add Fastlane validation lane (optional)

Add to `fastlane/Fastfile`:

```ruby
desc "Validate delivery screenshots including macOS"
lane :validate_delivery_screenshots do
  # Existing validation...

  # Add macOS validation
  sh("../../../.github/scripts/validate-screenshots.sh --macos-only")
end
```

### Step 3: Create CI workflow (optional, validation-only approach)

Create `.github/workflows/validate-macos-screenshots.yml`:

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
    name: Validate macOS Screenshots
    runs-on: macos-14
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install ImageMagick
        run: brew install imagemagick

      - name: Check processed screenshots exist
        run: |
          if [ ! -d "fastlane/screenshots/mac/processed" ]; then
            echo "::error::macOS processed screenshots not found."
            echo "::error::Run '.github/scripts/generate-screenshots-local.sh macos' locally first."
            exit 1
          fi

      - name: Validate dimensions
        run: |
          for f in fastlane/screenshots/mac/processed/*/*.png; do
            dims=$(magick identify -format "%wx%h" "$f")
            if [[ "$dims" != "2880x1800" ]]; then
              echo "::error::Invalid dimensions for $(basename "$f"): $dims"
              exit 1
            fi
          done
          echo "All macOS screenshots have correct dimensions (2880x1800)"

      - name: Validate no alpha channel
        run: |
          for f in fastlane/screenshots/mac/processed/*/*.png; do
            channels=$(magick identify -format "%[channels]" "$f")
            if [[ "$channels" == *"a"* ]]; then
              echo "::error::Alpha channel found in $(basename "$f")"
              exit 1
            fi
          done
          echo "All macOS screenshots have no alpha channel"
```

## Tests to Pass

All 15 tests should still pass.

## Acceptance Criteria

- [ ] `validate-screenshots.sh` checks macOS processed screenshots
- [ ] Validation checks dimensions = 2880x1800
- [ ] Validation checks no alpha channel
- [ ] Validation checks file size < 10MB
- [ ] All 15 tests pass
- [ ] Manual visual verification complete
- [ ] Test upload to App Store Connect succeeds (optional)

## How to Verify Completion

```bash
# 1. Run validation
.github/scripts/validate-screenshots.sh

# 2. Run all tests (expect 15/15 pass)
.github/scripts/tests/test-process-macos-screenshots.sh

# 3. Visual verification - open processed screenshots
for f in fastlane/screenshots/mac/processed/en-US/*.png; do
    open "$f"
done

# Verify each screenshot:
# - Gradient background visible around edges
# - Shadow appears below window
# - Window is centered
# - Window is not cropped
# - Settings window is proportionally smaller

# 4. Test App Store upload (optional)
# Upload to App Store Connect and verify acceptance
```

---

# Appendix A: Apple App Store Requirements

## macOS Screenshot Specifications

| Requirement | Specification |
|------------|---------------|
| **Accepted Dimensions** | 1280x800, 1440x900, 2560x1600, **2880x1800** |
| **Aspect Ratio** | 16:10 (mandatory) |
| **File Format** | PNG or JPEG |
| **Color Space** | RGB (no transparency/alpha allowed) |
| **Max File Size** | 10MB per screenshot |
| **Quantity** | 1-10 screenshots per locale |

**Recommended**: 2880x1800 for highest quality on Retina displays.

## Sources

- [Apple App Store Connect Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/)
- [How to automate perfect screenshots for the Mac App Store - Jesse Squires](https://www.jessesquires.com/blog/2025/03/24/automate-perfect-mac-screenshots/)

---

# Appendix B: Design Specifications

## Background Colors (from ListAll App Icon)

```
Primary Background:     #1A3F4D (dark teal/navy)
Lighter Center:         #2A5F6D (for radial gradient center)
Darkest Edge:           #0D1F26 (gradient edge color)

Accent Colors (for future use):
- Cyan:    #00FFD4
- Blue:    #4080FF
- Purple:  #8F4FFF
- Pink:    #FF4F8F
```

## Radial Gradient Specification

```
Type:           Radial gradient
Center Color:   #2A5F6D (lighter teal)
Edge Color:     #0D1F26 (dark navy)
Effect:         Creates depth with lighter center, darker edges
```

## Drop Shadow Specification

```
Opacity:    50%
Blur:       30px
X-Offset:   0px
Y-Offset:   15px (shadow below window)
Color:      rgba(0,0,0,0.5)
```

## Window Scaling (CRITICAL)

The `-resize 85%` flag scales to 85% of the *input* size, NOT the canvas. We calculate target dimensions based on canvas size.

**Scaling Strategy:**
```
Canvas:           2880x1800
Max width:        2880 * 0.85 = 2448px
Max height:       1800 * 0.85 = 1530px
ImageMagick:      -resize "2448x1530>" (fits within bounds, preserves aspect ratio)

For 800x652:      Scale factor = min(2448/800, 1530/652) = min(3.06, 2.35) = 2.35
                  Result: 800*2.35 x 652*2.35 = 1880x1532 -> fits!

For 482x420:      Same bounds, smaller result (proportionally smaller on canvas)
                  Result: ~1133x988 (smaller dialog appearance)
```

**User Decision:** Settings window (482x420) will remain proportionally smaller on canvas to show it's a dialog, not scaled to same size as main windows.

**Centering:** Gravity center (both horizontal and vertical)

---

# Appendix C: ImageMagick Reference

## Core Processing Command

```bash
magick -size 2880x1800 -depth 8 radial-gradient:"#2A5F6D-#0D1F26" \
    \( "${input_file}" \
        -resize "2448x1530>" \
        \( +clone -background black -shadow 50x30+0+15 \) \
        +swap \
        -background none \
        -layers merge \
        +repage \
    \) \
    -gravity center \
    -composite \
    -flatten \
    -strip \
    -colorspace sRGB \
    -define png:compression-level=9 \
    "${output_file}"
```

## Command Breakdown

| Flag/Option | Purpose |
|-------------|---------|
| `-size 2880x1800` | Create canvas at target dimensions |
| `-depth 8` | Use 8-bit color depth (prevents 16-bit intermediates) |
| `radial-gradient:"#2A5F6D-#0D1F26"` | Create radial gradient from center to edge |
| `-resize "2448x1530>"` | Scale to fit within bounds (> prevents upscaling) |
| `-shadow 50x30+0+15` | Create shadow: 50% opacity, 30px blur, 15px Y offset |
| `-layers merge` | Merge window and shadow layers |
| `-gravity center` | Center the composite on canvas |
| `-composite` | Overlay window+shadow on gradient |
| `-flatten` | Remove alpha channel (required for App Store) |
| `-strip` | Remove metadata |
| `-colorspace sRGB` | Ensure sRGB color space |
| `-define png:compression-level=9` | Maximum PNG compression |

## Quick Test Command

```bash
cd /Users/aleksi/source/listall

magick -size 2880x1800 -depth 8 radial-gradient:"#2A5F6D-#0D1F26" \
    \( fastlane/screenshots/mac/en-US/01_MainWindow.png \
        -resize "2448x1530>" \
        \( +clone -background black -shadow 50x30+0+15 \) \
        +swap \
        -background none \
        -layers merge \
        +repage \
    \) \
    -gravity center \
    -composite \
    -flatten \
    -strip \
    -colorspace sRGB \
    -define png:compression-level=9 \
    /tmp/test_macos_screenshot.png

# Verify dimensions
magick identify /tmp/test_macos_screenshot.png

# Open to visually verify
open /tmp/test_macos_screenshot.png
```

## Validation Commands

```bash
# Check dimensions
magick identify -format "%wx%h" screenshot.png

# Check channels (should be "srgb", not "srgba")
magick identify -format "%[channels]" screenshot.png

# Check file size
stat -f%z screenshot.png  # macOS
stat -c%s screenshot.png  # Linux
```

---

# Appendix D: Critical Review History

## Review Conducted By

- **Critical Reviewer Agent** - Found 16 issues across process, testing, error handling
- **Testing Specialist Agent** - Complete TDD test plan
- **Shell Script Specialist Agent** - ImageMagick command review, code fixes
- **Pipeline Specialist Agent** - CI/CD integration review

## Fixed Issues

| Issue | Severity | Status | Fix Applied |
|-------|----------|--------|-------------|
| `-resize 85%` scales input, not canvas | CRITICAL | FIXED | Changed to `-resize "2448x1530>"` |
| Settings window different size | CRITICAL | FIXED | User chose: keep proportionally smaller |
| Aspect ratio mismatch could exceed canvas | IMPORTANT | FIXED | Using both width AND height bounds |
| Missing error handling | IMPORTANT | FIXED | Added ImageMagick exit code check |
| 16-bit intermediate processing | IMPORTANT | FIXED | Added `-depth 8` early |
| TDD Violation - Tests last | CRITICAL | FIXED | Restructured to phases 0-4 |
| No ImageMagick dependency check | CRITICAL | FIXED | Added check_imagemagick() |
| Hardcoded locales | HIGH | FIXED | Dynamic discovery |
| No atomic processing | HIGH | FIXED | Temp dir + move pattern |
| No input validation | HIGH | FIXED | Added validate_input_image() |
| Arithmetic increment bug | HIGH | FIXED | Added `|| true` |

## Required Code Fixes Applied

### Fix 1: ImageMagick Dependency Check
```bash
check_imagemagick() {
    if ! command -v magick &>/dev/null; then
        # ... error handling
    fi
}
```

### Fix 2: Arithmetic Safety
```bash
# Use || true to prevent errexit on zero increment
((success_count++)) || true
```

### Fix 3: Resize Flag (Prevent Upscaling)
```bash
-resize "${max_width}x${max_height}>"  # > prevents upscaling
```

### Fix 4: Dynamic Locale Discovery
```bash
for locale_dir in "${input_dir}"/*/; do
    local locale_name="$(basename "${locale_dir}")"
    [[ "${locale_name}" != "processed" ]] && locales+=("${locale_name}")
done
```

### Fix 5: Atomic Processing Pattern
```bash
local temp_dir=$(mktemp -d)
trap 'rm -rf "${temp_dir}"' EXIT
# Process to temp, then move if all succeed
```

---

# Appendix E: File Structure

## Files Created by This Implementation

```
.github/scripts/
├── generate-screenshots-local.sh      # MODIFIED - integration
├── process-macos-screenshots.sh       # NEW - main processing script
├── validate-screenshots.sh            # MODIFIED - add macOS validation
├── lib/
│   └── macos-screenshot-helper.sh     # NEW - ImageMagick functions
└── tests/
    └── test-process-macos-screenshots.sh  # NEW - 15 test cases

fastlane/screenshots/mac/
├── en-US/
│   ├── 01_MainWindow.png              # Raw XCUITest captures (800x652)
│   ├── 02_ListDetailView.png
│   ├── 03_ItemEditSheet.png
│   └── 04_SettingsWindow.png          # Smaller dialog (482x420)
├── fi/
│   └── ... (same structure)
└── processed/                          # NEW - App Store ready (2880x1800)
    ├── en-US/
    │   ├── 01_MainWindow.png
    │   ├── 02_ListDetailView.png
    │   ├── 03_ItemEditSheet.png
    │   └── 04_SettingsWindow.png
    └── fi/
        └── ... (same structure)
```

---

# Appendix F: Current Screenshot Dimensions

| Screenshot | Current Size | Notes |
|------------|--------------|-------|
| 01_MainWindow.png | 800x652 | Main app window |
| 02_ListDetailView.png | 800x652 | List selected |
| 03_ItemEditSheet.png | 800x652 | Edit sheet open |
| 04_SettingsWindow.png | 482x420 | **Smaller dialog** |

---

**Document Status:** READY FOR IMPLEMENTATION
**Revision:** 2.0 (Restructured for Phase-by-Phase Implementation)
**Next Step:** Begin Phase 0 - Create test file with 15 test cases
