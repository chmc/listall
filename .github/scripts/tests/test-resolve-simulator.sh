#!/usr/bin/env bash
# =============================================================================
# Test Suite for resolve-simulator.sh
# =============================================================================
# Purpose: Verify simulator resolution is pinned to the selected Xcode's SDK
#          runtime, matches device names exactly, and creates missing devices.
# Usage:   ./test-resolve-simulator.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SCRIPT_UNDER_TEST="${SCRIPT_DIR}/../resolve-simulator.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_test() { echo -e "${BLUE}[TEST]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)) || true; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)) || true; }

run_test() {
    local test_name="$1"
    local test_func="$2"
    ((TESTS_RUN++)) || true
    log_test "Running: ${test_name}"
    if (set +e; ${test_func}); then
        log_pass "${test_name}"
    else
        log_fail "${test_name}"
    fi
}

# -----------------------------------------------------------------------------
# Mock xcrun
# -----------------------------------------------------------------------------
# The mock serves canned JSON from MOCK_DIR and records `simctl create` calls.
# Fixture: SDK 26.5; runtimes iOS 26.1 + 26.5 and watchOS 26.5; devices include
# "iPhone 17 Pro" on both iOS runtimes and "iPhone 17 Pro Max" on 26.5.

MOCK_DIR=""

setup_mock() {
    MOCK_DIR=$(mktemp -d)
    mkdir -p "${MOCK_DIR}/bin"

    cat > "${MOCK_DIR}/devices.json" <<'JSON'
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-26-1": [
      {"name": "iPhone 17 Pro", "udid": "OLD-RUNTIME-PRO", "isAvailable": true}
    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
      {"name": "iPhone 17 Pro Max", "udid": "PRO-MAX-265", "isAvailable": true},
      {"name": "iPhone 17 Pro", "udid": "PRO-265", "isAvailable": true}
    ],
    "com.apple.CoreSimulator.SimRuntime.watchOS-26-5": [
      {"name": "Apple Watch Series 11 (42mm)", "udid": "PAIRED-WATCH-42", "isAvailable": true}
    ]
  }
}
JSON

    cat > "${MOCK_DIR}/runtimes.json" <<'JSON'
{
  "runtimes": [
    {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-1", "isAvailable": true},
    {"identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-5", "isAvailable": true},
    {"identifier": "com.apple.CoreSimulator.SimRuntime.watchOS-26-5", "isAvailable": true}
  ]
}
JSON

    cat > "${MOCK_DIR}/devicetypes.json" <<'JSON'
{
  "devicetypes": [
    {"name": "Apple Watch Series 11 (46mm)", "identifier": "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm"},
    {"name": "iPad Pro 13-inch (M5)", "identifier": "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB"}
  ]
}
JSON

    cat > "${MOCK_DIR}/pairs.json" <<'JSON'
{
  "pairs": {
    "PAIR-1": {
      "watch": {"name": "Apple Watch Series 11 (42mm)", "udid": "PAIRED-WATCH-42", "state": "Shutdown"},
      "phone": {"name": "iPhone 17 Pro", "udid": "PRO-265", "state": "Shutdown"},
      "state": "(active, disconnected)"
    }
  }
}
JSON

    cat > "${MOCK_DIR}/bin/xcrun" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
    "--sdk iphonesimulator --show-sdk-version"|"--sdk watchsimulator --show-sdk-version")
        echo "${MOCK_SDK_VERSION:-26.5}" ;;
    "simctl list devices available -j") cat "${MOCK_DIR}/devices.json" ;;
    "simctl list runtimes -j") cat "${MOCK_DIR}/runtimes.json" ;;
    "simctl list devicetypes -j") cat "${MOCK_DIR}/devicetypes.json" ;;
    "simctl list pairs -j") cat "${MOCK_DIR}/pairs.json" ;;
    simctl\ pair\ *)
        printf '%s|%s\n' "$3" "$4" >> "${MOCK_DIR}/paired.log"
        echo "NEW-PAIR-UDID" ;;
    simctl\ create*)
        shift 2
        printf '%s|%s|%s\n' "$1" "$2" "$3" >> "${MOCK_DIR}/created.log"
        echo "CREATED-UDID" ;;
    *) echo "unexpected xcrun call: $*" >&2; exit 99 ;;
esac
MOCK
    chmod +x "${MOCK_DIR}/bin/xcrun"
    export MOCK_DIR
}

teardown_mock() {
    [[ -n "${MOCK_DIR}" ]] && rm -rf "${MOCK_DIR}"
}

run_resolver() {
    PATH="${MOCK_DIR}/bin:${PATH}" "${SCRIPT_UNDER_TEST}" "$@"
}

# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

test_script_is_executable() {
    [[ -x "${SCRIPT_UNDER_TEST}" ]]
}

test_usage_error_without_args() {
    local rc=0
    run_resolver >/dev/null 2>&1 || rc=$?
    [[ ${rc} -eq 2 ]]
}

test_rejects_unknown_platform() {
    local rc=0
    run_resolver tvOS "Apple TV" >/dev/null 2>&1 || rc=$?
    [[ ${rc} -eq 2 ]]
}

test_picks_device_on_sdk_runtime_not_other_runtime() {
    local udid
    udid=$(run_resolver iOS "iPhone 17 Pro")
    [[ "${udid}" == "PRO-265" ]]
}

test_exact_name_does_not_match_pro_max() {
    local udid
    udid=$(run_resolver iOS "iPhone 17 Pro Max")
    [[ "${udid}" == "PRO-MAX-265" ]]
}

test_creates_missing_device_on_sdk_runtime() {
    local udid
    udid=$(run_resolver watchOS "Apple Watch Series 11 (46mm)")
    [[ "${udid}" == "CREATED-UDID" ]] || return 1
    grep -qx "Apple Watch Series 11 (46mm)|com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm|com.apple.CoreSimulator.SimRuntime.watchOS-26-5" \
        "${MOCK_DIR}/created.log"
}

test_pairs_unpaired_watch_with_companion_iphone() {
    local udid
    udid=$(run_resolver watchOS "Apple Watch Series 11 (46mm)")
    [[ "${udid}" == "CREATED-UDID" ]] || return 1
    # Embedded (companion) watch apps need a paired iPhone to be a valid destination
    grep -qx "CREATED-UDID|PRO-265" "${MOCK_DIR}/paired.log"
}

test_does_not_repair_already_paired_watch() {
    local udid
    udid=$(run_resolver watchOS "Apple Watch Series 11 (42mm)")
    [[ "${udid}" == "PAIRED-WATCH-42" ]] || return 1
    ! grep -q "PAIRED-WATCH-42" "${MOCK_DIR}/paired.log" 2>/dev/null
}

test_ios_resolution_does_not_pair() {
    run_resolver iOS "iPhone 17 Pro Max" >/dev/null || return 1
    ! grep -q "PRO-MAX-265" "${MOCK_DIR}/paired.log" 2>/dev/null
}

test_fails_when_sdk_runtime_not_installed() {
    local rc=0 output
    output=$(MOCK_SDK_VERSION=26.9 run_resolver iOS "iPhone 17 Pro" 2>&1) || rc=$?
    [[ ${rc} -eq 1 ]] && echo "${output}" | grep -q "iOS-26-9"
}

test_fails_for_unknown_device_type() {
    local rc=0
    run_resolver iOS "iPhone 99 Ultra" >/dev/null 2>&1 || rc=$?
    [[ ${rc} -eq 1 ]]
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    setup_mock
    trap teardown_mock EXIT

    run_test "Script is executable" test_script_is_executable
    run_test "Usage error (exit 2) without args" test_usage_error_without_args
    run_test "Rejects unknown platform" test_rejects_unknown_platform
    run_test "Picks device on SDK runtime, ignores other runtimes" test_picks_device_on_sdk_runtime_not_other_runtime
    run_test "Exact name match (Pro vs Pro Max)" test_exact_name_does_not_match_pro_max
    run_test "Creates missing device on SDK runtime" test_creates_missing_device_on_sdk_runtime
    run_test "Pairs unpaired watch with companion iPhone" test_pairs_unpaired_watch_with_companion_iphone
    run_test "Does not re-pair an already paired watch" test_does_not_repair_already_paired_watch
    run_test "iOS resolution does not pair" test_ios_resolution_does_not_pair
    run_test "Fails when SDK runtime is not installed" test_fails_when_sdk_runtime_not_installed
    run_test "Fails for unknown device type" test_fails_for_unknown_device_type

    echo ""
    echo "Tests run: ${TESTS_RUN}, passed: ${TESTS_PASSED}, failed: ${TESTS_FAILED}"
    [[ ${TESTS_FAILED} -eq 0 ]]
}

main "$@"
