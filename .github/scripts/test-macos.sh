#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# macOS Test Runner Script
# ==============================================================================
# Runs unit and/or UI tests for ListAll macOS app with detailed reporting.
#
# Exit Codes:
#   0 - All tests passed
#   1 - Test failures or script errors
#
# Usage:
#   .github/scripts/test-macos.sh [OPTIONS]
#
# Options:
#   --unit              Run unit tests only (ListAllMacTests)
#   --ui                Run UI tests only (ListAllMacUITests)
#   --verbose           Enable verbose xcodebuild output
#   --help              Show this help message
#
# Default (no options): Runs all tests (unit + UI)
#
# Examples:
#   .github/scripts/test-macos.sh                 # Run all tests
#   .github/scripts/test-macos.sh --unit          # Run unit tests only
#   .github/scripts/test-macos.sh --ui            # Run UI tests only
#   .github/scripts/test-macos.sh --verbose       # All tests with verbose output
# ==============================================================================

# shellcheck disable=SC2155  # Intentional: combined declaration for script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155  # Intentional: combined declaration for script paths
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_PATH="${PROJECT_ROOT}/ListAll/ListAll.xcodeproj"
readonly SCHEME="ListAllMac"
readonly RESULTS_DIR="${PROJECT_ROOT}/ListAll"
readonly RESULTS_BUNDLE="${RESULTS_DIR}/TestResults-Mac.xcresult"

# ANSI color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Script options (set via command line)
VERBOSE=false
ONLY_UNIT=false
ONLY_UI=false

# Test result tracking
TEST_START_TIME=0
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ==============================================================================
# Helper Functions
# ==============================================================================

log_success() {
    echo -e "${GREEN}✅${NC} $*"
}

log_failure() {
    echo -e "${RED}❌${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $*"
}

log_info() {
    echo -e "${BLUE}ℹ${NC}  $*"
}

log_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $*${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_help() {
    # Extract documentation comments from the script header (lines 1-28)
    sed -n '1,28s/^# //p; 28q' "$0"
    exit 0
}

# Format duration from seconds to human-readable string
format_duration() {
    local total_seconds="$1"
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))

    if [[ ${minutes} -gt 0 ]]; then
        echo "${minutes}m ${seconds}s"
    else
        echo "${seconds}s"
    fi
}

# ==============================================================================
# Pre-flight Checks
# ==============================================================================

preflight_checks() {
    log_header "Pre-flight Checks"

    # Check Xcode project exists
    if [[ ! -d "${PROJECT_PATH}" ]]; then
        log_failure "Xcode project not found: ${PROJECT_PATH}"
        exit 1
    fi
    log_success "Xcode project found"

    # Verify scheme exists
    local schemes
    schemes=$(xcodebuild -project "${PROJECT_PATH}" -list 2>/dev/null | grep -A 100 "Schemes:" | tail -n +2 | grep -v "^$" | sed 's/^[ \t]*//' || true)

    if ! echo "${schemes}" | grep -q "^${SCHEME}$"; then
        log_failure "${SCHEME} scheme not found"
        log_info "Available schemes:"
        echo "${schemes}" | while read -r scheme; do
            echo "      ${scheme}"
        done
        exit 1
    fi
    log_success "${SCHEME} scheme found"

    # Verify results directory is writable
    if [[ ! -d "${RESULTS_DIR}" ]]; then
        log_warning "Results directory does not exist: ${RESULTS_DIR}"
        log_info "Creating results directory..."
        mkdir -p "${RESULTS_DIR}"
    fi

    if [[ ! -w "${RESULTS_DIR}" ]]; then
        log_failure "Results directory not writable: ${RESULTS_DIR}"
        exit 1
    fi
    log_success "Results directory writable"

    echo ""
}

# ==============================================================================
# Test Execution
# ==============================================================================

run_tests() {
    local test_type="$1"  # "all", "unit", or "ui"
    local test_label=""
    local only_testing_args=()

    case "${test_type}" in
        "unit")
            test_label="Unit Tests (ListAllMacTests)"
            only_testing_args=("-only-testing:ListAllMacTests")
            ;;
        "ui")
            test_label="UI Tests (ListAllMacUITests)"
            only_testing_args=("-only-testing:ListAllMacUITests")
            ;;
        "all")
            test_label="All Tests (Unit + UI)"
            ;;
        *)
            log_failure "Invalid test type: ${test_type}"
            exit 1
            ;;
    esac

    log_header "Running ${test_label}"

    # Clean previous results
    if [[ -d "${RESULTS_BUNDLE}" ]]; then
        log_info "Cleaning previous test results..."
        rm -rf "${RESULTS_BUNDLE}"
    fi

    # Build xcodebuild command
    local xcodebuild_cmd=(
        xcodebuild test
        -project "${PROJECT_PATH}"
        -scheme "${SCHEME}"
        -destination "platform=macOS"
        -resultBundlePath "${RESULTS_BUNDLE}"
        CODE_SIGN_IDENTITY=""
        CODE_SIGNING_REQUIRED=NO
        CODE_SIGNING_ALLOWED=NO
    )

    # Add test filtering if needed
    if [[ ${#only_testing_args[@]} -gt 0 ]]; then
        xcodebuild_cmd+=("${only_testing_args[@]}")
    fi

    # Prepare output handling
    local test_output
    local test_exit_code=0
    local start_time
    start_time=$(date +%s)

    log_info "Starting tests at $(date '+%H:%M:%S')..."
    echo ""

    # Run tests with appropriate output handling
    if [[ "${VERBOSE}" == "true" ]]; then
        # Verbose mode: show all output in real-time
        log_info "Running in verbose mode (full xcodebuild output)..."
        echo ""
        if ! "${xcodebuild_cmd[@]}"; then
            test_exit_code=$?
        fi
    else
        # Normal mode: capture output, show progress
        log_info "Running tests (use --verbose for detailed output)..."
        if ! test_output=$("${xcodebuild_cmd[@]}" 2>&1); then
            test_exit_code=$?
        fi
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    log_info "Tests completed in $(format_duration ${duration})"

    # Parse test results
    parse_test_results "${test_exit_code}" "${test_output:-}"

    return "${test_exit_code}"
}

# ==============================================================================
# Test Result Parsing
# ==============================================================================

parse_test_results() {
    local exit_code="$1"
    local output="${2:-}"

    echo ""
    log_header "Test Results Summary"

    # Try to extract test counts from xcresult bundle
    if [[ -d "${RESULTS_BUNDLE}" ]] && command -v xcrun >/dev/null 2>&1; then
        local result_info
        if result_info=$(xcrun xcresulttool get --format json --path "${RESULTS_BUNDLE}" 2>/dev/null); then
            # Parse JSON for test counts (basic grep approach for portability)
            if echo "${result_info}" | grep -q "testsCount"; then
                # Extract counts using grep and basic parsing
                local total
                total=$(echo "${result_info}" | grep -o '"testsCount"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1)
                local failed
                failed=$(echo "${result_info}" | grep -o '"testsFailedCount"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*$' | head -1)

                if [[ -n "${total}" ]] && [[ -n "${failed}" ]]; then
                    TOTAL_TESTS="${total}"
                    FAILED_TESTS="${failed}"
                    PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
                fi
            fi
        fi
    fi

    # Fallback: parse from output if xcresult parsing failed
    if [[ ${TOTAL_TESTS} -eq 0 ]] && [[ -n "${output}" ]]; then
        # Look for standard test summary patterns
        if echo "${output}" | grep -q "Test Suite.*passed"; then
            # Extract from "Test Suite 'All tests' passed at..."
            local passed_line
            passed_line=$(echo "${output}" | grep "Test Suite.*passed" | tail -1)
            if [[ -n "${passed_line}" ]]; then
                # Parse: "Executed 15 tests, with 0 failures"
                TOTAL_TESTS=$(echo "${passed_line}" | grep -o '[0-9]* test' | grep -o '[0-9]*' | head -1)
                FAILED_TESTS=$(echo "${passed_line}" | grep -o '[0-9]* failure' | grep -o '[0-9]*' | head -1)
                PASSED_TESTS=$((TOTAL_TESTS - FAILED_TESTS))
            fi
        fi
    fi

    # Display results
    if [[ ${exit_code} -eq 0 ]]; then
        log_success "All tests passed"
        if [[ ${TOTAL_TESTS} -gt 0 ]]; then
            echo ""
            echo -e "   ${GREEN}Total:${NC}   ${TOTAL_TESTS} tests"
            echo -e "   ${GREEN}Passed:${NC}  ${PASSED_TESTS} tests"
            echo -e "   ${GREEN}Failed:${NC}  ${FAILED_TESTS} tests"
        fi
    else
        log_failure "Tests failed (exit code: ${exit_code})"
        if [[ ${TOTAL_TESTS} -gt 0 ]]; then
            echo ""
            echo -e "   ${BLUE}Total:${NC}   ${TOTAL_TESTS} tests"
            echo -e "   ${GREEN}Passed:${NC}  ${PASSED_TESTS} tests"
            echo -e "   ${RED}Failed:${NC}  ${FAILED_TESTS} tests"
        fi

        # Show failure hints if not in verbose mode
        if [[ "${VERBOSE}" != "true" ]] && [[ -n "${output}" ]]; then
            echo ""
            log_info "Test failure details:"
            # Extract and show test failures
            local failure_lines
            failure_lines=$(echo "${output}" | grep -A 3 "error:" | head -20)
            if [[ -n "${failure_lines}" ]]; then
                # Add indentation to each line
                while IFS= read -r line; do
                    echo "      ${line}"
                done <<< "${failure_lines}"
                echo ""
                log_info "Run with --verbose for full output"
            fi
        fi
    fi

    # Show xcresult location
    echo ""
    if [[ -d "${RESULTS_BUNDLE}" ]]; then
        log_info "Full test results: ${RESULTS_BUNDLE}"
        log_info "View in Xcode: xed ${RESULTS_BUNDLE}"
    fi

    echo ""
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unit)
                ONLY_UNIT=true
                shift
                ;;
            --ui)
                ONLY_UI=true
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

    # Validate mutually exclusive options
    if [[ "${ONLY_UNIT}" == "true" ]] && [[ "${ONLY_UI}" == "true" ]]; then
        log_failure "Cannot use --unit and --ui together"
        echo "Use --help for usage information"
        exit 1
    fi

    # Change to project root for consistent paths
    cd "${PROJECT_ROOT}"

    # Print header
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ListAll macOS Test Runner                                         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show configuration
    if [[ "${ONLY_UNIT}" == "true" ]]; then
        log_info "Test mode: Unit tests only"
    elif [[ "${ONLY_UI}" == "true" ]]; then
        log_info "Test mode: UI tests only"
    else
        log_info "Test mode: All tests (unit + UI)"
    fi

    [[ "${VERBOSE}" == "true" ]] && log_info "Verbose output enabled"
    echo ""

    # Run pre-flight checks
    preflight_checks

    # Track overall timing
    TEST_START_TIME=$(date +%s)

    # Run tests based on configuration
    local overall_exit_code=0

    if [[ "${ONLY_UNIT}" == "true" ]]; then
        if ! run_tests "unit"; then
            overall_exit_code=1
        fi
    elif [[ "${ONLY_UI}" == "true" ]]; then
        if ! run_tests "ui"; then
            overall_exit_code=1
        fi
    else
        if ! run_tests "all"; then
            overall_exit_code=1
        fi
    fi

    # Calculate total duration
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - TEST_START_TIME))

    # Print final summary
    log_header "Final Summary"

    if [[ ${overall_exit_code} -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
    else
        echo -e "${RED}❌ Tests failed!${NC}"
    fi

    echo ""
    echo "Total duration: $(format_duration ${total_duration})"
    echo ""

    exit "${overall_exit_code}"
}

main "$@"
