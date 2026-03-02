#!/usr/bin/env bash
#
# run-muter.sh — Run Muter mutation testing for ListAll
#
# Usage:
#   ./scripts/run-muter.sh <platform> [--test-targets "T1,T2"] [extra-muter-args...]
#
# Platforms: ios, macos, watchos, all
#
# Options:
#   --test-targets "T1,T2"  Inject -only-testing flags into the muter config
#                           to run targeted test subsets per mutant.
#                           Comma-separated list of test bundle/suite paths.
#                           Example: --test-targets "ListAllTests/ServicesTests"
#
# Muter v16 always reads muter.conf.yml from the current directory.
# This script copies the platform-specific config into place before running,
# resolving simulator destinations for iOS and watchOS.
#
# Prerequisites:
#   - Muter built from source: https://github.com/muter-mutation-testing/muter
#     (Homebrew version is broken — build with: git clone ... && make install)
#   - muter binary in PATH
#
# Examples:
#   ./scripts/run-muter.sh ios
#   ./scripts/run-muter.sh ios --test-targets "ListAllTests/ServicesTests" --files-to-mutate "ListAll/ListAll/Services/ImportService.swift"
#   ./scripts/run-muter.sh all
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ACTIVE_CONFIG="${PROJECT_ROOT}/muter.conf.yml"

# ── Helpers ──────────────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 <platform> [--test-targets \"T1,T2\"] [extra-muter-args...]"
    echo ""
    echo "Platforms:"
    echo "  ios      Run mutation testing for iOS"
    echo "  macos    Run mutation testing for macOS"
    echo "  watchos  Run mutation testing for watchOS"
    echo "  all      Run all platforms sequentially"
    echo ""
    echo "Options:"
    echo "  --test-targets \"T1,T2\"  Run only specified test targets per mutant"
    echo ""
    echo "Extra arguments are passed directly to muter run."
    echo ""
    echo "Examples:"
    echo "  $0 ios --skip-coverage"
    echo "  $0 ios --test-targets \"ListAllTests/ServicesTests\" --files-to-mutate \"path/File.swift\""
    exit 1
}

check_muter() {
    if ! command -v muter &>/dev/null; then
        echo "ERROR: muter is not installed."
        echo ""
        echo "The Homebrew version is broken. Build from source:"
        echo "  git clone https://github.com/muter-mutation-testing/muter.git /tmp/muter"
        echo "  cd /tmp/muter && make install"
        echo ""
        echo "If 'make install' fails (permission denied), copy manually:"
        echo "  mkdir -p ~/bin && cp /tmp/muter/.build/release/muter ~/bin/"
        echo "  export PATH=\"\$HOME/bin:\$PATH\""
        exit 1
    fi
    echo "Using muter: $(command -v muter) (version $(muter --version 2>&1))"
}

# Inject -only-testing flags into the active muter config.
# Inserts entries before the final "- test" line in the arguments array.
# Usage: inject_test_targets "Target1/Suite1,Target2/Suite2"
inject_test_targets() {
    local targets="$1"
    local config="${ACTIVE_CONFIG}"

    if [[ -z "${targets}" ]]; then
        return 0
    fi

    echo "    Injecting -only-testing targets: ${targets}"

    # Build sed insertion text: one "  - -only-testing:Target" line per target
    local sed_insert=""
    IFS=',' read -ra TARGET_ARRAY <<< "${targets}"
    for target in "${TARGET_ARRAY[@]}"; do
        target="$(echo "${target}" | xargs)"  # trim whitespace
        if [[ -n "${target}" ]]; then
            # Escape forward slashes for sed
            local escaped="${target//\//\\/}"
            sed_insert="${sed_insert}  - -only-testing:${escaped}\\
"
        fi
    done

    # Insert before the "  - test" line (last entry in arguments array)
    sed -i '' "s|^  - test$|${sed_insert}  - test|" "${config}"
}

# Resolve a simulator UDID by platform and device name pattern
# Usage: resolve_simulator "iOS" "iPhone 16 Pro"
resolve_simulator() {
    local platform="$1"
    local name_pattern="$2"

    xcrun simctl list devices available -j 2>/dev/null | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
platform = '${platform}'
name_pattern = '${name_pattern}'
for runtime, devices in sorted(data.get('devices', {}).items(), reverse=True):
    if platform in runtime:
        for d in devices:
            if d.get('isAvailable') and name_pattern in d.get('name', ''):
                # Also extract OS version from runtime string
                # e.g., 'com.apple.CoreSimulator.SimRuntime.iOS-18-2' -> '18.2'
                parts = runtime.rsplit('-', 2)
                if len(parts) >= 3:
                    os_ver = parts[-2] + '.' + parts[-1]
                else:
                    os_ver = 'unknown'
                print(d['udid'] + '|' + d['name'] + '|' + os_ver)
                sys.exit(0)
sys.exit(1)
" 2>/dev/null || true
}

# Ensure cleanup happens on exit
cleanup_config() {
    rm -f "${ACTIVE_CONFIG}"
}
trap cleanup_config EXIT

# ── Platform runners ─────────────────────────────────────────────────────────

run_ios() {
    local source_config="${PROJECT_ROOT}/muter.ios.conf.yml"
    echo "==> Running Muter for iOS"

    # Resolve iPhone simulator
    local sim_info
    sim_info=$(resolve_simulator "iOS" "iPhone 16 Pro")
    if [[ -z "${sim_info}" ]]; then
        echo "ERROR: No available iPhone 16 Pro simulator found."
        echo "Available iOS simulators:"
        xcrun simctl list devices available | grep -i iphone || echo "  (none)"
        exit 1
    fi

    local sim_udid sim_name sim_os
    IFS='|' read -r sim_udid sim_name sim_os <<< "${sim_info}"
    echo "    Simulator: ${sim_name} (iOS ${sim_os}, ${sim_udid})"

    # Generate config with resolved destination
    sed "s|IOS_DESTINATION_PLACEHOLDER|platform=iOS Simulator,id=${sim_udid}|g" \
        "${source_config}" > "${ACTIVE_CONFIG}"
    echo "    Activated config with resolved iOS destination"
    inject_test_targets "${TEST_TARGETS}"

    cd "${PROJECT_ROOT}"
    local exit_code=0
    muter run --skip-coverage "$@" || exit_code=$?
    if [[ "${exit_code}" -eq 255 ]]; then
        echo "No mutable code found — treating as success"
        return 0
    fi
    return "${exit_code}"
}

run_macos() {
    local source_config="${PROJECT_ROOT}/muter.macos.conf.yml"
    echo "==> Running Muter for macOS"

    # macOS needs no simulator resolution
    cp "${source_config}" "${ACTIVE_CONFIG}"
    echo "    Activated config: muter.macos.conf.yml"
    inject_test_targets "${TEST_TARGETS}"

    cd "${PROJECT_ROOT}"
    local exit_code=0
    muter run --skip-coverage "$@" || exit_code=$?
    if [[ "${exit_code}" -eq 255 ]]; then
        echo "No mutable code found — treating as success"
        return 0
    fi
    return "${exit_code}"
}

run_watchos() {
    local source_config="${PROJECT_ROOT}/muter.watchos.conf.yml"
    echo "==> Running Muter for watchOS"

    # Resolve watchOS simulator
    local sim_info
    sim_info=$(resolve_simulator "watchOS" "Apple Watch")
    if [[ -z "${sim_info}" ]]; then
        echo "ERROR: No available Apple Watch simulator found."
        echo "Available watchOS simulators:"
        xcrun simctl list devices available | grep -i watch || echo "  (none)"
        exit 1
    fi

    local sim_udid sim_name sim_os
    IFS='|' read -r sim_udid sim_name sim_os <<< "${sim_info}"
    echo "    Simulator: ${sim_name} (watchOS ${sim_os}, ${sim_udid})"

    # Generate config with resolved destination
    sed "s|WATCHOS_DESTINATION_PLACEHOLDER|platform=watchOS Simulator,id=${sim_udid}|g" \
        "${source_config}" > "${ACTIVE_CONFIG}"
    echo "    Activated config with resolved watchOS destination"
    inject_test_targets "${TEST_TARGETS}"

    # Boot simulator
    echo "    Booting watchOS simulator..."
    xcrun simctl boot "${sim_udid}" 2>/dev/null || true
    if ! xcrun simctl bootstatus "${sim_udid}" -b; then
        echo "ERROR: Failed to boot watchOS simulator ${sim_udid}"
        exit 1
    fi

    # Run muter
    cd "${PROJECT_ROOT}"
    local exit_code=0
    muter run --skip-coverage "$@" || exit_code=$?
    if [[ "${exit_code}" -eq 255 ]]; then
        echo "No mutable code found — treating as success"
        exit_code=0
    fi

    # Shutdown simulator (config cleanup handled by trap)
    echo "    Shutting down watchOS simulator..."
    xcrun simctl shutdown "${sim_udid}" 2>/dev/null || true

    return "${exit_code}"
}

# ── Main ─────────────────────────────────────────────────────────────────────

if [[ $# -lt 1 ]]; then
    usage
fi

PLATFORM="$1"
shift

# Parse --test-targets (consumed here, not passed to muter)
TEST_TARGETS=""
REMAINING_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --test-targets)
            TEST_TARGETS="${2:-}"
            shift 2
            ;;
        *)
            REMAINING_ARGS+=("$1")
            shift
            ;;
    esac
done

# Filter out empty arguments (GitHub Actions passes "" for unset inputs)
ARGS=()
for arg in "${REMAINING_ARGS[@]+"${REMAINING_ARGS[@]}"}"; do
    [[ -n "$arg" ]] && ARGS+=("$arg")
done
if (( ${#ARGS[@]} > 0 )); then
    set -- "${ARGS[@]}"
else
    set --
fi

check_muter

case "${PLATFORM}" in
    ios)
        run_ios "$@"
        ;;
    macos)
        run_macos "$@"
        ;;
    watchos)
        run_watchos "$@"
        ;;
    all)
        echo "==> Running Muter for all platforms"
        echo ""
        run_ios "$@"
        echo ""
        run_macos "$@"
        echo ""
        run_watchos "$@"
        echo ""
        echo "==> All platforms complete"
        ;;
    *)
        echo "ERROR: Unknown platform '${PLATFORM}'"
        echo ""
        usage
        ;;
esac
