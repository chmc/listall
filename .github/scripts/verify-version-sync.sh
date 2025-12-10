#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Version Synchronization Verification Script
# ==============================================================================
# Verifies that all platform versions (iOS, macOS, watchOS) are synchronized
# and match the expected version in .version file.
#
# Exit Codes:
#   0 - All platform versions synchronized
#   1 - Version mismatch detected
# ==============================================================================

# shellcheck disable=SC2155  # Intentional: combined declaration and assignment for script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155  # Intentional: combined declaration and assignment for script paths
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_PATH="${PROJECT_ROOT}/ListAll/ListAll.xcodeproj"
readonly VERSION_FILE="${PROJECT_ROOT}/.version"

# ANSI color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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
    echo -e "${BLUE}ℹ${NC} $*"
}

# Extract MARKETING_VERSION from Xcode build settings
# Args:
#   $1 - Scheme name
# Returns:
#   Version string or empty string on failure
get_version() {
    local scheme="$1"
    local version

    if ! version="$(xcodebuild -project "${PROJECT_PATH}" -showBuildSettings -scheme "${scheme}" 2>/dev/null | \
        grep "MARKETING_VERSION" | head -1 | awk '{print $3}')"; then
        echo ""
        return 1
    fi

    echo "${version}"
    return 0
}

# ==============================================================================
# Version Verification
# ==============================================================================

verify_versions() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Version Synchronization Verification                         ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Check .version file exists
    if [[ ! -f "${VERSION_FILE}" ]]; then
        log_failure ".version file not found at: ${VERSION_FILE}"
        echo ""
        echo "Remediation:"
        echo "  Create .version file with current version:"
        echo "  echo '1.1.4' > .version"
        echo ""
        return 1
    fi

    # Read expected version
    local expected_version
    expected_version="$(cat "${VERSION_FILE}" | tr -d '[:space:]')"

    if [[ -z "${expected_version}" ]]; then
        log_failure ".version file is empty"
        echo ""
        return 1
    fi

    log_info "Expected version: ${expected_version}"
    echo ""

    # Platform schemes to check
    declare -a schemes=(
        "ListAll"
        "ListAllMac"
        "ListAllWatch Watch App"
    )

    local error_count=0
    local ios_version=""
    local macos_version=""
    local watchos_version=""

    # Check each platform
    for scheme in "${schemes[@]}"; do
        local version
        version="$(get_version "${scheme}")"

        if [[ -z "${version}" ]]; then
            log_failure "${scheme}: Failed to extract version"
            ((error_count++)) || true
            continue
        fi

        # Store versions for later reference
        case "${scheme}" in
            "ListAll")
                ios_version="${version}"
                ;;
            "ListAllMac")
                macos_version="${version}"
                ;;
            "ListAllWatch Watch App")
                watchos_version="${version}"
                ;;
        esac

        if [[ "${version}" == "${expected_version}" ]]; then
            log_success "${scheme}: ${version}"
        else
            log_failure "${scheme}: ${version} (expected ${expected_version})"
            ((error_count++)) || true
        fi
    done

    echo ""

    # Print summary and remediation if needed
    if [[ ${error_count} -eq 0 ]]; then
        echo -e "${GREEN}✅ All platforms synchronized at version ${expected_version}${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Version mismatch detected!${NC}"
        echo ""
        echo "Current state:"
        [[ -n "${ios_version}" ]] && echo "  • ListAll (iOS): ${ios_version}"
        [[ -n "${macos_version}" ]] && echo "  • ListAllMac (macOS): ${macos_version}"
        [[ -n "${watchos_version}" ]] && echo "  • ListAllWatch Watch App (watchOS): ${watchos_version}"
        echo ""
        echo "Remediation:"
        echo "  To synchronize all platforms to ${expected_version}:"
        echo -e "  ${BLUE}bundle exec fastlane set_version version:${expected_version}${NC}"
        echo ""
        echo "  Or to update .version file to match current platform versions:"
        echo -e "  ${BLUE}echo '${ios_version:-1.1.4}' > .version${NC}"
        echo ""
        return 1
    fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    if verify_versions; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
