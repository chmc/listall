#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Local Screenshot Generation - Preflight Check Script
# ==============================================================================
# Validates the local environment meets all requirements for screenshot
# generation before running time-consuming Fastlane lanes.
#
# Exit Codes:
#   0 - All checks passed
#   1 - One or more checks failed
# ==============================================================================

# shellcheck disable=SC2155  # Intentional: combined declaration and assignment for script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155  # Intentional: combined declaration and assignment for script paths
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ANSI color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Counters for pass/fail tracking
PASS_COUNT=0
FAIL_COUNT=0

# ==============================================================================
# Helper Functions
# ==============================================================================

log_header() {
    echo ""
    echo -e "${BLUE}=== $* ===${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
    ((PASS_COUNT++)) || true
}

log_failure() {
    echo -e "${RED}✗${NC} $*"
    ((FAIL_COUNT++)) || true
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

# Check a command or condition and report result
# Args:
#   $1 - Description of the check
#   $2 - Command to execute
#   $3 - Expected value/description for failure message
# Note: This function is available for future use or indirect invocation
# shellcheck disable=SC2329  # Function available for utility/future use
check_requirement() {
    local description="$1"
    local command="$2"
    local expected="${3:-}"

    if eval "${command}" &>/dev/null; then
        log_success "${description}"
        return 0
    else
        if [[ -n "${expected}" ]]; then
            log_failure "${description} - Expected: ${expected}"
        else
            log_failure "${description}"
        fi
        return 1
    fi
}

# ==============================================================================
# Xcode Checks
# ==============================================================================

check_xcode() {
    log_header "Xcode Environment"

    # Check Xcode is installed
    if ! command -v xcodebuild &>/dev/null; then
        log_failure "Xcode not found - xcodebuild command not available"
        return
    fi

    # Check Xcode version (16.1+)
    local xcode_version
    xcode_version="$(xcodebuild -version | head -1 | awk '{print $2}')"
    local major minor
    major="$(echo "${xcode_version}" | cut -d. -f1)"
    minor="$(echo "${xcode_version}" | cut -d. -f2)"

    if [[ "${major}" -gt 16 ]] || [[ "${major}" -eq 16 && "${minor}" -ge 1 ]]; then
        log_success "Xcode ${xcode_version} (requirement: 16.1+)"
    else
        log_failure "Xcode ${xcode_version} - Expected: 16.1 or higher"
    fi
}

# ==============================================================================
# Simulator Checks
# ==============================================================================

check_simulators() {
    log_header "Simulators"

    # Check if simctl is available
    if ! command -v xcrun &>/dev/null; then
        log_failure "xcrun not available - cannot check simulators"
        return
    fi

    # Check iPhone 16 Pro Max
    if xcrun simctl list devices available 2>/dev/null | grep -q "iPhone 16 Pro Max"; then
        log_success "iPhone 16 Pro Max simulator available"
    else
        log_failure "iPhone 16 Pro Max simulator not found"
        log_info "  Install via: Xcode > Settings > Platforms > iOS 18.1"
    fi

    # Check iPad Pro 13-inch (M4)
    if xcrun simctl list devices available 2>/dev/null | grep -q "iPad Pro 13-inch (M4)"; then
        log_success "iPad Pro 13-inch (M4) simulator available"
    else
        log_failure "iPad Pro 13-inch (M4) simulator not found"
        log_info "  Install via: Xcode > Settings > Platforms > iOS 18.1"
    fi

    # Check Apple Watch Series 10 (46mm)
    if xcrun simctl list devices available 2>/dev/null | grep -q "Apple Watch Series 10 (46mm)"; then
        log_success "Apple Watch Series 10 (46mm) simulator available"
    else
        log_failure "Apple Watch Series 10 (46mm) simulator not found"
        log_info "  Install via: Xcode > Settings > Platforms > watchOS 11.1"
    fi
}

# ==============================================================================
# Tool Checks
# ==============================================================================

check_tools() {
    log_header "Required Tools"

    # Check ImageMagick (convert command)
    if command -v convert &>/dev/null; then
        local imagemagick_version
        imagemagick_version="$(convert -version 2>/dev/null | head -1 | awk '{print $3}')"
        log_success "ImageMagick ${imagemagick_version} installed"
    else
        log_failure "ImageMagick not found"
        log_info "  Install via: brew install imagemagick"
    fi

    # Check Ruby version (3.2+)
    if command -v ruby &>/dev/null; then
        local ruby_version
        ruby_version="$(ruby --version | awk '{print $2}' | cut -dp -f1)"
        local ruby_major ruby_minor
        ruby_major="$(echo "${ruby_version}" | cut -d. -f1)"
        ruby_minor="$(echo "${ruby_version}" | cut -d. -f2)"

        if [[ "${ruby_major}" -gt 3 ]] || [[ "${ruby_major}" -eq 3 && "${ruby_minor}" -ge 2 ]]; then
            log_success "Ruby ${ruby_version} (requirement: 3.2+)"
        else
            log_failure "Ruby ${ruby_version} - Expected: 3.2 or higher"
        fi
    else
        log_failure "Ruby not found"
    fi

    # Check bundler is available
    if command -v bundle &>/dev/null; then
        log_success "Bundler installed"
    else
        log_failure "Bundler not found"
        log_info "  Install via: gem install bundler"
    fi
}

# ==============================================================================
# Bundle Dependencies Check
# ==============================================================================

check_bundle_dependencies() {
    log_header "Ruby Dependencies"

    cd "${PROJECT_ROOT}" || {
        log_failure "Cannot change to project root: ${PROJECT_ROOT}"
        return
    }

    if [[ ! -f "Gemfile" ]]; then
        log_failure "Gemfile not found in project root"
        return
    fi

    if bundle check &>/dev/null; then
        log_success "Bundle dependencies satisfied"
    else
        log_failure "Bundle dependencies not satisfied"
        log_info "  Run: bundle install"
    fi
}


# ==============================================================================
# Disk Space Check
# ==============================================================================

check_disk_space() {
    log_header "Disk Space"

    # Get free space in GB
    # df -h shows human-readable format (e.g., "15Gi", "1.5Ti")
    local free_space_raw
    free_space_raw="$(df -h "${PROJECT_ROOT}" | awk 'NR==2 {print $4}')"

    # Extract numeric value and unit
    local free_space_value unit
    free_space_value="${free_space_raw//[!0-9.]/}"
    unit="${free_space_raw//[0-9.]/}"

    # Convert to GB for comparison
    local free_gb=0
    case "${unit}" in
        Ti)
            free_gb="$(echo "${free_space_value} * 1024" | bc | cut -d. -f1)"
            ;;
        Gi|G)
            free_gb="$(echo "${free_space_value}" | cut -d. -f1)"
            ;;
        Mi|M)
            free_gb="$(echo "${free_space_value} / 1024" | bc | cut -d. -f1)"
            ;;
        *)
            log_failure "Unknown disk space unit: ${unit}"
            return
            ;;
    esac

    # Require at least 5GB free
    if [[ "${free_gb}" -ge 5 ]]; then
        log_success "Disk space: ${free_space_raw} free (requirement: 5GB+)"
    else
        log_failure "Disk space: ${free_space_raw} free - Expected: 5GB or more"
        log_info "  Screenshot generation requires significant temporary storage"
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Local Screenshot Generation - Preflight Check                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"

    # Run all checks
    check_xcode
    check_simulators
    check_tools
    check_bundle_dependencies
    check_disk_space

    # Print summary
    log_header "Summary"
    echo -e "${GREEN}Passed: ${PASS_COUNT}${NC}"
    echo -e "${RED}Failed: ${FAIL_COUNT}${NC}"

    # Exit with appropriate code
    if [[ "${FAIL_COUNT}" -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}⚠ Please fix the failed checks before proceeding with screenshot generation.${NC}"
        echo ""
        echo "For detailed setup instructions, see:"
        echo "  ${PROJECT_ROOT}/documentation/todo.localsc.md"
        echo ""
        exit 1
    else
        echo ""
        echo -e "${GREEN}✅ All checks passed! Environment ready for screenshot generation.${NC}"
        echo ""
        echo "Next steps:"
        echo "  • Generate all platforms: bundle exec fastlane ios prepare_appstore"
        echo "  • Generate iPhone only:   bundle exec fastlane ios screenshots_iphone"
        echo "  • Generate iPad only:     bundle exec fastlane ios screenshots_ipad"
        echo "  • Generate Watch only:    bundle exec fastlane ios watch_screenshots"
        echo ""
        exit 0
    fi
}

main "$@"
