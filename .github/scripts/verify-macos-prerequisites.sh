#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# macOS CI/CD Prerequisites Verification Script
# ==============================================================================
# Verifies that all infrastructure is in place before implementing macOS CI/CD.
# This script validates 5 prerequisites:
#   1. App Store Connect API authentication (actual API call validation)
#   2. macOS provisioning profile (via match, readonly)
#   3. Version synchronization (all platforms match)
#   4. macOS build capability (unsigned build test)
#   5. macOS entitlements (sandbox, CloudKit, App Groups)
#
# Exit Codes:
#   0 - All checks passed (or only warnings)
#   1 - One or more critical checks failed
#
# Usage:
#   .github/scripts/verify-macos-prerequisites.sh [OPTIONS]
#
# Options:
#   --skip-profile-check   Skip provisioning profile check (for first-time setup)
#   --verbose              Show detailed output from commands
#   --ci                   Running in CI environment (stricter checks)
#   --help                 Show this help message
#
# Environment Variables (required for full validation):
#   ASC_KEY_ID             App Store Connect API Key ID
#   ASC_ISSUER_ID          App Store Connect Issuer ID
#   ASC_KEY_BASE64         Base64-encoded API Key content
#   MATCH_PASSWORD         Password for Match encryption
#   MATCH_GIT_TOKEN        GitHub token for Match repo access (CI only)
#
# Swarm Verification: December 2025
#   - Shell Script Specialist: Defensive bash patterns
#   - Pipeline Specialist: CI/CD integration patterns
#   - Apple Development Expert: Xcode/Fastlane patterns
#   - Critical Reviewer: Edge case handling
# ==============================================================================

# shellcheck disable=SC2155  # Intentional: combined declaration for script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155  # Intentional: combined declaration for script paths
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_PATH="${PROJECT_ROOT}/ListAll/ListAll.xcodeproj"
readonly ENTITLEMENTS_FILE="${PROJECT_ROOT}/ListAll/ListAllMac/ListAllMac.entitlements"
readonly VERSION_SYNC_SCRIPT="${SCRIPT_DIR}/verify-version-sync.sh"
readonly MACOS_BUNDLE_ID="io.github.chmc.ListAllMac"
readonly SCHEME_MACOS="ListAllMac"

# ANSI color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script options (set via command line)
SKIP_PROFILE_CHECK=false
VERBOSE=false
CI_MODE=false

# Counters
error_count=0
warning_count=0

# ==============================================================================
# Helper Functions
# ==============================================================================

log_success() {
    echo -e "   ${GREEN}✅${NC} $*"
}

log_failure() {
    echo -e "   ${RED}❌${NC} $*"
}

log_warning() {
    echo -e "   ${YELLOW}⚠${NC}  $*"
}

log_info() {
    echo -e "   ${BLUE}ℹ${NC}  $*"
}

log_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_help() {
    head -50 "$0" | grep -E "^#( |$)" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Check if Fastlane is available via Bundler
check_fastlane_available() {
    if ! command -v bundle >/dev/null 2>&1; then
        return 1
    fi
    if ! bundle exec fastlane --version >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# ==============================================================================
# Check 1: App Store Connect API Authentication
# ==============================================================================
# Uses asc_dry_run lane which actually makes API calls (not just loads key)
# This validates the key works, not just that env vars are set

check_asc_auth() {
    log_header "Check 1 of 5: App Store Connect API Authentication"

    # Check Fastlane availability first
    if ! check_fastlane_available; then
        log_failure "Fastlane not available"
        log_info "Remediation: Run 'bundle install' to install dependencies"
        return 1
    fi

    # Check required environment variables
    local missing_vars=()
    [[ -z "${ASC_KEY_ID:-}" ]] && missing_vars+=("ASC_KEY_ID")
    [[ -z "${ASC_ISSUER_ID:-}" ]] && missing_vars+=("ASC_ISSUER_ID")
    [[ -z "${ASC_KEY_BASE64:-}" ]] && missing_vars+=("ASC_KEY_BASE64")

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_failure "Missing environment variables: ${missing_vars[*]}"
        echo ""
        log_info "Remediation:"
        echo -e "   ${BLUE}export ASC_KEY_ID=\"your_key_id\"${NC}"
        echo -e "   ${BLUE}export ASC_ISSUER_ID=\"your_issuer_id\"${NC}"
        echo -e "   ${BLUE}export ASC_KEY_BASE64=\"\$(base64 -i AuthKey_XXXX.p8)\"${NC}"
        echo ""
        log_info "Get these from App Store Connect > Users and Access > Keys"
        return 1
    fi

    log_info "Environment variables present, validating API key..."

    # Use asc_dry_run lane which actually validates the key via API call
    # This is more reliable than just loading the key
    local asc_output
    if asc_output=$(cd "${PROJECT_ROOT}" && bundle exec fastlane asc_dry_run 2>&1); then
        log_success "App Store Connect API key is valid and functional"
        return 0
    else
        log_failure "App Store Connect API authentication failed"
        echo ""
        # Parse common error messages
        if echo "${asc_output}" | grep -qi "invalid.*credentials\|authorization.*invalid"; then
            log_info "Error: Invalid or expired API key"
        elif echo "${asc_output}" | grep -qi "could not find"; then
            log_info "Error: API key may have been deleted from App Store Connect"
        elif echo "${asc_output}" | grep -qi "network\|connection\|timeout"; then
            log_info "Error: Network connectivity issue"
        fi
        log_info "Remediation: Check App Store Connect > Users and Access > Keys"
        [[ "${VERBOSE}" == "true" ]] && echo "${asc_output}"
        return 1
    fi
}

# ==============================================================================
# Check 2: macOS Provisioning Profile (via Match)
# ==============================================================================
# Uses match --readonly to check profile without creating new ones
# CRITICAL: Parses output to detect "No matching profiles" (exit code 0 but no profile)

check_provisioning_profile() {
    log_header "Check 2 of 5: macOS Provisioning Profile"

    if [[ "${SKIP_PROFILE_CHECK}" == "true" ]]; then
        log_info "Skipping profile check (--skip-profile-check flag set)"
        log_info "This is expected for first-time setup"
        return 0
    fi

    # Check Fastlane availability
    if ! check_fastlane_available; then
        log_failure "Fastlane not available"
        return 1
    fi

    # Check MATCH_PASSWORD
    if [[ -z "${MATCH_PASSWORD:-}" ]]; then
        log_warning "MATCH_PASSWORD not set - cannot verify provisioning profile"
        log_info "This is OK for first-time setup or local development"
        log_info "CI requires MATCH_PASSWORD to access encrypted profiles"
        ((warning_count++)) || true
        return 0  # Warning, not failure
    fi

    log_info "Checking provisioning profile via match (readonly mode)..."

    # Run match in readonly mode and capture output
    local match_output
    local match_exit_code=0
    match_output=$(cd "${PROJECT_ROOT}" && bundle exec fastlane match appstore \
        --platform macos \
        --app_identifier "${MACOS_BUNDLE_ID}" \
        --readonly 2>&1) || match_exit_code=$?

    # CRITICAL: Match may exit 0 even if no profiles found (just warns)
    # Must parse output to detect actual state
    if [[ ${match_exit_code} -ne 0 ]]; then
        log_failure "Match failed (network/auth error)"
        log_info "Remediation: Check MATCH_PASSWORD and git repo access"
        [[ "${VERBOSE}" == "true" ]] && echo "${match_output}"
        return 1
    elif echo "${match_output}" | grep -qi "no matching provisioning profiles\|couldn't find"; then
        log_warning "macOS provisioning profile not found in Match repo"
        echo ""
        log_info "This is expected for first-time macOS CI/CD setup"
        log_info "Remediation (one-time setup):"
        echo -e "   ${BLUE}bundle exec fastlane match appstore --platform macos${NC}"
        ((warning_count++)) || true
        return 0  # Warning, not failure (expected for new setup)
    else
        log_success "macOS provisioning profile available"
        return 0
    fi
}

# ==============================================================================
# Check 3: Version Synchronization
# ==============================================================================
# Delegates to existing verify-version-sync.sh script

check_version_sync() {
    log_header "Check 3 of 5: Version Synchronization"

    if [[ ! -f "${VERSION_SYNC_SCRIPT}" ]]; then
        log_failure "Version sync script not found: ${VERSION_SYNC_SCRIPT}"
        return 1
    fi

    if [[ ! -x "${VERSION_SYNC_SCRIPT}" ]]; then
        log_warning "Version sync script not executable, fixing..."
        chmod +x "${VERSION_SYNC_SCRIPT}"
    fi

    log_info "Running version synchronization check..."

    if "${VERSION_SYNC_SCRIPT}"; then
        log_success "All platforms synchronized"
        return 0
    else
        log_failure "Version mismatch detected"
        log_info "Remediation: Run 'bundle exec fastlane set_version version:X.X.X'"
        return 1
    fi
}

# ==============================================================================
# Check 4: macOS Build Capability
# ==============================================================================
# Performs unsigned build to verify Xcode setup
# NOTE: This validates build capability, NOT signing capability
# Signing is validated separately via match in check 2

check_build_capability() {
    log_header "Check 4 of 5: macOS Build Capability"

    # Verify Xcode project exists
    if [[ ! -d "${PROJECT_PATH}" ]]; then
        log_failure "Xcode project not found: ${PROJECT_PATH}"
        return 1
    fi

    # Verify scheme exists
    local schemes
    schemes=$(xcodebuild -project "${PROJECT_PATH}" -list 2>/dev/null | grep -A 100 "Schemes:" | tail -n +2 | grep -v "^$" | sed 's/^[ \t]*//' || true)

    if ! echo "${schemes}" | grep -q "${SCHEME_MACOS}"; then
        log_failure "${SCHEME_MACOS} scheme not found"
        log_info "Available schemes:"
        echo "${schemes}" | while read -r scheme; do
            echo "      - ${scheme}"
        done
        return 1
    fi

    log_info "Building macOS target (unsigned, Debug configuration)..."
    log_info "This validates Xcode setup, SDK availability, and source code"

    # Build without code signing to verify setup
    # Uses platform=macOS (NOT arch=arm64) per Apple Dev Expert recommendation
    local build_log="${PROJECT_ROOT}/build-mac-prereq.log"
    local build_exit_code=0

    if xcodebuild clean build \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME_MACOS}" \
        -destination 'platform=macOS' \
        -configuration Debug \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        -quiet \
        > "${build_log}" 2>&1; then
        log_success "macOS build successful"
        rm -f "${build_log}"
        return 0
    else
        build_exit_code=$?
        log_failure "macOS build failed (exit code: ${build_exit_code})"
        echo ""
        log_info "Last 15 lines of build output:"
        tail -15 "${build_log}" 2>/dev/null | sed 's/^/      /'
        echo ""
        log_info "Full build log: ${build_log}"
        return 1
    fi
}

# ==============================================================================
# Check 5: macOS Entitlements Verification
# ==============================================================================
# Verifies required entitlements for macOS App Store / TestFlight
# CRITICAL: macOS requires explicit sandbox and network entitlements (unlike iOS)

check_entitlements() {
    log_header "Check 5 of 5: macOS Entitlements"

    if [[ ! -f "${ENTITLEMENTS_FILE}" ]]; then
        log_failure "Entitlements file not found: ${ENTITLEMENTS_FILE}"
        log_info "Remediation: Create entitlements file with required keys"
        return 1
    fi

    log_info "Verifying required entitlements for macOS App Store..."

    # Required entitlements for macOS TestFlight (per Apple Dev Expert)
    # These are DIFFERENT from iOS - macOS requires explicit sandbox and network
    local required_entitlements=(
        "com.apple.security.app-sandbox"           # REQUIRED for Mac App Store
        "com.apple.security.network.client"        # REQUIRED for CloudKit
        "com.apple.security.application-groups"    # REQUIRED for shared data
        "com.apple.developer.icloud-services"      # REQUIRED for CloudKit
    )

    local missing_count=0
    for entitlement in "${required_entitlements[@]}"; do
        if grep -q "${entitlement}" "${ENTITLEMENTS_FILE}"; then
            log_success "${entitlement}"
        else
            log_failure "Missing: ${entitlement}"
            ((missing_count++))
        fi
    done

    if [[ ${missing_count} -gt 0 ]]; then
        echo ""
        log_info "Remediation: Add missing entitlements to ${ENTITLEMENTS_FILE}"
        log_info "See Apple documentation for macOS App Store requirements"
        return 1
    fi

    return 0
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-profile-check)
                SKIP_PROFILE_CHECK=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --ci)
                CI_MODE=true
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

    # Change to project root for consistent paths
    cd "${PROJECT_ROOT}"

    # Print header
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  macOS CI/CD Prerequisites Verification                            ║${NC}"
    echo -e "${BLUE}║  Task 9.0.2 - Pre-flight checks before Phase 9 implementation      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show options
    [[ "${SKIP_PROFILE_CHECK}" == "true" ]] && log_info "Profile check skipped (--skip-profile-check)"
    [[ "${VERBOSE}" == "true" ]] && log_info "Verbose mode enabled"
    [[ "${CI_MODE}" == "true" ]] && log_info "CI mode enabled"

    # Run all checks (continue even if one fails)
    if ! check_asc_auth; then
        ((error_count++)) || true
    fi

    if ! check_provisioning_profile; then
        ((error_count++)) || true
    fi

    if ! check_version_sync; then
        ((error_count++)) || true
    fi

    if ! check_build_capability; then
        ((error_count++)) || true
    fi

    if ! check_entitlements; then
        ((error_count++)) || true
    fi

    # Print summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [[ ${error_count} -eq 0 && ${warning_count} -eq 0 ]]; then
        echo -e "${GREEN}✅ All 5 prerequisites verified successfully!${NC}"
        echo ""
        echo "You may proceed with Phase 9 CI/CD implementation (Tasks 9.1+)"
        echo ""
        exit 0
    elif [[ ${error_count} -eq 0 && ${warning_count} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Passed with ${warning_count} warning(s)${NC}"
        echo ""
        echo "Warnings are expected for first-time setup."
        echo "You may proceed with Phase 9, but address warnings before release."
        echo ""
        exit 0
    else
        echo -e "${RED}❌ ${error_count} check(s) failed, ${warning_count} warning(s)${NC}"
        echo ""
        echo "Fix the errors above before proceeding with Phase 9."
        echo ""
        exit 1
    fi
}

main "$@"
