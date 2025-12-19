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
    screenshots locally using iOS/watchOS simulators, then applies device
    frames to iPhone/iPad screenshots for a polished marketing look.
    Watch screenshots remain unframed.

Arguments:
    PLATFORM    Platform to generate screenshots for
                Options: iphone, ipad, watch, macos, all, framed
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

    # Generate macOS screenshots for all locales (5 minutes)
    ./generate-screenshots-local.sh macos

Platform Details:
    iphone  - iPhone 16 Pro Max (6.7" display, 1290x2796)
              Fastlane lane: screenshots_iphone + framing
              Screenshots: 2 per locale (framed with device bezel)
              Estimated time: ~25 minutes

    ipad    - iPad Pro 13" M4 (13" display, 2064x2752)
              Fastlane lane: screenshots_ipad + framing
              Screenshots: 2 per locale (framed with device bezel)
              Estimated time: ~40 minutes

    watch   - Apple Watch Series 10 46mm (45mm slot, 396x484)
              Fastlane lane: watch_screenshots
              Screenshots: 5 per locale (unframed)
              Estimated time: ~20 minutes

    macos   - macOS (Native, 16:10 aspect ratio, 2880x1800)
              Fastlane lane: screenshots_macos
              Screenshots: 4 per locale (unframed)
              Estimated time: ~5 minutes

    all     - All platforms (iPhone + iPad + Watch + macOS)
              Screenshots: 13 per locale (26 total)
              iPhone/iPad: framed with device bezels
              Watch/macOS: unframed
              Estimated time: ~70-100 minutes

    framed  - Re-apply device frames to existing screenshots
              Fastlane lane: frame_screenshots_custom
              Requires: Screenshots must exist in screenshots_compat/
              Output: Replaces screenshots with framed versions
              Estimated time: ~2-5 minutes

Output Locations:
    iPhone/iPad (framed with device bezels):
        fastlane/screenshots_compat/en-US/
        fastlane/screenshots_compat/fi/

    Watch (unframed):
        fastlane/screenshots/watch_normalized/en-US/
        fastlane/screenshots/watch_normalized/fi/

    macOS (unframed):
        fastlane/screenshots/mac/en-US/
        fastlane/screenshots/mac/fi/

    Raw captures (temporary, not committed):
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
        iphone|ipad|watch|macos|all|framed)
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
    booted_count=$(xcrun simctl list devices | grep -c "(Booted)" 2>/dev/null || true)
    booted_count="${booted_count:-0}"

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

    # Clean screenshots_compat (iPhone/iPad framed output)
    if [[ -d "${PROJECT_ROOT}/fastlane/screenshots_compat" ]]; then
        rm -rf "${PROJECT_ROOT}/fastlane/screenshots_compat"
        log_info "Cleaned: fastlane/screenshots_compat/"
    fi

    # Clean watch_normalized
    if [[ -d "${PROJECT_ROOT}/fastlane/screenshots/watch_normalized" ]]; then
        rm -rf "${PROJECT_ROOT}/fastlane/screenshots/watch_normalized"
        log_info "Cleaned: fastlane/screenshots/watch_normalized/"
    fi

    # Clean framed screenshots temp directory
    if [[ -d "${PROJECT_ROOT}/fastlane/screenshots_framed" ]]; then
        rm -rf "${PROJECT_ROOT}/fastlane/screenshots_framed"
        log_info "Cleaned: fastlane/screenshots_framed/"
    fi

    # Clean raw screenshot directories
    rm -rf "${PROJECT_ROOT}/fastlane/screenshots/en-US" 2>/dev/null || true
    rm -rf "${PROJECT_ROOT}/fastlane/screenshots/fi" 2>/dev/null || true
    rm -rf "${PROJECT_ROOT}/fastlane/screenshots/watch" 2>/dev/null || true

    log_success "Screenshot directories cleaned"
    echo ""
}

# =============================================================================
# Framing Functions
# =============================================================================

# Frame iPhone/iPad screenshots in-place (replace raw with framed)
# Watch screenshots are NOT framed
frame_ios_screenshots_inplace() {
    log_header "Applying Device Frames to iPhone/iPad Screenshots"

    local compat_dir="${PROJECT_ROOT}/fastlane/screenshots_compat"
    local framed_dir="${PROJECT_ROOT}/fastlane/screenshots_framed/ios"

    # Check that screenshots exist
    if [[ ! -d "${compat_dir}" ]]; then
        log_warn "No screenshots found at ${compat_dir}, skipping framing"
        return 0
    fi

    # Check for ImageMagick
    if ! command -v magick &> /dev/null; then
        log_error "ImageMagick not found. Install with: brew install imagemagick"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_info "Framing screenshots with device bezels..."
    log_info "Input: fastlane/screenshots_compat/"
    log_info "Output: Framed images will replace raw images in same location"
    echo ""

    # Run the framing lane
    if ! bundle exec fastlane ios frame_screenshots_custom; then
        log_error "Screenshot framing failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    # Copy framed images back to screenshots_compat, replacing raw
    log_info "Replacing raw screenshots with framed versions..."

    for locale_dir in "${framed_dir}"/*; do
        if [[ -d "${locale_dir}" ]]; then
            local locale
            locale="$(basename "${locale_dir}")"
            local target_dir="${compat_dir}/${locale}"

            if [[ -d "${target_dir}" ]]; then
                for framed_file in "${locale_dir}"/*.png; do
                    if [[ -f "${framed_file}" ]]; then
                        local filename
                        filename="$(basename "${framed_file}")"
                        cp "${framed_file}" "${target_dir}/${filename}"
                        log_info "  Replaced: ${locale}/${filename}"
                    fi
                done
            fi
        fi
    done

    # Clean up framed directory
    rm -rf "${PROJECT_ROOT}/fastlane/screenshots_framed"
    log_info "Cleaned up temporary framed directory"

    log_success "Device frames applied to all iPhone/iPad screenshots"
    echo ""

    return 0
}

# =============================================================================
# macOS Helper Functions
# =============================================================================

hide_and_quit_background_apps_macos() {
    log_info "Preparing macOS desktop for clean screenshots..."

    # Check if osascript is available
    if ! command -v osascript &> /dev/null; then
        log_warn "osascript not found - skipping app cleanup (may result in cluttered screenshots)"
        return 0
    fi

    # STEP 1: Quit non-essential applications completely
    # This is more reliable than hiding - apps stay closed
    log_info "Closing non-essential applications..."

    osascript <<'EOF' 2>/dev/null || true
tell application "System Events"
    set appList to name of every process whose background only is false
    repeat with appName in appList
        -- Skip essential system processes and apps we need
        -- Use pattern matching (contains) instead of exact names for test runner variants
        set shouldSkip to false

        -- Skip system essentials
        if appName is in {"Finder", "SystemUIServer", "Dock", "Terminal"} then
            set shouldSkip to true
        end if

        -- Skip Xcode and related tools (pattern matching)
        if appName contains "Xcode" or appName contains "xcode" then
            set shouldSkip to true
        end if

        -- Skip test runners (pattern matching for various test runner names)
        if appName contains "xctest" or appName contains "XCTest" or appName contains "xctrunner" or appName contains "XCTRunner" then
            set shouldSkip to true
        end if

        -- Skip xcodebuild
        if appName contains "xcodebuild" then
            set shouldSkip to true
        end if

        -- Skip Simulator (important - tests run in simulator context)
        if appName contains "Simulator" then
            set shouldSkip to true
        end if

        -- Skip ListAll app (the app being tested - must not be quit!)
        if appName contains "ListAll" then
            set shouldSkip to true
        end if

        if shouldSkip is false then
            try
                -- Quit apps that can be quit (ignoring errors for system apps)
                tell process appName to quit
            end try
        end if
    end repeat
end tell
EOF

    log_info "Waiting for applications to quit (3 seconds)..."
    sleep 3

    # STEP 2: Hide any remaining visible apps (for apps that can't be quit)
    # This targets apps that refused to quit or are system components
    log_info "Hiding remaining visible applications..."

    osascript <<'EOF' 2>/dev/null || true
tell application "System Events"
    -- Use proper AppleScript syntax with repeat loop
    -- (the "name is not in {list}" one-liner syntax doesn't work)
    repeat with p in (get every process whose visible is true)
        set appName to name of p
        if appName is not in {"Finder", "SystemUIServer", "Dock", "Terminal"} then
            -- Also skip test-related and ListAll processes
            if appName does not contain "Xcode" and appName does not contain "xctest" and appName does not contain "ListAll" then
                try
                    set visible of p to false
                end try
            end if
        end if
    end repeat
end tell
EOF

    log_info "Waiting for hide animations to complete (2 seconds)..."
    sleep 2

    # STEP 3: Minimize Finder windows to clear desktop
    log_info "Minimizing Finder windows..."

    osascript <<'EOF' 2>/dev/null || true
tell application "Finder"
    set miniaturized of every window to true
end tell
EOF

    sleep 1

    log_success "Desktop prepared for screenshots"
    log_info "Current state: All non-essential apps closed/hidden, desktop clear"

    return 0
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

generate_macos_screenshots() {
    log_info "Platform: macOS (Native)"
    log_info "Expected output: 2880x1800 pixels"
    log_info "Screenshots: 4 per locale (01_MainWindow, 02_ListDetailView, 03_ItemEditSheet, 04_SettingsWindow)"
    log_info "Estimated time: ~5 minutes"
    echo ""

    # Prepare desktop for clean screenshots BEFORE launching app
    # This closes/hides all non-essential apps and clears the desktop
    hide_and_quit_background_apps_macos

    # Now launch fastlane to run tests and take screenshots
    # The tests should NOT try to hide apps - just activate ListAll to foreground
    if ! bundle exec fastlane ios screenshots_macos; then
        log_error "macOS screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}

generate_all_screenshots() {
    log_info "Platform: All (iPhone + iPad + Watch + macOS)"
    log_info "Screenshots: 13 per locale (26 total)"
    log_info "Estimated time: ~70-100 minutes"
    log_info "Mode: iPhone/iPad with device frames, Watch/macOS unframed"
    echo ""

    log_info "Step 1/5: Generating iPhone screenshots..."
    if ! bundle exec fastlane ios screenshots_iphone; then
        log_error "iPhone screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_info "Step 2/5: Generating iPad screenshots..."
    if ! bundle exec fastlane ios screenshots_ipad; then
        log_error "iPad screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_info "Step 3/5: Applying device frames to iPhone/iPad..."
    if ! frame_ios_screenshots_inplace; then
        log_error "Screenshot framing failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_info "Step 4/5: Generating Watch screenshots (unframed)..."
    if ! bundle exec fastlane ios watch_screenshots; then
        log_error "Watch screenshot generation failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_info "Step 5/5: Generating macOS screenshots (unframed)..."
    # Use helper function to ensure background apps are hidden
    if ! generate_macos_screenshots; then
        return "${EXIT_GENERATION_FAILED}"
    fi

    return 0
}

generate_framed_screenshots() {
    log_info "Mode: Re-apply Device Frames to Existing Screenshots"
    log_info "Input: Screenshots in fastlane/screenshots_compat/"
    log_info "Output: Framed versions replace originals in same location"
    log_info "Estimated time: ~2-5 minutes"
    echo ""

    # Check that screenshots exist
    if [[ ! -d "${PROJECT_ROOT}/fastlane/screenshots_compat" ]]; then
        log_error "Screenshots not found at fastlane/screenshots_compat/"
        log_error "Run './generate-screenshots-local.sh all' first to generate screenshots"
        return "${EXIT_GENERATION_FAILED}"
    fi

    # Apply framing in-place
    if ! frame_ios_screenshots_inplace; then
        log_error "Screenshot framing failed"
        return "${EXIT_GENERATION_FAILED}"
    fi

    log_success "Framed screenshots generated"
    echo ""
    log_info "Output location (same as input, replaced in-place):"
    log_info "  fastlane/screenshots_compat/en-US/"
    log_info "  fastlane/screenshots_compat/fi/"

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
        echo "  Watch (unframed):"
        echo "    fastlane/screenshots/watch_normalized/en-US/"
        echo "    fastlane/screenshots/watch_normalized/fi/"
    elif [[ "${platform}" == "macos" ]]; then
        echo "  macOS (unframed):"
        echo "    fastlane/screenshots/mac/en-US/"
        echo "    fastlane/screenshots/mac/fi/"
    elif [[ "${platform}" == "all" ]]; then
        echo "  iPhone/iPad (framed with device bezels):"
        echo "    fastlane/screenshots_compat/en-US/"
        echo "    fastlane/screenshots_compat/fi/"
        echo ""
        echo "  Watch (unframed):"
        echo "    fastlane/screenshots/watch_normalized/en-US/"
        echo "    fastlane/screenshots/watch_normalized/fi/"
        echo ""
        echo "  macOS (unframed):"
        echo "    fastlane/screenshots/mac/en-US/"
        echo "    fastlane/screenshots/mac/fi/"
    else
        echo "  iPhone/iPad (framed with device bezels):"
        echo "    fastlane/screenshots_compat/en-US/"
        echo "    fastlane/screenshots_compat/fi/"
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Review screenshots manually"
    echo "  2. Commit to git: git add fastlane/screenshots_compat/ fastlane/screenshots/watch_normalized/ fastlane/screenshots/mac_normalized/"
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
        echo "Valid platforms: iphone, ipad, watch, macos, all, framed"
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

    # For framed mode, skip cleanup since we need existing screenshots
    if [[ "${PLATFORM}" != "framed" ]]; then
        # Clean simulator state to prevent hangs from previous runs
        cleanup_simulators

        # Clean old screenshots before generating new ones
        clean_screenshot_directories
    fi

    # Generate screenshots based on platform
    case "${PLATFORM}" in
        iphone)
            log_header "iPhone Screenshot Generation"
            generate_iphone_screenshots || exit $?
            frame_ios_screenshots_inplace || exit $?
            ;;
        ipad)
            log_header "iPad Screenshot Generation"
            generate_ipad_screenshots || exit $?
            frame_ios_screenshots_inplace || exit $?
            ;;
        watch)
            log_header "Watch Screenshot Generation (Unframed)"
            generate_watch_screenshots || exit $?
            ;;
        macos)
            log_header "macOS Screenshot Generation (Unframed)"
            generate_macos_screenshots || exit $?
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
