#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# macOS Build Helper Script
# ==============================================================================
# Builds the ListAll macOS app with configurable options for local development
# and CI/CD environments.
#
# Features:
#   • Support for Debug and Release configurations
#   • Code signing options (signed/unsigned)
#   • Colored output with timing information
#   • xcpretty integration for clean build logs
#   • ShellCheck compliant
#
# Exit Codes:
#   0 - Build successful
#   1 - Build failed or invalid arguments
#
# Usage:
#   .github/scripts/build-macos.sh [OPTIONS]
#
# Options:
#   --config <Debug|Release>  Build configuration (default: Debug)
#   --unsigned                Disable code signing (for CI builds)
#   --verbose                 Show detailed xcodebuild output
#   --help                    Show this help message
#
# Examples:
#   # Local development (signed Debug build)
#   .github/scripts/build-macos.sh
#
#   # Release build
#   .github/scripts/build-macos.sh --config Release
#
#   # CI unsigned build
#   .github/scripts/build-macos.sh --unsigned
#
# Environment:
#   Build artifacts are written to: ./ListAll/build/
# ==============================================================================

# shellcheck disable=SC2155  # Intentional: combined declaration for script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155  # Intentional: combined declaration for script paths
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_PATH="${PROJECT_ROOT}/ListAll/ListAll.xcodeproj"
readonly SCHEME="ListAllMac"
readonly BUILD_DIR="${PROJECT_ROOT}/ListAll/build"

# ANSI color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Default options
CONFIGURATION="Debug"
UNSIGNED=false
VERBOSE=false

# ==============================================================================
# Helper Functions
# ==============================================================================

log_success() {
    echo -e "${GREEN}✅${NC} $*"
}

log_failure() {
    echo -e "${RED}❌${NC} $*"
}

log_info() {
    echo -e "${BLUE}ℹ${NC}  $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $*"
}

log_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $*${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_help() {
    head -50 "$0" | grep -E "^#( |$)" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Format seconds into human-readable duration
format_duration() {
    local total_seconds=$1
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))

    if [[ ${minutes} -gt 0 ]]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# ==============================================================================
# Validation
# ==============================================================================

validate_environment() {
    log_header "Environment Validation"

    local validation_failed=false

    # Check Xcode project exists
    if [[ ! -d "${PROJECT_PATH}" ]]; then
        log_failure "Xcode project not found: ${PROJECT_PATH}"
        validation_failed=true
    else
        log_success "Xcode project found"
    fi

    # Check xcodebuild is available
    if ! command -v xcodebuild >/dev/null 2>&1; then
        log_failure "xcodebuild not found - Xcode may not be installed"
        validation_failed=true
    else
        local xcode_version
        xcode_version="$(xcodebuild -version | head -1)"
        log_success "${xcode_version}"
    fi

    # Check xcpretty is available (optional, graceful degradation)
    if command -v xcpretty >/dev/null 2>&1; then
        log_success "xcpretty available (clean output mode)"
    else
        log_warning "xcpretty not available - using raw xcodebuild output"
        log_info "Install via: gem install xcpretty"
    fi

    # Verify scheme exists
    local schemes
    schemes=$(xcodebuild -project "${PROJECT_PATH}" -list 2>/dev/null | \
        grep -A 100 "Schemes:" | tail -n +2 | grep -v "^$" | sed 's/^[ \t]*//' || true)

    if echo "${schemes}" | grep -q "^${SCHEME}$"; then
        log_success "Scheme '${SCHEME}' found"
    else
        log_failure "Scheme '${SCHEME}' not found"
        log_info "Available schemes:"
        echo "${schemes}" | while read -r scheme; do
            echo "      - ${scheme}"
        done
        validation_failed=true
    fi

    if [[ "${validation_failed}" == "true" ]]; then
        echo ""
        log_failure "Environment validation failed"
        return 1
    fi

    echo ""
    return 0
}

# ==============================================================================
# Build Configuration
# ==============================================================================

build_macos() {
    log_header "macOS Build Configuration"

    log_info "Project:       ${PROJECT_PATH##*/}"
    log_info "Scheme:        ${SCHEME}"
    log_info "Configuration: ${CONFIGURATION}"
    log_info "Destination:   platform=macOS"
    log_info "Build output:  ${BUILD_DIR}"

    if [[ "${UNSIGNED}" == "true" ]]; then
        log_info "Code signing:  Disabled (unsigned build)"
    else
        log_info "Code signing:  Enabled"
    fi

    echo ""

    # Create build directory
    mkdir -p "${BUILD_DIR}"

    # Build xcodebuild command
    local -a xcodebuild_cmd=(
        xcodebuild
        clean build
        -project "${PROJECT_PATH}"
        -scheme "${SCHEME}"
        -destination 'platform=macOS'
        -configuration "${CONFIGURATION}"
        -derivedDataPath "${BUILD_DIR}"
    )

    # Add code signing flags if unsigned
    if [[ "${UNSIGNED}" == "true" ]]; then
        xcodebuild_cmd+=(
            CODE_SIGN_IDENTITY=""
            CODE_SIGNING_REQUIRED=NO
            CODE_SIGNING_ALLOWED=NO
        )
    fi

    # Execute build
    log_header "Building..."
    echo ""

    local build_start build_end build_duration
    build_start=$(date +%s)

    local build_exit_code=0

    # Choose output mode based on xcpretty availability and verbose flag
    if [[ "${VERBOSE}" == "true" ]]; then
        # Verbose mode: show raw xcodebuild output
        if "${xcodebuild_cmd[@]}"; then
            build_exit_code=0
        else
            build_exit_code=$?
        fi
    elif command -v xcpretty >/dev/null 2>&1; then
        # Normal mode with xcpretty: clean output
        if "${xcodebuild_cmd[@]}" 2>&1 | xcpretty --color; then
            build_exit_code=0
        else
            build_exit_code=$?
        fi
    else
        # Fallback: raw output with -quiet flag
        xcodebuild_cmd+=(-quiet)
        if "${xcodebuild_cmd[@]}"; then
            build_exit_code=0
        else
            build_exit_code=$?
        fi
    fi

    build_end=$(date +%s)
    build_duration=$((build_end - build_start))

    echo ""
    log_header "Build Result"

    if [[ ${build_exit_code} -eq 0 ]]; then
        log_success "Build succeeded in $(format_duration "${build_duration}")"
        echo ""
        log_info "Build artifacts: ${BUILD_DIR}"

        # Show built .app location
        local app_path="${BUILD_DIR}/Build/Products/${CONFIGURATION}/ListAll.app"
        if [[ -d "${app_path}" ]]; then
            log_info "Application:     ${app_path}"
        fi

        echo ""
        return 0
    else
        log_failure "Build failed in $(format_duration "${build_duration}") (exit code: ${build_exit_code})"
        echo ""
        log_info "Troubleshooting:"
        echo "      • Review build output above for specific errors"
        echo "      • Run with --verbose for detailed logs"
        echo "      • Check Xcode project settings and dependencies"
        echo "      • Verify all source files compile individually"
        echo ""
        return 1
    fi
}

# ==============================================================================
# Argument Parsing
# ==============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --config requires an argument (Debug|Release)"
                    exit 1
                fi
                CONFIGURATION="$2"
                if [[ "${CONFIGURATION}" != "Debug" && "${CONFIGURATION}" != "Release" ]]; then
                    echo "Error: Invalid configuration '${CONFIGURATION}'"
                    echo "Expected: Debug or Release"
                    exit 1
                fi
                shift 2
                ;;
            --unsigned)
                UNSIGNED=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Print header
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  ListAll macOS Build Helper                                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"

    # Validate environment
    if ! validate_environment; then
        exit 1
    fi

    # Build
    if build_macos; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
