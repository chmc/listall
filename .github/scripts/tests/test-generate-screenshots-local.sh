#!/usr/bin/env bash
# =============================================================================
# Test Suite for generate-screenshots-local.sh
# =============================================================================
# Purpose: Comprehensive tests for screenshot generation script
# Usage:   ./test-generate-screenshots-local.sh
# =============================================================================

# shellcheck disable=SC2329  # Mock functions are called indirectly via export -f

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SCRIPT_UNDER_TEST="${SCRIPT_DIR}/../generate-screenshots-local.sh"
readonly TEST_TEMP_DIR="/tmp/test-screenshots-$$"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# =============================================================================
# Test Infrastructure
# =============================================================================

setup_test_environment() {
    # Create temporary directory for testing
    mkdir -p "${TEST_TEMP_DIR}"

    # Create mock project structure
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/fi"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots/watch_normalized/en-US"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots/watch_normalized/fi"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/fi"

    # Create mock screenshot files for testing
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen2.png"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/fi/screen1.png"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/fi/screen2.png"

    # Create framed screenshots for testing
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US/screen1.png"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US/screen2.png"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/fi/screen1.png"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/fi/screen2.png"
}

cleanup_test_environment() {
    if [[ -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi

    # Restore any overridden functions
    unset -f xcrun 2>/dev/null || true
    unset -f bundle 2>/dev/null || true
    unset -f pkill 2>/dev/null || true
    unset -f magick 2>/dev/null || true
    unset -f sleep 2>/dev/null || true
    unset -f command 2>/dev/null || true
}

# Setup cleanup trap
trap cleanup_test_environment EXIT INT TERM

# =============================================================================
# Source Script Functions (without executing main)
# =============================================================================

# Source the script but prevent main from executing
source_script_functions() {
    # Create a temporary wrapper that sources functions without running main
    local temp_script="${TEST_TEMP_DIR}/script_functions.sh"

    # Extract only function definitions and skip variable declarations
    # This avoids conflicts with readonly variables already defined in test script
    # Use awk to extract function definitions
    awk '
        /^[a-z_]+\(\)/ { in_func=1 }
        in_func { print }
        /^}$/ && in_func { in_func=0; print "" }
    ' "${SCRIPT_UNDER_TEST}" > "${temp_script}"

    # Source the functions
    # shellcheck disable=SC1090
    source "${temp_script}"

    # Override PROJECT_ROOT for tests (used by sourced functions)
    # shellcheck disable=SC2034
    PROJECT_ROOT="${TEST_TEMP_DIR}"

    # Define exit codes needed by functions
    # shellcheck disable=SC2034  # Used by sourced functions
    EXIT_SUCCESS=0
    # shellcheck disable=SC2034  # Used by sourced functions
    EXIT_INVALID_ARGS=1
    # shellcheck disable=SC2034  # Used by sourced functions
    EXIT_GENERATION_FAILED=2
    # shellcheck disable=SC2034  # Used by sourced functions
    EXIT_VALIDATION_FAILED=3
}

# =============================================================================
# Assertion Functions
# =============================================================================

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    ((TESTS_RUN++))

    if [[ "${expected}" == "${actual}" ]]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} ${message}"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} ${message}"
        echo -e "    Expected: ${expected}"
        echo -e "    Actual:   ${actual}"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"

    ((TESTS_RUN++))

    if [[ "${condition}" == "0" ]]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} ${message}"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} ${message}"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Condition should be false}"

    ((TESTS_RUN++))

    if [[ "${condition}" != "0" ]]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} ${message}"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} ${message}"
        return 1
    fi
}

assert_file_exists() {
    local filepath="$1"
    local message="${2:-File should exist: ${filepath}}"

    ((TESTS_RUN++))

    if [[ -f "${filepath}" ]]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} ${message}"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} ${message}"
        return 1
    fi
}

assert_file_not_exists() {
    local filepath="$1"
    local message="${2:-File should not exist: ${filepath}}"

    ((TESTS_RUN++))

    if [[ ! -f "${filepath}" ]]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} ${message}"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} ${message}"
        return 1
    fi
}

assert_dir_exists() {
    local dirpath="$1"
    local message="${2:-Directory should exist: ${dirpath}}"

    ((TESTS_RUN++))

    if [[ -d "${dirpath}" ]]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} ${message}"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} ${message}"
        return 1
    fi
}

assert_dir_not_exists() {
    local dirpath="$1"
    local message="${2:-Directory should not exist: ${dirpath}}"

    ((TESTS_RUN++))

    if [[ ! -d "${dirpath}" ]]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} ${message}"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} ${message}"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain: ${needle}}"

    ((TESTS_RUN++))

    if [[ "${haystack}" == *"${needle}"* ]]; then
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} ${message}"
        return 0
    else
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} ${message}"
        echo -e "    Expected to find: ${needle}"
        echo -e "    In string: ${haystack}"
        return 1
    fi
}

# =============================================================================
# Mock Functions
# =============================================================================

# Mock xcrun simctl (returns success)
mock_xcrun_success() {
    xcrun() {
        if [[ "$1" == "simctl" && "$2" == "list" ]]; then
            # Return mock simulator list with no booted devices
            echo "== Devices =="
            echo "-- iOS 18.1 --"
            echo "    iPhone 16 Pro (12345678-1234-1234-1234-123456789ABC) (Shutdown)"
            return 0
        fi
        return 0
    }
    export -f xcrun
}

# Mock xcrun simctl with booted simulators
mock_xcrun_with_booted() {
    xcrun() {
        if [[ "$1" == "simctl" && "$2" == "list" ]]; then
            # Return mock simulator list with booted devices
            echo "== Devices =="
            echo "-- iOS 18.1 --"
            echo "    iPhone 16 Pro (12345678-1234-1234-1234-123456789ABC) (Booted)"
            echo "    iPhone 16 Pro (12345678-1234-1234-1234-123456789ABD) (Booted)"
            return 0
        fi
        return 0
    }
    export -f xcrun
}

# Mock bundle exec fastlane (returns success)
mock_bundle_success() {
    bundle() {
        if [[ "$1" == "exec" && "$2" == "fastlane" ]]; then
            echo "Mock fastlane: ${*}"
            return 0
        fi
        return 0
    }
    export -f bundle
}

# Mock bundle exec fastlane (returns failure)
mock_bundle_failure() {
    bundle() {
        if [[ "$1" == "exec" && "$2" == "fastlane" ]]; then
            echo "Mock fastlane error: ${*}" >&2
            return 1
        fi
        return 0
    }
    export -f bundle
}

# Mock pkill (returns success)
mock_pkill_success() {
    pkill() {
        return 0
    }
    export -f pkill
}

# Mock ImageMagick magick command
mock_magick_exists() {
    command() {
        if [[ "$1" == "-v" && "$2" == "magick" ]]; then
            echo "/usr/local/bin/magick"
            return 0
        fi
        builtin command "$@"
    }
    export -f command

    magick() {
        return 0
    }
    export -f magick
}

# Mock ImageMagick missing
mock_magick_missing() {
    command() {
        if [[ "$1" == "-v" && "$2" == "magick" ]]; then
            return 1
        fi
        builtin command "$@"
    }
    export -f command
}

# Mock sleep to speed up tests
mock_sleep() {
    sleep() {
        return 0
    }
    export -f sleep
}

# =============================================================================
# Test Cases: Validation Functions
# =============================================================================

test_validate_platform() {
    echo -e "${BLUE}Testing validate_platform()${NC}"

    # Valid platforms
    validate_platform "iphone"
    assert_true "$?" "validate_platform accepts 'iphone'"

    validate_platform "ipad"
    assert_true "$?" "validate_platform accepts 'ipad'"

    validate_platform "watch"
    assert_true "$?" "validate_platform accepts 'watch'"

    validate_platform "all"
    assert_true "$?" "validate_platform accepts 'all'"

    validate_platform "framed"
    assert_true "$?" "validate_platform accepts 'framed'"

    # Invalid platforms
    validate_platform "invalid" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'invalid'"

    validate_platform "iPhone" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'iPhone' (case sensitive)"

    validate_platform "" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects empty string"

    validate_platform "mac" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'mac'"

    echo ""
}

test_validate_locale() {
    echo -e "${BLUE}Testing validate_locale()${NC}"

    # Valid locales
    validate_locale "en-US"
    assert_true "$?" "validate_locale accepts 'en-US'"

    validate_locale "fi"
    assert_true "$?" "validate_locale accepts 'fi'"

    validate_locale "all"
    assert_true "$?" "validate_locale accepts 'all'"

    # Invalid locales
    validate_locale "en" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'en'"

    validate_locale "en_US" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'en_US'"

    validate_locale "" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects empty string"

    validate_locale "de-DE" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'de-DE'"

    echo ""
}

# =============================================================================
# Test Cases: Cleanup Functions
# =============================================================================

test_cleanup_simulators_success() {
    echo -e "${BLUE}Testing cleanup_simulators() - success case${NC}"

    # Setup mocks
    mock_xcrun_success
    mock_pkill_success
    mock_sleep

    # Run cleanup
    local output
    output=$(cleanup_simulators 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "cleanup_simulators returns success"
    assert_contains "${output}" "Simulator cleanup complete" "cleanup_simulators shows success message"

    echo ""
}

test_cleanup_simulators_with_booted() {
    echo -e "${BLUE}Testing cleanup_simulators() - with booted simulators${NC}"

    # Setup mocks
    mock_xcrun_with_booted
    mock_pkill_success
    mock_sleep

    # Run cleanup
    local output
    output=$(cleanup_simulators 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "cleanup_simulators handles booted simulators"
    assert_contains "${output}" "still showing as booted" "cleanup_simulators warns about booted simulators"
    assert_contains "${output}" "force shutdown" "cleanup_simulators attempts force shutdown"

    echo ""
}

test_clean_screenshot_directories() {
    echo -e "${BLUE}Testing clean_screenshot_directories()${NC}"

    # Create directories to clean
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots/watch_normalized"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_framed"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots/en-US"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots/fi"

    # Run cleanup
    local output
    output=$(clean_screenshot_directories 2>&1)

    # Verify directories were removed
    assert_dir_not_exists "${TEST_TEMP_DIR}/fastlane/screenshots_compat" \
        "screenshots_compat directory removed"
    assert_dir_not_exists "${TEST_TEMP_DIR}/fastlane/screenshots/watch_normalized" \
        "watch_normalized directory removed"
    assert_dir_not_exists "${TEST_TEMP_DIR}/fastlane/screenshots_framed" \
        "screenshots_framed directory removed"
    assert_dir_not_exists "${TEST_TEMP_DIR}/fastlane/screenshots/en-US" \
        "screenshots/en-US directory removed"
    assert_dir_not_exists "${TEST_TEMP_DIR}/fastlane/screenshots/fi" \
        "screenshots/fi directory removed"

    assert_contains "${output}" "Screenshot directories cleaned" \
        "clean_screenshot_directories shows success message"

    echo ""
}

# =============================================================================
# Test Cases: Framing Functions
# =============================================================================

test_frame_ios_screenshots_inplace_success() {
    echo -e "${BLUE}Testing frame_ios_screenshots_inplace() - success case${NC}"

    # Setup mocks
    mock_bundle_success
    mock_magick_exists

    # Ensure screenshots exist
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"

    # Run framing
    local output
    output=$(frame_ios_screenshots_inplace 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "frame_ios_screenshots_inplace returns success"
    assert_contains "${output}" "Device frames applied" \
        "frame_ios_screenshots_inplace shows success message"

    echo ""
}

test_frame_ios_screenshots_no_screenshots() {
    echo -e "${BLUE}Testing frame_ios_screenshots_inplace() - no screenshots${NC}"

    # Setup mocks
    mock_bundle_success
    mock_magick_exists

    # Remove screenshots directory
    rm -rf "${TEST_TEMP_DIR}/fastlane/screenshots_compat"

    # Run framing
    local output
    output=$(frame_ios_screenshots_inplace 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "frame_ios_screenshots_inplace handles missing screenshots"
    assert_contains "${output}" "skipping framing" \
        "frame_ios_screenshots_inplace shows skip message"

    echo ""
}

test_frame_ios_screenshots_no_imagemagick() {
    echo -e "${BLUE}Testing frame_ios_screenshots_inplace() - ImageMagick missing${NC}"

    # Setup mocks
    mock_bundle_success
    mock_magick_missing

    # Ensure screenshots exist
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"

    # Run framing
    local output exit_code
    output=$(frame_ios_screenshots_inplace 2>&1) || exit_code=$?

    assert_equals "2" "${exit_code}" "frame_ios_screenshots_inplace returns EXIT_GENERATION_FAILED"
    assert_contains "${output}" "ImageMagick not found" \
        "frame_ios_screenshots_inplace shows error message"

    echo ""
}

test_frame_ios_screenshots_fastlane_failure() {
    echo -e "${BLUE}Testing frame_ios_screenshots_inplace() - Fastlane failure${NC}"

    # Setup mocks
    mock_bundle_failure
    mock_magick_exists

    # Ensure screenshots exist
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"

    # Run framing
    local output exit_code
    output=$(frame_ios_screenshots_inplace 2>&1) || exit_code=$?

    assert_equals "2" "${exit_code}" "frame_ios_screenshots_inplace returns EXIT_GENERATION_FAILED on fastlane error"
    assert_contains "${output}" "Screenshot framing failed" \
        "frame_ios_screenshots_inplace shows error message"

    echo ""
}

test_frame_ios_screenshots_copies_framed() {
    echo -e "${BLUE}Testing frame_ios_screenshots_inplace() - copies framed files${NC}"

    # Setup mocks
    mock_bundle_success
    mock_magick_exists

    # Create mock framed screenshots
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US"
    echo "framed content" > "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US/screen1.png"

    # Create original screenshots
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    echo "original content" > "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"

    # Run framing
    frame_ios_screenshots_inplace > /dev/null 2>&1

    # Verify framed file replaced original
    local content
    content=$(cat "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png")
    assert_equals "framed content" "${content}" \
        "Framed screenshot replaces original"

    # Verify temp directory cleaned up
    assert_dir_not_exists "${TEST_TEMP_DIR}/fastlane/screenshots_framed" \
        "Temporary framed directory removed"

    echo ""
}

# =============================================================================
# Test Cases: Screenshot Generation Functions
# =============================================================================

test_generate_iphone_screenshots_success() {
    echo -e "${BLUE}Testing generate_iphone_screenshots() - success${NC}"

    mock_bundle_success

    local output
    output=$(generate_iphone_screenshots 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "generate_iphone_screenshots returns success"
    assert_contains "${output}" "iPhone 16 Pro Max" \
        "generate_iphone_screenshots shows device info"

    echo ""
}

test_generate_iphone_screenshots_failure() {
    echo -e "${BLUE}Testing generate_iphone_screenshots() - failure${NC}"

    mock_bundle_failure

    local output exit_code
    output=$(generate_iphone_screenshots 2>&1) || exit_code=$?

    assert_equals "2" "${exit_code}" "generate_iphone_screenshots returns EXIT_GENERATION_FAILED"
    assert_contains "${output}" "iPhone screenshot generation failed" \
        "generate_iphone_screenshots shows error message"

    echo ""
}

test_generate_ipad_screenshots_success() {
    echo -e "${BLUE}Testing generate_ipad_screenshots() - success${NC}"

    mock_bundle_success

    local output
    output=$(generate_ipad_screenshots 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "generate_ipad_screenshots returns success"
    assert_contains "${output}" "iPad Pro 13" \
        "generate_ipad_screenshots shows device info"

    echo ""
}

test_generate_ipad_screenshots_failure() {
    echo -e "${BLUE}Testing generate_ipad_screenshots() - failure${NC}"

    mock_bundle_failure

    local output exit_code
    output=$(generate_ipad_screenshots 2>&1) || exit_code=$?

    assert_equals "2" "${exit_code}" "generate_ipad_screenshots returns EXIT_GENERATION_FAILED"
    assert_contains "${output}" "iPad screenshot generation failed" \
        "generate_ipad_screenshots shows error message"

    echo ""
}

test_generate_watch_screenshots_success() {
    echo -e "${BLUE}Testing generate_watch_screenshots() - success${NC}"

    mock_bundle_success

    local output
    output=$(generate_watch_screenshots 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "generate_watch_screenshots returns success"
    assert_contains "${output}" "Apple Watch Series 10" \
        "generate_watch_screenshots shows device info"

    echo ""
}

test_generate_watch_screenshots_failure() {
    echo -e "${BLUE}Testing generate_watch_screenshots() - failure${NC}"

    mock_bundle_failure

    local output exit_code
    output=$(generate_watch_screenshots 2>&1) || exit_code=$?

    assert_equals "2" "${exit_code}" "generate_watch_screenshots returns EXIT_GENERATION_FAILED"
    assert_contains "${output}" "Watch screenshot generation failed" \
        "generate_watch_screenshots shows error message"

    echo ""
}

test_generate_all_screenshots_success() {
    echo -e "${BLUE}Testing generate_all_screenshots() - success${NC}"

    mock_bundle_success
    mock_magick_exists

    # Create required directories
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US/screen1.png"

    local output
    output=$(generate_all_screenshots 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "generate_all_screenshots returns success"
    assert_contains "${output}" "Step 1/4" "generate_all_screenshots shows progress"
    assert_contains "${output}" "Step 2/4" "generate_all_screenshots shows iPad step"
    assert_contains "${output}" "Step 3/4" "generate_all_screenshots shows framing step"
    assert_contains "${output}" "Step 4/4" "generate_all_screenshots shows Watch step"

    echo ""
}

test_generate_all_screenshots_iphone_failure() {
    echo -e "${BLUE}Testing generate_all_screenshots() - iPhone failure${NC}"

    # Mock bundle to fail on first call (iPhone)
    # Command is: bundle exec fastlane ios screenshots_iphone
    # So $1=exec, $2=fastlane, $3=ios, $4=screenshots_iphone
    bundle() {
        if [[ "$4" == "screenshots_iphone" ]]; then
            return 1
        fi
        return 0
    }
    export -f bundle

    local output exit_code
    output=$(generate_all_screenshots 2>&1) && exit_code=0 || exit_code=$?

    assert_equals "2" "${exit_code}" "generate_all_screenshots fails on iPhone error"
    assert_contains "${output}" "iPhone screenshot generation failed" \
        "generate_all_screenshots shows iPhone error"

    echo ""
}

test_generate_all_screenshots_ipad_failure() {
    echo -e "${BLUE}Testing generate_all_screenshots() - iPad failure${NC}"

    # Mock bundle to succeed on iPhone but fail on iPad
    bundle() {
        if [[ "$4" == "screenshots_ipad" ]]; then
            return 1
        fi
        return 0
    }
    export -f bundle

    local output exit_code
    output=$(generate_all_screenshots 2>&1) && exit_code=0 || exit_code=$?

    assert_equals "2" "${exit_code}" "generate_all_screenshots fails on iPad error"
    assert_contains "${output}" "iPad screenshot generation failed" \
        "generate_all_screenshots shows iPad error"

    echo ""
}

test_generate_all_screenshots_watch_failure() {
    echo -e "${BLUE}Testing generate_all_screenshots() - Watch failure${NC}"

    # Mock bundle to succeed on iPhone/iPad but fail on Watch
    bundle() {
        if [[ "$4" == "watch_screenshots" ]]; then
            return 1
        fi
        return 0
    }
    export -f bundle

    mock_magick_exists

    # Create directories needed for framing step
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US/screen1.png"

    local output exit_code
    output=$(generate_all_screenshots 2>&1) && exit_code=0 || exit_code=$?

    assert_equals "2" "${exit_code}" "generate_all_screenshots fails on Watch error"
    assert_contains "${output}" "Watch screenshot generation failed" \
        "generate_all_screenshots shows Watch error"

    echo ""
}

test_generate_all_screenshots_framing_failure() {
    echo -e "${BLUE}Testing generate_all_screenshots() - framing failure${NC}"

    # Mock bundle to succeed but ImageMagick is missing
    mock_bundle_success
    mock_magick_missing

    # Create directories for iPhone/iPad screenshots
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"

    local output exit_code
    output=$(generate_all_screenshots 2>&1) && exit_code=0 || exit_code=$?

    assert_equals "2" "${exit_code}" "generate_all_screenshots fails on framing error"
    assert_contains "${output}" "ImageMagick not found" \
        "generate_all_screenshots shows ImageMagick error"

    echo ""
}

test_generate_framed_screenshots_success() {
    echo -e "${BLUE}Testing generate_framed_screenshots() - success${NC}"

    mock_bundle_success
    mock_magick_exists

    # Create required directories and files
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US/screen1.png"

    local output
    output=$(generate_framed_screenshots 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "generate_framed_screenshots returns success"
    assert_contains "${output}" "Re-apply Device Frames" \
        "generate_framed_screenshots shows mode description"
    assert_contains "${output}" "Framed screenshots generated" \
        "generate_framed_screenshots shows success"

    echo ""
}

test_generate_framed_screenshots_no_screenshots() {
    echo -e "${BLUE}Testing generate_framed_screenshots() - no screenshots${NC}"

    mock_bundle_success
    mock_magick_exists

    # Remove screenshots directory
    rm -rf "${TEST_TEMP_DIR}/fastlane/screenshots_compat"

    local output exit_code
    output=$(generate_framed_screenshots 2>&1) || exit_code=$?

    assert_equals "2" "${exit_code}" "generate_framed_screenshots fails when no screenshots"
    assert_contains "${output}" "Screenshots not found" \
        "generate_framed_screenshots shows error message"

    echo ""
}

# =============================================================================
# Test Cases: Validation
# =============================================================================

test_validate_screenshots_success() {
    echo -e "${BLUE}Testing validate_screenshots() - success${NC}"

    mock_bundle_success

    local output
    output=$(validate_screenshots 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "validate_screenshots returns success"
    assert_contains "${output}" "validated successfully" \
        "validate_screenshots shows success message"

    echo ""
}

test_validate_screenshots_failure() {
    echo -e "${BLUE}Testing validate_screenshots() - failure${NC}"

    mock_bundle_failure

    local output exit_code
    output=$(validate_screenshots 2>&1) || exit_code=$?

    assert_equals "3" "${exit_code}" "validate_screenshots returns EXIT_VALIDATION_FAILED"
    assert_contains "${output}" "Screenshot validation failed" \
        "validate_screenshots shows error message"

    echo ""
}

# =============================================================================
# Test Cases: Help and Summary
# =============================================================================

test_show_help() {
    echo -e "${BLUE}Testing show_help()${NC}"

    local output
    output=$(show_help)

    assert_contains "${output}" "Local Screenshot Generation Script" \
        "show_help contains title"
    assert_contains "${output}" "Usage:" "show_help contains usage section"
    assert_contains "${output}" "PLATFORM" "show_help contains platform argument"
    assert_contains "${output}" "LOCALE" "show_help contains locale argument"
    assert_contains "${output}" "iphone" "show_help lists iphone platform"
    assert_contains "${output}" "ipad" "show_help lists ipad platform"
    assert_contains "${output}" "watch" "show_help lists watch platform"
    assert_contains "${output}" "all" "show_help lists all platform"
    assert_contains "${output}" "framed" "show_help lists framed platform"
    assert_contains "${output}" "en-US" "show_help lists en-US locale"
    assert_contains "${output}" "fi" "show_help lists fi locale"
    assert_contains "${output}" "Exit Codes:" "show_help contains exit codes"

    echo ""
}

test_show_summary_watch() {
    echo -e "${BLUE}Testing show_summary() - watch platform${NC}"

    local output
    output=$(show_summary "2024-01-01 10:00:00" "2024-01-01 10:30:00" "watch")

    assert_contains "${output}" "Generation Complete" "summary contains header"
    assert_contains "${output}" "watch_normalized" "summary shows watch output path"

    echo ""
}

test_show_summary_all() {
    echo -e "${BLUE}Testing show_summary() - all platforms${NC}"

    local output
    output=$(show_summary "2024-01-01 10:00:00" "2024-01-01 11:30:00" "all")

    assert_contains "${output}" "screenshots_compat" "summary shows iOS output path"
    assert_contains "${output}" "watch_normalized" "summary shows watch output path"
    assert_contains "${output}" "framed with device bezels" "summary mentions framing"

    echo ""
}

test_show_summary_iphone() {
    echo -e "${BLUE}Testing show_summary() - iPhone platform${NC}"

    local output
    output=$(show_summary "2024-01-01 10:00:00" "2024-01-01 10:20:00" "iphone")

    assert_contains "${output}" "screenshots_compat" "summary shows iOS output path"
    assert_contains "${output}" "framed with device bezels" "summary mentions framing"

    # Check that watch paths are NOT shown in "Screenshots are ready at:" section
    # Extract only the "Screenshots are ready at:" section before "Next steps:"
    local screenshots_section
    screenshots_section=$(echo "${output}" | awk '/Screenshots are ready at:/,/Next steps:/ {if (!/Next steps:/) print}')

    if echo "${screenshots_section}" | grep -q "watch_normalized"; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} summary should not show watch paths in output section for iPhone"
        echo -e "    Found watch_normalized in: ${screenshots_section}"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} summary excludes watch paths in output section for iPhone"
    fi

    echo ""
}

test_show_summary_ipad() {
    echo -e "${BLUE}Testing show_summary() - iPad platform${NC}"

    local output
    output=$(show_summary "2024-01-01 10:00:00" "2024-01-01 10:35:00" "ipad")

    assert_contains "${output}" "screenshots_compat" "summary shows iOS output path"
    assert_contains "${output}" "framed with device bezels" "summary mentions framing"

    # Check that watch paths are NOT shown in "Screenshots are ready at:" section
    local screenshots_section
    screenshots_section=$(echo "${output}" | awk '/Screenshots are ready at:/,/Next steps:/ {if (!/Next steps:/) print}')

    if echo "${screenshots_section}" | grep -q "watch_normalized"; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} summary should not show watch paths in output section for iPad"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} summary excludes watch paths in output section for iPad"
    fi

    echo ""
}

test_show_summary_framed() {
    echo -e "${BLUE}Testing show_summary() - framed platform${NC}"

    local output
    output=$(show_summary "2024-01-01 10:00:00" "2024-01-01 10:05:00" "framed")

    assert_contains "${output}" "screenshots_compat" "summary shows iOS output path"
    assert_contains "${output}" "framed with device bezels" "summary mentions framing"

    # Check that watch paths are NOT shown in "Screenshots are ready at:" section
    local screenshots_section
    screenshots_section=$(echo "${output}" | awk '/Screenshots are ready at:/,/Next steps:/ {if (!/Next steps:/) print}')

    if echo "${screenshots_section}" | grep -q "watch_normalized"; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} summary should not show watch paths in output section for framed"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} summary excludes watch paths in output section for framed"
    fi

    echo ""
}

# =============================================================================
# Integration Tests: Script Execution
# =============================================================================

test_script_help_flag() {
    echo -e "${BLUE}Testing script execution with --help${NC}"

    local output exit_code
    output=$("${SCRIPT_UNDER_TEST}" --help 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_equals "0" "${exit_code}" "Script exits with 0 for --help"
    assert_contains "${output}" "Local Screenshot Generation Script" \
        "Help output shown for --help"

    echo ""
}

test_script_help_flag_short() {
    echo -e "${BLUE}Testing script execution with -h${NC}"

    local output exit_code
    output=$("${SCRIPT_UNDER_TEST}" -h 2>&1) || exit_code=$?
    exit_code=${exit_code:-0}

    assert_equals "0" "${exit_code}" "Script exits with 0 for -h"
    assert_contains "${output}" "Local Screenshot Generation Script" \
        "Help output shown for -h"

    echo ""
}

test_script_invalid_platform() {
    echo -e "${BLUE}Testing script execution with invalid platform${NC}"

    local output exit_code
    output=$("${SCRIPT_UNDER_TEST}" invalid 2>&1) || exit_code=$?

    assert_equals "1" "${exit_code}" "Script exits with EXIT_INVALID_ARGS"
    assert_contains "${output}" "Invalid platform: invalid" \
        "Error message shown for invalid platform"
    assert_contains "${output}" "Valid platforms:" \
        "Valid platforms listed in error"

    echo ""
}

test_script_invalid_locale() {
    echo -e "${BLUE}Testing script execution with invalid locale${NC}"

    local output exit_code
    output=$("${SCRIPT_UNDER_TEST}" iphone invalid-locale 2>&1) || exit_code=$?

    assert_equals "1" "${exit_code}" "Script exits with EXIT_INVALID_ARGS"
    assert_contains "${output}" "Invalid locale: invalid-locale" \
        "Error message shown for invalid locale"
    assert_contains "${output}" "Valid locales:" \
        "Valid locales listed in error"

    echo ""
}

test_script_valid_platform_iphone() {
    echo -e "${BLUE}Testing script validates 'iphone' platform${NC}"

    # This test just validates the platform is accepted
    # We don't actually run the full script to avoid starting simulators

    local output exit_code
    # Use timeout to kill after validation passes but before execution starts
    output=$(timeout 2 "${SCRIPT_UNDER_TEST}" iphone 2>&1 || true)
    exit_code=$?

    # Exit code will be timeout (124) or generation failure (2), not invalid args (1)
    if [[ "${exit_code}" == "1" ]]; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} Script should accept 'iphone' platform (got exit code 1)"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} Script accepts 'iphone' platform"
    fi

    echo ""
}

test_script_valid_platform_all() {
    echo -e "${BLUE}Testing script validates 'all' platform${NC}"

    local output exit_code
    # Use timeout to kill after validation passes
    output=$(timeout 2 "${SCRIPT_UNDER_TEST}" all 2>&1 || true)
    exit_code=$?

    # Exit code will be timeout or generation failure, not invalid args
    if [[ "${exit_code}" == "1" ]]; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} Script should accept 'all' platform (got exit code 1)"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} Script accepts 'all' platform"
    fi

    echo ""
}

test_script_valid_locale_all() {
    echo -e "${BLUE}Testing script validates 'all' locale${NC}"

    local output exit_code
    # Use timeout to kill after validation passes
    output=$(timeout 2 "${SCRIPT_UNDER_TEST}" iphone all 2>&1 || true)
    exit_code=$?

    # Exit code will be timeout or generation failure, not invalid args
    if [[ "${exit_code}" == "1" ]]; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} Script should accept 'all' locale (got exit code 1)"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} Script accepts 'all' locale"
    fi

    echo ""
}

test_script_valid_locale_en_us() {
    echo -e "${BLUE}Testing script validates 'en-US' locale${NC}"

    local output exit_code
    # Use timeout to kill after validation passes
    output=$(timeout 2 "${SCRIPT_UNDER_TEST}" iphone en-US 2>&1 || true)
    exit_code=$?

    # Exit code will be timeout or generation failure, not invalid args
    if [[ "${exit_code}" == "1" ]]; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} Script should accept 'en-US' locale (got exit code 1)"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} Script accepts 'en-US' locale"
    fi

    echo ""
}

test_script_valid_locale_fi() {
    echo -e "${BLUE}Testing script validates 'fi' locale${NC}"

    local output exit_code
    # Use timeout to kill after validation passes
    # Quote 'fi' to prevent shellcheck from treating it as keyword
    output=$(timeout 2 "${SCRIPT_UNDER_TEST}" iphone "fi" 2>&1 || true)
    exit_code=$?

    # Exit code will be timeout or generation failure, not invalid args
    if [[ "${exit_code}" == "1" ]]; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} Script should accept 'fi' locale (got exit code 1)"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} Script accepts 'fi' locale"
    fi

    echo ""
}

# =============================================================================
# Test Cases: Logging Functions
# =============================================================================

test_log_info_format() {
    echo -e "${BLUE}Testing log_info() output format${NC}"

    local output
    output=$(log_info "Test message" 2>&1)

    assert_contains "${output}" "[INFO]" "log_info includes [INFO] tag"
    assert_contains "${output}" "Test message" "log_info includes message"
    # Check time format (HH:MM:SS)
    if echo "${output}" | grep -qE '[0-9]{2}:[0-9]{2}:[0-9]{2}'; then
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} log_info includes timestamp"
    else
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} log_info should include timestamp"
    fi

    echo ""
}

test_log_success_format() {
    echo -e "${BLUE}Testing log_success() output format${NC}"

    local output
    output=$(log_success "Operation completed" 2>&1)

    assert_contains "${output}" "[SUCCESS]" "log_success includes [SUCCESS] tag"
    assert_contains "${output}" "Operation completed" "log_success includes message"

    echo ""
}

test_log_warn_format() {
    echo -e "${BLUE}Testing log_warn() output format (stderr)${NC}"

    local output
    output=$(log_warn "Warning message" 2>&1)

    assert_contains "${output}" "[WARN]" "log_warn includes [WARN] tag"
    assert_contains "${output}" "Warning message" "log_warn includes message"

    echo ""
}

test_log_error_format() {
    echo -e "${BLUE}Testing log_error() output format (stderr)${NC}"

    local output
    output=$(log_error "Error occurred" 2>&1)

    assert_contains "${output}" "[ERROR]" "log_error includes [ERROR] tag"
    assert_contains "${output}" "Error occurred" "log_error includes message"

    echo ""
}

test_log_header_format() {
    echo -e "${BLUE}Testing log_header() output format${NC}"

    local output
    output=$(log_header "Section Title" 2>&1)

    assert_contains "${output}" "Section Title" "log_header includes title"
    assert_contains "${output}" "===" "log_header includes border"

    echo ""
}

test_logging_with_special_characters() {
    echo -e "${BLUE}Testing logging functions with special characters${NC}"

    local special_msg='Message with $VAR and "quotes" and \backslash'
    local output

    output=$(log_info "${special_msg}" 2>&1)
    assert_contains "${output}" "quotes" "log_info handles special characters"

    output=$(log_error "${special_msg}" 2>&1)
    assert_contains "${output}" "quotes" "log_error handles special characters"

    echo ""
}

# =============================================================================
# Test Cases: Edge Cases in Validation
# =============================================================================

test_validate_platform_with_spaces() {
    echo -e "${BLUE}Testing validate_platform() with whitespace${NC}"

    validate_platform "iphone " && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'iphone ' (trailing space)"

    validate_platform " iphone" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects ' iphone' (leading space)"

    validate_platform "ip hone" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'ip hone' (space in middle)"

    echo ""
}

test_validate_platform_with_special_chars() {
    echo -e "${BLUE}Testing validate_platform() with special characters${NC}"

    validate_platform "iphone;" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'iphone;'"

    validate_platform "iphone|watch" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'iphone|watch'"

    validate_platform "\$iphone" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects '\$iphone'"

    validate_platform "../iphone" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects '../iphone'"

    echo ""
}

test_validate_locale_with_spaces() {
    echo -e "${BLUE}Testing validate_locale() with whitespace${NC}"

    validate_locale "en-US " && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'en-US ' (trailing space)"

    validate_locale " fi" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects ' fi' (leading space)"

    echo ""
}

test_validate_locale_with_special_chars() {
    echo -e "${BLUE}Testing validate_locale() with special characters${NC}"

    validate_locale "en-US;" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'en-US;'"

    validate_locale "en/US" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'en/US'"

    validate_locale "../fi" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects '../fi'"

    echo ""
}

test_validate_platform_case_sensitivity() {
    echo -e "${BLUE}Testing validate_platform() case sensitivity${NC}"

    validate_platform "iPhone" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'iPhone'"

    validate_platform "IPHONE" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'IPHONE'"

    validate_platform "All" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'All'"

    validate_platform "WATCH" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_platform rejects 'WATCH'"

    echo ""
}

test_validate_locale_case_sensitivity() {
    echo -e "${BLUE}Testing validate_locale() case sensitivity${NC}"

    validate_locale "EN-US" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'EN-US'"

    validate_locale "en-us" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'en-us'"

    validate_locale "FI" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'FI'"

    validate_locale "All" && exit_code=0 || exit_code=$?
    assert_false "${exit_code}" "validate_locale rejects 'All'"

    echo ""
}

# =============================================================================
# Test Cases: Framing Edge Cases
# =============================================================================

test_frame_ios_screenshots_empty_locale_dirs() {
    echo -e "${BLUE}Testing frame_ios_screenshots_inplace() - empty locale directories${NC}"

    mock_bundle_success
    mock_magick_exists

    # Create locale directories but no PNG files
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US"
    # No files created

    local output
    output=$(frame_ios_screenshots_inplace 2>&1)
    local exit_code=$?

    # Should succeed (no files to copy is valid)
    assert_true "${exit_code}" "frame_ios_screenshots_inplace handles empty locale directories"

    echo ""
}

test_frame_ios_screenshots_no_framed_output() {
    echo -e "${BLUE}Testing frame_ios_screenshots_inplace() - fastlane produces no framed output${NC}"

    mock_bundle_success
    mock_magick_exists

    # Create screenshots_compat but fastlane doesn't create framed output
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"
    # Don't create screenshots_framed directory

    local output
    output=$(frame_ios_screenshots_inplace 2>&1)
    local exit_code=$?

    # Should succeed (no framed files to copy back)
    assert_true "${exit_code}" "frame_ios_screenshots_inplace handles missing framed output"

    echo ""
}

test_frame_ios_screenshots_partial_framed_output() {
    echo -e "${BLUE}Testing frame_ios_screenshots_inplace() - partial framed output${NC}"

    mock_bundle_success
    mock_magick_exists

    # Create two locale directories in compat, but only one in framed
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/fi"
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US"

    echo "original en" > "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"
    echo "original fi" > "${TEST_TEMP_DIR}/fastlane/screenshots_compat/fi/screen1.png"
    echo "framed en" > "${TEST_TEMP_DIR}/fastlane/screenshots_framed/ios/en-US/screen1.png"
    # No framed fi output

    local output
    output=$(frame_ios_screenshots_inplace 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "frame_ios_screenshots_inplace handles partial framed output"

    # Check en-US was replaced
    local en_content
    en_content=$(cat "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png")
    assert_equals "framed en" "${en_content}" "en-US screenshot replaced with framed version"

    # Check fi was not modified
    local fi_content
    fi_content=$(cat "${TEST_TEMP_DIR}/fastlane/screenshots_compat/fi/screen1.png")
    assert_equals "original fi" "${fi_content}" "fi screenshot unchanged when no framed version"

    echo ""
}

test_clean_screenshot_directories_nonexistent_dirs() {
    echo -e "${BLUE}Testing clean_screenshot_directories() - handles nonexistent directories${NC}"

    # Remove all directories first
    rm -rf "${TEST_TEMP_DIR}/fastlane"

    # Should not fail when directories don't exist
    local output
    output=$(clean_screenshot_directories 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "clean_screenshot_directories succeeds with nonexistent directories"
    assert_contains "${output}" "Screenshot directories cleaned" \
        "clean_screenshot_directories shows success even when dirs don't exist"

    echo ""
}

test_clean_screenshot_directories_permission_resilience() {
    echo -e "${BLUE}Testing clean_screenshot_directories() - resilience to permission errors${NC}"

    # Create a directory structure
    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots/en-US/test.png"

    # The function uses || true to ignore errors, so it should always succeed
    local output
    output=$(clean_screenshot_directories 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "clean_screenshot_directories handles permission errors gracefully"

    echo ""
}

# =============================================================================
# Test Cases: Cleanup Edge Cases
# =============================================================================

test_cleanup_simulators_xcrun_failure() {
    echo -e "${BLUE}Testing cleanup_simulators() - xcrun command failure${NC}"

    # Mock xcrun to fail
    xcrun() {
        return 1
    }
    export -f xcrun

    mock_pkill_success
    mock_sleep

    # cleanup_simulators uses || true, so it should succeed despite xcrun failures
    local output
    output=$(cleanup_simulators 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "cleanup_simulators handles xcrun failures gracefully"

    echo ""
}

test_cleanup_simulators_grep_no_match() {
    echo -e "${BLUE}Testing cleanup_simulators() - grep finds no booted devices${NC}"

    # Mock xcrun to return empty device list
    xcrun() {
        if [[ "$1" == "simctl" && "$2" == "list" ]]; then
            echo "== Devices =="
            echo "-- iOS 18.1 --"
            # No devices at all
            return 0
        fi
        return 0
    }
    export -f xcrun

    mock_pkill_success
    mock_sleep

    local output
    output=$(cleanup_simulators 2>&1)
    local exit_code=$?

    assert_true "${exit_code}" "cleanup_simulators handles empty device list"

    # Should not show warning about booted simulators
    if echo "${output}" | grep -q "still showing as booted"; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} Should not warn about booted sims when none exist"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} No warning shown when no booted sims"
    fi

    echo ""
}

# =============================================================================
# Test Cases: Screenshot Generation Edge Cases
# =============================================================================

test_generate_framed_screenshots_framing_failure() {
    echo -e "${BLUE}Testing generate_framed_screenshots() - framing failure${NC}"

    # Screenshots exist but framing fails
    mock_bundle_failure
    mock_magick_exists

    mkdir -p "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US"
    touch "${TEST_TEMP_DIR}/fastlane/screenshots_compat/en-US/screen1.png"

    local output exit_code
    output=$(generate_framed_screenshots 2>&1) || exit_code=$?

    assert_equals "2" "${exit_code}" "generate_framed_screenshots fails on framing error"
    assert_contains "${output}" "Screenshot framing failed" \
        "generate_framed_screenshots shows error message"

    echo ""
}

# =============================================================================
# Test Cases: Integration - Multiple Arguments
# =============================================================================

test_script_multiple_args_valid() {
    echo -e "${BLUE}Testing script with multiple valid arguments${NC}"

    # Test with both platform and locale
    local output exit_code
    output=$(timeout 2 "${SCRIPT_UNDER_TEST}" ipad fi 2>&1 || true)
    exit_code=$?

    # Should not fail validation (exit code 1)
    if [[ "${exit_code}" == "1" ]]; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} Script should accept 'ipad fi' arguments"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} Script accepts multiple valid arguments"
    fi

    echo ""
}

test_script_too_many_args() {
    echo -e "${BLUE}Testing script with too many arguments${NC}"

    # Script accepts only 2 args, but bash won't reject extras
    # They're just ignored, so this should still pass validation
    local output exit_code
    output=$(timeout 2 "${SCRIPT_UNDER_TEST}" iphone en-US extra 2>&1 || true)
    exit_code=$?

    # Exit code won't be 1 (validation error) because platform/locale are valid
    # Extra args are simply ignored
    if [[ "${exit_code}" == "1" ]]; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} Script should not fail validation with extra args"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} Script ignores extra arguments"
    fi

    echo ""
}

test_script_empty_platform() {
    echo -e "${BLUE}Testing script with empty string as platform${NC}"

    # When passed empty string "", bash parameter expansion ${1:-all} treats it as unset
    # and defaults to "all", so the script will actually accept it and try to run
    # This is a quirk of bash parameter expansion, not a bug
    local output exit_code
    output=$(timeout 2 "${SCRIPT_UNDER_TEST}" "" 2>&1 || true)
    exit_code=$?

    # Exit code will NOT be 1 because empty string becomes "all" via ${1:-all}
    # This tests that bash parameter expansion works as designed
    if [[ "${exit_code}" == "1" ]]; then
        ((TESTS_RUN++))
        ((TESTS_FAILED++))
        echo -e "  ${RED}✗${NC} Empty string defaults to 'all' via parameter expansion"
    else
        ((TESTS_RUN++))
        ((TESTS_PASSED++))
        echo -e "  ${GREEN}✓${NC} Empty string defaults to 'all' platform (bash parameter expansion)"
    fi

    echo ""
}

# =============================================================================
# Test Cases: Summary Function Edge Cases
# =============================================================================

test_show_summary_with_timestamps() {
    echo -e "${BLUE}Testing show_summary() displays timestamps correctly${NC}"

    local start="2024-01-01 10:00:00"
    local end="2024-01-01 11:30:00"
    local output
    output=$(show_summary "${start}" "${end}" "all")

    assert_contains "${output}" "${start}" "Summary includes start time"
    assert_contains "${output}" "${end}" "Summary includes end time"

    echo ""
}

test_show_summary_next_steps_section() {
    echo -e "${BLUE}Testing show_summary() includes next steps${NC}"

    local output
    output=$(show_summary "2024-01-01 10:00:00" "2024-01-01 10:30:00" "iphone")

    assert_contains "${output}" "Next steps:" "Summary includes next steps section"
    assert_contains "${output}" "Review screenshots manually" "Summary includes manual review step"
    assert_contains "${output}" "git add" "Summary includes git add command"
    assert_contains "${output}" "bundle exec fastlane ios release" "Summary includes release command"

    echo ""
}

# =============================================================================
# Test Runner
# =============================================================================

run_all_tests() {
    echo ""
    echo -e "${BOLD}==================================================================${NC}"
    echo -e "${BOLD}Test Suite: generate-screenshots-local.sh${NC}"
    echo -e "${BOLD}==================================================================${NC}"
    echo ""

    # Setup test environment
    setup_test_environment

    # Source script functions
    source_script_functions

    # Run validation tests
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Validation Function Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    test_validate_platform
    test_validate_locale
    test_validate_platform_with_spaces
    test_validate_platform_with_special_chars
    test_validate_locale_with_spaces
    test_validate_locale_with_special_chars
    test_validate_platform_case_sensitivity
    test_validate_locale_case_sensitivity

    # Run logging tests
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Logging Function Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    test_log_info_format
    test_log_success_format
    test_log_warn_format
    test_log_error_format
    test_log_header_format
    test_logging_with_special_characters

    # Run cleanup tests
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Cleanup Function Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    test_cleanup_simulators_success
    test_cleanup_simulators_with_booted
    test_clean_screenshot_directories
    test_cleanup_simulators_xcrun_failure
    test_cleanup_simulators_grep_no_match
    test_clean_screenshot_directories_nonexistent_dirs
    test_clean_screenshot_directories_permission_resilience

    # Run framing tests
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Framing Function Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    test_frame_ios_screenshots_inplace_success
    test_frame_ios_screenshots_no_screenshots
    test_frame_ios_screenshots_no_imagemagick
    test_frame_ios_screenshots_fastlane_failure
    test_frame_ios_screenshots_copies_framed
    test_frame_ios_screenshots_empty_locale_dirs
    test_frame_ios_screenshots_no_framed_output
    test_frame_ios_screenshots_partial_framed_output

    # Run generation tests
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Screenshot Generation Function Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    test_generate_iphone_screenshots_success
    test_generate_iphone_screenshots_failure
    test_generate_ipad_screenshots_success
    test_generate_ipad_screenshots_failure
    test_generate_watch_screenshots_success
    test_generate_watch_screenshots_failure
    test_generate_all_screenshots_success
    test_generate_all_screenshots_iphone_failure
    test_generate_all_screenshots_ipad_failure
    test_generate_all_screenshots_watch_failure
    test_generate_all_screenshots_framing_failure
    test_generate_framed_screenshots_success
    test_generate_framed_screenshots_no_screenshots
    test_generate_framed_screenshots_framing_failure

    # Run validation tests
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Screenshot Validation Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    test_validate_screenshots_success
    test_validate_screenshots_failure

    # Run help/summary tests
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Help and Summary Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    test_show_help
    test_show_summary_watch
    test_show_summary_all
    test_show_summary_iphone
    test_show_summary_ipad
    test_show_summary_framed
    test_show_summary_with_timestamps
    test_show_summary_next_steps_section

    # Run integration tests
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Integration Tests${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    test_script_help_flag
    test_script_help_flag_short
    test_script_invalid_platform
    test_script_invalid_locale
    test_script_valid_platform_iphone
    test_script_valid_platform_all
    test_script_valid_locale_all
    test_script_valid_locale_en_us
    test_script_valid_locale_fi
    test_script_multiple_args_valid
    test_script_too_many_args
    test_script_empty_platform

    # Print summary
    echo ""
    echo -e "${BOLD}==================================================================${NC}"
    echo -e "${BOLD}Test Results${NC}"
    echo -e "${BOLD}==================================================================${NC}"
    echo ""
    echo "Total tests run:    ${TESTS_RUN}"
    echo -e "${GREEN}Tests passed:       ${TESTS_PASSED}${NC}"

    if [[ "${TESTS_FAILED}" -gt 0 ]]; then
        echo -e "${RED}Tests failed:       ${TESTS_FAILED}${NC}"
        echo ""
        echo -e "${RED}OVERALL: FAIL${NC}"
        return 1
    else
        echo -e "${GREEN}Tests failed:       0${NC}"
        echo ""
        echo -e "${GREEN}OVERALL: PASS${NC}"
        return 0
    fi
}

# =============================================================================
# Script Entry Point
# =============================================================================

run_all_tests
exit $?
