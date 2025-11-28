#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Local Screenshot Generation Script
# =============================================================================
# Purpose: Wrapper for Fastlane screenshot generation commands
# Usage:   ./generate-screenshots-local.sh [OPTIONS] [PLATFORM] [LOCALE]
# =============================================================================

# Constants
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_ROOT

readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_GENERATION_FAILED=2
readonly EXIT_VALIDATION_FAILED=3

# Default values
PLATFORM="${1:-all}"
LOCALE="${2:-all}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# =============================================================================
# Logging Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $*" >&2
}

log_header() {
    echo ""
    echo -e "${BOLD}=== $* ===${NC}"
    echo ""
}

# =============================================================================
# Help Text
# =============================================================================

show_help() {
    cat << 'EOF'
Local Screenshot Generation Script

Usage:
    ./generate-screenshots-local.sh [OPTIONS] [PLATFORM] [LOCALE]

Description:
    Wrapper script for Fastlane screenshot generation. Generates App Store
    screenshots locally using iOS/watchOS simulators with proper dimensions
    and validation.

Arguments:
    PLATFORM    Platform to generate screenshots for
                Options: iphone, ipad, watch, all, framed
                Default: all

    LOCALE      Locale to generate screenshots for
                Options: en-US, fi, all
                Default: all

Options:
    -h, --help  Show this help message and exit

Examples:
    # Generate all platforms and locales (60-90 minutes)
    ./generate-screenshots-local.sh all

    # Generate only iPhone screenshots (20 minutes)
    ./generate-screenshots-local.sh iphone

    # Generate iPad screenshots for English only (15 minutes)
    ./generate-screenshots-local.sh ipad en-US

    # Generate Watch screenshots for all locales (20 minutes)
    ./generate-screenshots-local.sh watch

    # Generate iPhone screenshots for Finnish only (10 minutes)
    ./generate-screenshots-local.sh iphone fi

Platform Details:
    iphone  - iPhone 16 Pro Max (6.7" display, 1290x2796)
              Fastlane lane: screenshots_iphone
              Screenshots: 2 per locale
              Estimated time: ~20 minutes

    ipad    - iPad Pro 13" M4 (13" display, 2064x2752)
              Fastlane lane: screenshots_ipad
              Screenshots: 2 per locale
              Estimated time: ~35 minutes

    watch   - Apple Watch Series 10 46mm (45mm slot, 396x484)
              Fastlane lane: watch_screenshots
              Screenshots: 5 per locale
              Estimated time: ~20 minutes

    all     - All platforms (iPhone + iPad + Watch)
              Fastlane lane: prepare_appstore
              Screenshots: 9 per locale (18 total)
              Estimated time: ~60-90 minutes

    framed  - Add device frames to existing normalized screenshots
              Fastlane lane: frame_screenshots_custom
              Requires: Normalized screenshots must exist first
              Output: Marketing-ready screenshots with device bezels
              Estimated time: ~2-5 minutes

Output Locations:
    iPhone/iPad (normalized):
        fastlane/screenshots_compat/en-US/
        fastlane/screenshots_compat/fi/

    Watch (normalized):
        fastlane/screenshots/watch_normalized/en-US/
        fastlane/screenshots/watch_normalized/fi/

    Raw captures (not committed):
        fastlane/screenshots/

Prerequisites:
    - Xcode 16.1 or higher
    - iOS 18.1 simulators installed
    - watchOS 11 simulators installed
    - ImageMagick (brew install imagemagick)
    - Ruby 3.2+ with bundler
    - App Store Connect API credentials in fastlane/.env

Exit Codes:
    0   Success
    1   Invalid arguments
    2   Screenshot generation failed
    3   Screenshot validation failed

Notes:
    - Run .github/scripts/local-preflight-check.sh first to verify setup
    - Generated screenshots are validated automatically
    - Screenshots are ready to commit after successful generation
    - Use bundle exec fastlane ios release version:X.Y.Z to upload

For more information, see:
    documentation/todo.localsc.md
EOF
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_platform() {
    local platform="$1"

    case "${platform}" in
        iphone|ipad|watch|all|framed)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

validate_locale() {
    local locale="$1"

    case "${locale}" in
        en-US|fi|all)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# =============================================================================
# Cleanup Functions
# =============================================================================

cleanup_simulators() {
    log_header "Cleaning Up Simulators"

    log_info "Shutting down all running simulators..."
    xcrun simctl shutdown all 2>/dev/null || true

    # Wait briefly for shutdown to complete
    sleep 2

    log_info "Removing unavailable simulators..."
    xcrun simctl delete unavailable 2>/dev/null || true

    # Kill any hung simulator processes
    log_info "Terminating any hung simulator processes..."
    pkill -9 -f "Simulator.app" 2>/dev/null || true
    pkill -9 -f "simctl" 2>/dev/null || true

    # Wait for processes to terminate
    sleep 2

    # Verify no simulators are booted
    local booted_count
    booted_count=$(xcrun simctl list devices | grep -c "(Booted)" || echo "0")

    if [[ "${booted_count}" -gt 0 ]]; then
        log_warn "Warning: ${booted_count} simulator(s) still showing as booted"
        log_info "Attempting force shutdown..."
        xcrun simctl shutdown all 2>/dev/null || true
        sleep 2
    fi

    log_success "Simulator cleanup complete"
    echo ""
}

clean_screenshot_directories() {
    log_header "Cleaning Screenshot Directories"

    log_info "Removing old screenshots to prevent stale files..."

    # Clean screenshots_compat (iPhone/iPad normalized)
    if [[ -d "${PROJECT_ROOT}/fastlane/screenshots_compat" ]]; then
        rm -rf "${PROJECT_ROOT}/fastlane/screenshots_compat"
        log_info "Cleaned: fastlane/screenshots_compat/"
    fi

    # Clean watch_normalized
    if [[ -d "${PROJECT_ROOT}/fastlane/screenshots/watch_normalized" ]]; then
        rm -rf "${PROJECT_ROOT}/fastlane/screenshots/watch_normalized"
        log_info "Cleaned: fastlane/screenshots/watch_normalized/"
    fi

    # Clean raw screenshot directories
    rm -rf "${PROJECT_ROOT}/fastlane/screenshots/en-US" 2>/dev/null || true
    rm -rf "${PROJECT_ROOT}/fastlane/screenshots/fi" 2>/dev/null || true
    rm -rf "${PROJECT_ROOT}/fastlane/screenshots/watch" 2>/dev/null || true

    log_success "Screenshot directories cleaned"
    echo ""
}

# =============================================================================
# Screenshot Generation Functions
# =============================================================================

generate_iphone_screenshots() {
    log_info "Platform: iPhone 16 Pro Max (6.7\" display)"
    log_info "Expected output: 1290x2796 pixels"
    log_info "Screenshots: 2 per locale"
    log_info "Estimated time: ~20 minutes"
    echo ""

    if ! bundle exec fastlane ios screenshots_iphone; then
        log_error "iPhone screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}

generate_ipad_screenshots() {
    log_info "Platform: iPad Pro 13\" M4 (13\" display)"
    log_info "Expected output: 2064x2752 pixels"
    log_info "Screenshots: 2 per locale"
    log_info "Estimated time: ~35 minutes"
    echo ""

    if ! bundle exec fastlane ios screenshots_ipad; then
        log_error "iPad screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}

generate_watch_screenshots() {
    log_info "Platform: Apple Watch Series 10 46mm (45mm slot)"
    log_info "Expected output: 396x484 pixels"
    log_info "Screenshots: 5 per locale"
    log_info "Estimated time: ~20 minutes"
    echo ""

    if ! bundle exec fastlane ios watch_screenshots; then
        log_error "Watch screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}

generate_all_screenshots() {
    log_info "Platform: All (iPhone + iPad + Watch)"
    log_info "Screenshots: 9 per locale (18 total)"
    log_info "Estimated time: ~60-90 minutes"
    log_info "Mode: No device frames (raw normalized screenshots)"
    echo ""

    # Generate each platform separately to skip framing
    # (prepare_appstore lane includes frameit which we don't need)

    log_info "Step 1/3: Generating iPhone screenshots..."
    if ! bundle exec fastlane ios screenshots_iphone; then
        log_error "iPhone screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_info "Step 2/3: Generating iPad screenshots..."
    if ! bundle exec fastlane ios screenshots_ipad; then
        log_error "iPad screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_info "Step 3/3: Generating Watch screenshots..."
    if ! bundle exec fastlane ios watch_screenshots; then
        log_error "Watch screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}

generate_framed_screenshots() {
    log_info "Mode: Custom Device Framing (Marketing Screenshots)"
    log_info "Input: Normalized screenshots (must exist)"
    log_info "Output: Framed screenshots with device bezels"
    log_info "Estimated time: ~2-5 minutes"
    echo ""

    # Check that normalized screenshots exist
    if [[ ! -d "${PROJECT_ROOT}/fastlane/screenshots_compat" ]]; then
        log_error "Normalized screenshots not found at fastlane/screenshots_compat/"
        log_error "Run './generate-screenshots-local.sh all' first to generate normalized screenshots"
        return "${EXIT_GENERATION_FAILED}"
    fi

    if [[ ! -d "${PROJECT_ROOT}/fastlane/screenshots/watch_normalized" ]]; then
        log_error "Normalized Watch screenshots not found at fastlane/screenshots/watch_normalized/"
        log_error "Run './generate-screenshots-local.sh all' first to generate normalized screenshots"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_info "Running custom framing pipeline..."
    if ! bundle exec fastlane ios frame_screenshots_custom; then
        log_error "Screenshot framing failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_success "Framed screenshots generated"
    echo ""
    log_info "Output location:"
    log_info "  fastlane/screenshots_framed/ios/"
    log_info "  fastlane/screenshots_framed/watch/"

    return 0
}

# =============================================================================
# Validation
# =============================================================================

validate_screenshots() {
    log_header "Screenshot Validation"

    log_info "Validating screenshot dimensions..."
    echo ""

    if ! bundle exec fastlane ios validate_delivery_screenshots; then
        log_error "Screenshot validation failed"
        return "${EXIT_VALIDATION_FAILED}"
    fi

    log_success "All screenshots validated successfully"
    return 0
}

# =============================================================================
# Summary
# =============================================================================

show_summary() {
    local start_time="$1"
    local end_time="$2"
    local platform="$3"

    log_header "Generation Complete"

    log_success "Screenshot generation finished"
    echo ""
    echo "Start time:  ${start_time}"
    echo "End time:    ${end_time}"
    echo "Platform:    ${platform}"
    echo ""
    echo "Screenshots are ready at:"
    echo ""

    if [[ "${platform}" == "watch" ]]; then
        echo "  Watch (normalized):"
        echo "    fastlane/screenshots/watch_normalized/en-US/"
        echo "    fastlane/screenshots/watch_normalized/fi/"
    elif [[ "${platform}" == "all" ]]; then
        echo "  iPhone/iPad (normalized):"
        echo "    fastlane/screenshots_compat/en-US/"
        echo "    fastlane/screenshots_compat/fi/"
        echo ""
        echo "  Watch (normalized):"
        echo "    fastlane/screenshots/watch_normalized/en-US/"
        echo "    fastlane/screenshots/watch_normalized/fi/"
    else
        echo "  iPhone/iPad (normalized):"
        echo "    fastlane/screenshots_compat/en-US/"
        echo "    fastlane/screenshots_compat/fi/"
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Review screenshots manually"
    echo "  2. Commit to git: git add fastlane/screenshots_compat/ fastlane/screenshots/watch_normalized/"
    echo "  3. Upload to App Store: bundle exec fastlane ios release version:X.Y.Z"
    echo ""
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    # Handle help flag
    if [[ "${PLATFORM}" == "-h" ]] || [[ "${PLATFORM}" == "--help" ]]; then
        show_help
        exit "${EXIT_SUCCESS}"
    fi

    # Platform defaults to "all" if not specified

    # Validate platform
    if ! validate_platform "${PLATFORM}"; then
        log_error "Invalid platform: ${PLATFORM}"
        echo ""
        echo "Valid platforms: iphone, ipad, watch, all, framed"
        echo "Run with --help for more information"
        exit "${EXIT_INVALID_ARGS}"
    fi

    # Validate locale if provided
    if [[ -n "${LOCALE}" ]] && ! validate_locale "${LOCALE}"; then
        log_error "Invalid locale: ${LOCALE}"
        echo ""
        echo "Valid locales: en-US, fi, all"
        echo "Run with --help for more information"
        exit "${EXIT_INVALID_ARGS}"
    fi

    # Change to project root
    cd "${PROJECT_ROOT}" || {
        log_error "Failed to change to project root: ${PROJECT_ROOT}"
        exit "${EXIT_GENERATION_FAILED}"
    }

    # Record start time
    START_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
    readonly START_TIME

    log_header "Local Screenshot Generation"
    log_info "Start time: ${START_TIME}"
    log_info "Platform: ${PLATFORM}"
    log_info "Locale: ${LOCALE}"
    echo ""

    # Clean simulator state to prevent hangs from previous runs
    cleanup_simulators

    # Clean old screenshots before generating new ones
    clean_screenshot_directories

    # Generate screenshots based on platform
    case "${PLATFORM}" in
        iphone)
            log_header "iPhone Screenshot Generation"
            generate_iphone_screenshots || exit $?
            ;;
        ipad)
            log_header "iPad Screenshot Generation"
            generate_ipad_screenshots || exit $?
            ;;
        watch)
            log_header "Watch Screenshot Generation"
            generate_watch_screenshots || exit $?
            ;;
        all)
            log_header "All Platforms Screenshot Generation"
            generate_all_screenshots || exit $?
            ;;
        framed)
            log_header "Custom Screenshot Framing"
            generate_framed_screenshots || exit $?
            # Skip validation for framed mode (different dimensions)
            END_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
            readonly END_TIME
            log_success "Framed screenshot generation complete"
            exit "${EXIT_SUCCESS}"
            ;;
    esac

    # Validate screenshots
    validate_screenshots || exit $?

    # Record end time
    END_TIME="$(date '+%Y-%m-%d %H:%M:%S')"
    readonly END_TIME

    # Show summary
    show_summary "${START_TIME}" "${END_TIME}" "${PLATFORM}"

    exit "${EXIT_SUCCESS}"
}

# =============================================================================
# Script Entry Point
# =============================================================================

main "$@"
