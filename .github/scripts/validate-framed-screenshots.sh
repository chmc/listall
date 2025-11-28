#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Framed Screenshot Validation Script
# ==============================================================================
# Validates custom-framed screenshots for completeness, dimensions, size, and
# image integrity before marketing use or CI/CD deployment.
#
# Validation Checks:
#   1. Screenshot completeness (expected counts per locale)
#   2. Dimension validation (framed images larger than raw)
#   3. File size checks (warn if > 2MB)
#   4. Image integrity (using identify -regard-warnings)
#
# Exit Codes:
#   0 - All validations passed
#   1 - One or more validations failed
# ==============================================================================

# shellcheck disable=SC2155  # Intentional: combined declaration and assignment for script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155  # Intentional: combined declaration and assignment for script paths
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly FRAMED_DIR="${PROJECT_ROOT}/fastlane/screenshots_framed"

# ANSI color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Expected screenshot counts per locale
readonly EXPECTED_IPHONE_COUNT=2
readonly EXPECTED_IPAD_COUNT=2
readonly EXPECTED_WATCH_COUNT=5

# Maximum file size in KB (2MB = 2048KB)
readonly MAX_FILE_SIZE_KB=2048

# Minimum dimensions for framed screenshots
readonly MIN_FRAMED_WIDTH=1000
readonly MIN_FRAMED_HEIGHT=1000

# Counters for tracking
ERROR_COUNT=0
WARNING_COUNT=0
VALIDATED_COUNT=0

# ==============================================================================
# Helper Functions
# ==============================================================================

log_header() {
    echo ""
    echo -e "${BLUE}=== $* ===${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
    ((ERROR_COUNT++)) || true
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
    ((WARNING_COUNT++)) || true
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

# Check if ImageMagick is available
check_dependencies() {
    if ! command -v identify &>/dev/null; then
        echo -e "${RED}Error: ImageMagick not found. Install with: brew install imagemagick${NC}" >&2
        exit 1
    fi
}

# ==============================================================================
# Validation Functions
# ==============================================================================

# Check screenshot completeness - expected counts per locale
check_completeness() {
    log_header "Screenshot Completeness"

    if [[ ! -d "${FRAMED_DIR}" ]]; then
        log_error "Framed screenshots directory not found: ${FRAMED_DIR}"
        return
    fi

    local locales
    # Find all locale directories
    locales=()
    if [[ -d "${FRAMED_DIR}/ios" ]]; then
        while IFS= read -r -d '' locale_dir; do
            locales+=("$(basename "${locale_dir}")")
        done < <(find "${FRAMED_DIR}/ios" -type d -mindepth 1 -maxdepth 1 -print0)
    fi

    # Also check watch directory
    if [[ -d "${FRAMED_DIR}/watch" ]]; then
        while IFS= read -r -d '' locale_dir; do
            local locale_name
            locale_name="$(basename "${locale_dir}")"
            # Only add if not already in array
            if [[ ! " ${locales[*]} " =~ ${locale_name} ]]; then
                locales+=("${locale_name}")
            fi
        done < <(find "${FRAMED_DIR}/watch" -type d -mindepth 1 -maxdepth 1 -print0)
    fi

    # If no locales found, check for common ones
    if [[ ${#locales[@]} -eq 0 ]]; then
        locales=("en-US" "fi")
    fi

    for locale in "${locales[@]}"; do
        local iphone_count=0
        local ipad_count=0
        local watch_count=0

        # Count iPhone screenshots
        if [[ -d "${FRAMED_DIR}/ios/${locale}" ]]; then
            iphone_count=$(find "${FRAMED_DIR}/ios/${locale}" -name "iPhone*_framed.png" 2>/dev/null | wc -l | xargs)
        fi

        # Count iPad screenshots
        if [[ -d "${FRAMED_DIR}/ios/${locale}" ]]; then
            ipad_count=$(find "${FRAMED_DIR}/ios/${locale}" -name "iPad*_framed.png" 2>/dev/null | wc -l | xargs)
        fi

        # Count Watch screenshots
        if [[ -d "${FRAMED_DIR}/watch/${locale}" ]]; then
            watch_count=$(find "${FRAMED_DIR}/watch/${locale}" -name "*_framed.png" 2>/dev/null | wc -l | xargs)
        fi

        log_info "Locale: ${locale}"
        echo "    iPhone: ${iphone_count}/${EXPECTED_IPHONE_COUNT}, iPad: ${ipad_count}/${EXPECTED_IPAD_COUNT}, Watch: ${watch_count}/${EXPECTED_WATCH_COUNT}"

        # Validate counts
        if [[ "${iphone_count}" -lt "${EXPECTED_IPHONE_COUNT}" ]]; then
            log_error "  ${locale}: Expected ${EXPECTED_IPHONE_COUNT} iPhone screenshots, found ${iphone_count}"
        fi

        if [[ "${ipad_count}" -lt "${EXPECTED_IPAD_COUNT}" ]]; then
            log_error "  ${locale}: Expected ${EXPECTED_IPAD_COUNT} iPad screenshots, found ${ipad_count}"
        fi

        if [[ "${watch_count}" -lt "${EXPECTED_WATCH_COUNT}" ]]; then
            log_error "  ${locale}: Expected ${EXPECTED_WATCH_COUNT} Watch screenshots, found ${watch_count}"
        fi

        # Success if all counts match
        if [[ "${iphone_count}" -ge "${EXPECTED_IPHONE_COUNT}" ]] && \
           [[ "${ipad_count}" -ge "${EXPECTED_IPAD_COUNT}" ]] && \
           [[ "${watch_count}" -ge "${EXPECTED_WATCH_COUNT}" ]]; then
            log_success "${locale}: All expected screenshots present"
        fi
    done
}

# Validate dimensions - framed images should be larger than raw screenshots
validate_dimensions() {
    log_header "Dimension Validation"

    local file_count=0

    while IFS= read -r -d '' framed_file; do
        ((file_count++)) || true

        # Get dimensions using ImageMagick identify
        local dims
        if ! dims=$(identify -format '%wx%h' "${framed_file}" 2>/dev/null); then
            log_error "Failed to read dimensions: $(basename "${framed_file}")"
            continue
        fi

        local width height
        width=$(echo "${dims}" | cut -d'x' -f1)
        height=$(echo "${dims}" | cut -d'x' -f2)

        # Validate dimensions are reasonable for framed screenshots
        if [[ "${width}" -lt "${MIN_FRAMED_WIDTH}" ]] || [[ "${height}" -lt "${MIN_FRAMED_HEIGHT}" ]]; then
            log_error "$(basename "${framed_file}"): Dimensions too small (${dims}), expected minimum ${MIN_FRAMED_WIDTH}x${MIN_FRAMED_HEIGHT}"
        fi

        ((VALIDATED_COUNT++)) || true
    done < <(find "${FRAMED_DIR}" -name "*_framed.png" -type f -print0 2>/dev/null)

    if [[ "${file_count}" -eq 0 ]]; then
        log_error "No framed screenshots found in ${FRAMED_DIR}"
    else
        log_success "Validated dimensions for ${file_count} framed screenshots"
    fi
}

# Check file sizes - warn if exceeding 2MB threshold
check_file_sizes() {
    log_header "File Size Validation"

    local oversized_count=0
    local total_size_kb=0

    while IFS= read -r -d '' framed_file; do
        local size_kb
        size_kb=$(du -k "${framed_file}" | cut -f1)
        total_size_kb=$((total_size_kb + size_kb))

        if [[ "${size_kb}" -gt "${MAX_FILE_SIZE_KB}" ]]; then
            local size_mb
            size_mb=$(echo "scale=2; ${size_kb} / 1024" | bc)
            log_warning "$(basename "${framed_file}"): ${size_mb}MB exceeds ${MAX_FILE_SIZE_KB}KB limit (consider compression)"
            ((oversized_count++)) || true
        fi
    done < <(find "${FRAMED_DIR}" -name "*_framed.png" -type f -print0 2>/dev/null)

    if [[ "${oversized_count}" -eq 0 ]]; then
        local total_mb
        total_mb=$(echo "scale=2; ${total_size_kb} / 1024" | bc)
        log_success "All framed screenshots under ${MAX_FILE_SIZE_KB}KB limit (total: ${total_mb}MB)"
    else
        log_info "${oversized_count} file(s) exceed size limit but may be acceptable for marketing"
    fi
}

# Verify image integrity using ImageMagick's strict validation
verify_integrity() {
    log_header "Image Integrity Validation"

    local corrupt_count=0
    local valid_count=0

    while IFS= read -r -d '' framed_file; do
        # Use identify with -regard-warnings to catch any image issues
        if identify -regard-warnings "${framed_file}" &>/dev/null; then
            ((valid_count++)) || true
        else
            log_error "Corrupted or invalid image: $(basename "${framed_file}")"
            ((corrupt_count++)) || true
        fi
    done < <(find "${FRAMED_DIR}" -name "*_framed.png" -type f -print0 2>/dev/null)

    if [[ "${corrupt_count}" -eq 0 ]] && [[ "${valid_count}" -gt 0 ]]; then
        log_success "All ${valid_count} framed screenshots have valid image integrity"
    elif [[ "${valid_count}" -eq 0 ]]; then
        log_error "No valid framed screenshots found"
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Framed Screenshot Validation                                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

    # Check dependencies first
    check_dependencies

    # Run all validation checks
    check_completeness
    validate_dimensions
    check_file_sizes
    verify_integrity

    # Print summary
    log_header "Summary"
    echo -e "${GREEN}Validated Files: ${VALIDATED_COUNT}${NC}"
    echo -e "${RED}Errors: ${ERROR_COUNT}${NC}"
    echo -e "${YELLOW}Warnings: ${WARNING_COUNT}${NC}"

    # Exit with appropriate code
    echo ""
    if [[ "${ERROR_COUNT}" -eq 0 ]]; then
        echo -e "${GREEN}✅ All validations passed!${NC}"
        if [[ "${WARNING_COUNT}" -gt 0 ]]; then
            echo -e "${YELLOW}Note: ${WARNING_COUNT} warning(s) detected but may be acceptable${NC}"
        fi
        echo ""
        exit 0
    else
        echo -e "${RED}❌ FAILED: ${ERROR_COUNT} error(s) found${NC}"
        echo ""
        echo "Please fix the errors before proceeding."
        echo "For more information, see:"
        echo "  ${PROJECT_ROOT}/documentation/todo.framed_screenshots.md"
        echo ""
        exit 1
    fi
}

main "$@"
