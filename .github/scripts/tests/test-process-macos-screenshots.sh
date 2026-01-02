#!/usr/bin/env bash
# =============================================================================
# Test Suite for process-macos-screenshots.sh
# =============================================================================
# Purpose: TDD test suite for macOS screenshot processing
# Usage:   ./test-process-macos-screenshots.sh
# TDD RED Phase - All tests should FAIL before implementation
# =============================================================================

# shellcheck disable=SC2329  # Test functions are called indirectly via run_test

set -euo pipefail

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

    # Run test in subshell to isolate errexit behavior
    if (set +e; ${test_func}); then
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
    # shellcheck source=../lib/macos-screenshot-helper.sh
    source "${HELPER_SCRIPT}" 2>/dev/null && type check_imagemagick &>/dev/null
}

#------------------------------------------------------------------------------
# Input Validation Tests (4 tests)
#------------------------------------------------------------------------------

test_rejects_missing_input_dir() {
    # Script must exist first
    [[ -x "${SCRIPT_UNDER_TEST}" ]] || return 1
    ! "${SCRIPT_UNDER_TEST}" 2>/dev/null
}

test_rejects_nonexistent_input_dir() {
    # Script must exist first
    [[ -x "${SCRIPT_UNDER_TEST}" ]] || return 1
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

    # Output file must exist
    [[ -f "${temp_dir}/output/en-US/test.png" ]] || return 1

    local channels
    channels=$(magick identify -format "%[channels]" "${temp_dir}/output/en-US/test.png" 2>/dev/null)
    # channels must be non-empty and not contain alpha
    [[ -n "${channels}" ]] && [[ "${channels}" != *"a"* ]] && [[ "${channels}" != *"alpha"* ]]
}

test_output_under_10mb() {
    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "${temp_dir}"' RETURN

    mkdir -p "${temp_dir}/input/en-US"
    magick -size 800x652 xc:white "${temp_dir}/input/en-US/test.png" 2>/dev/null || return 1

    "${SCRIPT_UNDER_TEST}" -i "${temp_dir}/input" -o "${temp_dir}/output" 2>/dev/null

    # Output file must exist
    [[ -f "${temp_dir}/output/en-US/test.png" ]] || return 1

    local size
    size=$(stat -f%z "${temp_dir}/output/en-US/test.png" 2>/dev/null || stat -c%s "${temp_dir}/output/en-US/test.png" 2>/dev/null)
    # size must be non-empty and less than 10MB
    [[ -n "${size}" ]] && [[ ${size} -lt 10485760 ]]  # 10MB in bytes
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
    # Script must exist first
    [[ -x "${SCRIPT_UNDER_TEST}" ]] || return 1

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
