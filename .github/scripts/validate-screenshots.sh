#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Screenshot Validation Script
# ==============================================================================
# Validates raw screenshots for App Store Connect delivery requirements.
# Checks dimensions against exact App Store requirements for each platform.
#
# Usage:
#   ./validate-screenshots.sh <screenshots_dir> <device_type>
#
# Arguments:
#   screenshots_dir - Directory containing screenshots to validate
#   device_type     - Device type: iphone, ipad, watch, or mac
#
# Exit Codes:
#   0 - All validations passed
#   1 - One or more validations failed or missing arguments
# ==============================================================================

# shellcheck disable=SC2155  # Intentional: combined declaration and assignment for script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155,SC2034  # Intentional: combined declaration and assignment; PROJECT_ROOT reserved for future use
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ANSI color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Valid dimensions for each platform
# iPhone: 6.7" display (iPhone 14 Pro Max, 15 Pro Max, 16 Pro Max)
readonly -a IPHONE_VALID_DIMENSIONS=(
    "1290x2796"  # iPhone 6.7" exact (required by App Store)
)

# iPad: 13" display (iPad Pro 13-inch M4)
readonly -a IPAD_VALID_DIMENSIONS=(
    "2064x2752"  # iPad 13" exact (2024 standard)
)

# Apple Watch: Series 7+ (46mm)
readonly -a WATCH_VALID_DIMENSIONS=(
    "396x484"    # Watch Series 7+ exact
)

# macOS: 16:10 aspect ratio displays
readonly -a MACOS_VALID_DIMENSIONS=(
    "1280x800"   # Minimum (MacBook Air 13")
    "1440x900"   # MacBook Air 13" Retina
    "2560x1600"  # 13" MacBook Pro Retina
    "2880x1800"  # 15/16" MacBook Pro Retina (Recommended)
)

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

# shellcheck disable=SC2329  # Reserved for future use
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

# Check if dimension is valid for device type
is_valid_dimension() {
    local dimension="$1"
    local device_type="$2"

    # Get valid dimensions for this device type
    local -a valid_dims
    case "${device_type}" in
        iphone)
            valid_dims=("${IPHONE_VALID_DIMENSIONS[@]}")
            ;;
        ipad)
            valid_dims=("${IPAD_VALID_DIMENSIONS[@]}")
            ;;
        watch)
            valid_dims=("${WATCH_VALID_DIMENSIONS[@]}")
            ;;
        mac)
            valid_dims=("${MACOS_VALID_DIMENSIONS[@]}")
            ;;
        *)
            return 1
            ;;
    esac

    for valid_dim in "${valid_dims[@]}"; do
        if [[ "${dimension}" == "${valid_dim}" ]]; then
            return 0
        fi
    done
    return 1
}

# Get expected dimensions list as string for device type
get_expected_dimensions() {
    local device_type="$1"

    case "${device_type}" in
        iphone)
            echo "${IPHONE_VALID_DIMENSIONS[*]}"
            ;;
        ipad)
            echo "${IPAD_VALID_DIMENSIONS[*]}"
            ;;
        watch)
            echo "${WATCH_VALID_DIMENSIONS[*]}"
            ;;
        mac)
            echo "${MACOS_VALID_DIMENSIONS[*]}"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ==============================================================================
# Validation Functions
# ==============================================================================

validate_screenshots() {
    local screenshots_dir="$1"
    local device_type="$2"

    log_header "Validating ${device_type} screenshots in ${screenshots_dir}"

    # Check if directory exists
    if [[ ! -d "${screenshots_dir}" ]]; then
        log_error "Screenshots directory not found: ${screenshots_dir}"
        return 1
    fi

    # Find all PNG files (excluding _framed.png files)
    local file_count=0
    while IFS= read -r -d '' screenshot; do
        # Skip framed screenshots
        if [[ "$(basename "${screenshot}")" == *"_framed.png" ]]; then
            continue
        fi

        ((file_count++)) || true

        # Get dimensions using ImageMagick identify
        local dims
        if ! dims=$(identify -format '%wx%h' "${screenshot}" 2>/dev/null); then
            log_error "Failed to read dimensions: $(basename "${screenshot}")"
            continue
        fi

        # Validate dimensions
        if is_valid_dimension "${dims}" "${device_type}"; then
            log_success "$(basename "${screenshot}"): ${dims}"
            ((VALIDATED_COUNT++)) || true
        else
            local expected_dims
            expected_dims=$(get_expected_dimensions "${device_type}")
            log_error "$(basename "${screenshot}"): Wrong dimensions ${dims}, expected one of: ${expected_dims}"
        fi
    done < <(find "${screenshots_dir}" -name "*.png" -type f -print0 2>/dev/null)

    if [[ "${file_count}" -eq 0 ]]; then
        log_error "No screenshots found in ${screenshots_dir}"
        return 1
    else
        log_info "Processed ${file_count} screenshot(s)"
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

usage() {
    cat <<EOF
Usage: $0 <screenshots_dir> <device_type>

Arguments:
  screenshots_dir - Directory containing screenshots to validate
  device_type     - Device type: iphone, ipad, watch, or mac

Examples:
  $0 fastlane/screenshots_compat/en-US iphone
  $0 fastlane/screenshots/watch_normalized/en-US watch
  $0 fastlane/screenshots/mac/en-US mac

Exit Codes:
  0 - All validations passed
  1 - One or more validations failed or missing arguments
EOF
    exit 1
}

main() {
    # Check arguments
    if [[ $# -ne 2 ]]; then
        echo -e "${RED}Error: Missing required arguments${NC}" >&2
        echo "" >&2
        usage
    fi

    local screenshots_dir="$1"
    local device_type="$2"

    # Validate device type
    case "${device_type}" in
        iphone|ipad|watch|mac)
            ;;
        *)
            echo -e "${RED}Error: Invalid device type '${device_type}'${NC}" >&2
            echo -e "${RED}Must be one of: iphone, ipad, watch, mac${NC}" >&2
            echo "" >&2
            usage
            ;;
    esac

    # Convert device type to uppercase for display
    local device_type_upper
    device_type_upper=$(echo "${device_type}" | tr '[:lower:]' '[:upper:]')

    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Screenshot Validation - ${device_type_upper}${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

    # Check dependencies first
    check_dependencies

    # Run validation
    validate_screenshots "${screenshots_dir}" "${device_type}"

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
        echo "Expected dimensions for ${device_type}:"
        get_expected_dimensions "${device_type}" | tr ' ' '\n' | sed 's/^/  - /'
        echo ""
        exit 1
    fi
}

main "$@"
