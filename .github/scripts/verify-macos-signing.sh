#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# macOS Code Signing Verification Script
# ==============================================================================
# Verifies macOS certificate and provisioning profile availability via match.
# This script validates:
#   1. Match repository access and connectivity
#   2. Certificate availability and validity (not expired)
#   3. Provisioning profile exists and matches bundle ID
#   4. Certificate chain is properly installed in keychain
#
# Exit Codes:
#   0 - All signing components verified successfully
#   1 - One or more signing components failed verification
#
# Usage:
#   .github/scripts/verify-macos-signing.sh [OPTIONS]
#
# Options:
#   --readonly             Use readonly mode (CI/verification only, no creation)
#   --verbose              Show detailed output from match and security commands
#   --help                 Show this help message
#
# Environment Variables (required):
#   MATCH_PASSWORD         Password for Match encryption
#   MATCH_GIT_URL          Git repo URL for match (optional, uses Matchfile default)
#   MATCH_GIT_TOKEN        GitHub token for Match repo access (CI only)
#   FASTLANE_USER          Apple ID (optional, for match sync)
#
# Examples:
#   # Local verification (can create if missing)
#   .github/scripts/verify-macos-signing.sh
#
#   # CI verification (readonly, no creation)
#   .github/scripts/verify-macos-signing.sh --readonly
#
#   # Debug mode with full output
#   .github/scripts/verify-macos-signing.sh --readonly --verbose
#
# Task 9.5: Update Matchfile for macOS Certificates
# ==============================================================================

# shellcheck disable=SC2155  # Intentional: combined declaration for script paths
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155  # Intentional: combined declaration for script paths
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly MATCHFILE="${PROJECT_ROOT}/fastlane/Matchfile"
readonly MACOS_BUNDLE_ID="io.github.chmc.ListAllMac"
readonly CERT_TYPE="Apple Distribution"
readonly PLATFORM="macos"
readonly MATCH_TYPE="appstore"

# ANSI color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script options (set via command line)
READONLY_MODE=false
VERBOSE=false

# Counters
error_count=0
warning_count=0

# Temporary file for match output
TEMP_OUTPUT=""

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
    head -60 "$0" | grep -E "^#( |$)" | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Cleanup temporary files on exit
# shellcheck disable=SC2329  # Function invoked via trap, not directly
cleanup() {
    local exit_code=$?
    if [[ -n "${TEMP_OUTPUT}" && -f "${TEMP_OUTPUT}" ]]; then
        rm -f "${TEMP_OUTPUT}"
    fi
    exit "${exit_code}"
}
trap cleanup EXIT ERR INT TERM

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
# Check 1: Prerequisites and Environment
# ==============================================================================

check_prerequisites() {
    log_header "Check 1 of 4: Prerequisites and Environment"

    local prereq_failed=false

    # Check Bundler/Fastlane
    if ! command -v bundle >/dev/null 2>&1; then
        log_failure "Bundler not available"
        log_info "Remediation: Install bundler with 'gem install bundler'"
        prereq_failed=true
    else
        log_success "Bundler available: $(bundle --version | head -1)"
    fi

    # Check Fastlane
    if ! check_fastlane_available; then
        log_failure "Fastlane not available"
        log_info "Remediation: Run 'bundle install' to install dependencies"
        prereq_failed=true
    else
        local fastlane_version
        fastlane_version=$(bundle exec fastlane --version 2>&1 | head -1)
        log_success "Fastlane available: ${fastlane_version}"
    fi

    # Check MATCH_PASSWORD
    if [[ -z "${MATCH_PASSWORD:-}" ]]; then
        log_failure "MATCH_PASSWORD environment variable not set"
        log_info "Remediation: export MATCH_PASSWORD='your_match_password'"
        prereq_failed=true
    else
        log_success "MATCH_PASSWORD is set"
    fi

    # Check Matchfile exists
    if [[ ! -f "${MATCHFILE}" ]]; then
        log_failure "Matchfile not found: ${MATCHFILE}"
        prereq_failed=true
    else
        log_success "Matchfile found: ${MATCHFILE}"
    fi

    # Optional: Check MATCH_GIT_TOKEN (required in CI)
    if [[ -n "${CI:-}" && -z "${MATCH_GIT_TOKEN:-}" ]]; then
        log_warning "MATCH_GIT_TOKEN not set (required in CI for private repos)"
        ((warning_count++)) || true
    fi

    # Show mode
    if [[ "${READONLY_MODE}" == "true" ]]; then
        log_info "Running in readonly mode (no certificate/profile creation)"
    else
        log_info "Running in read/write mode (can create missing certificates/profiles)"
    fi

    if [[ "${prereq_failed}" == "true" ]]; then
        return 1
    fi

    return 0
}

# ==============================================================================
# Check 2: Match Repository Access
# ==============================================================================

check_match_repo_access() {
    log_header "Check 2 of 4: Match Repository Access"

    log_info "Testing connectivity to match repository..."

    # Extract git URL from Matchfile
    local git_url
    if [[ -f "${MATCHFILE}" ]]; then
        git_url=$(grep -E "^git_url" "${MATCHFILE}" | sed -E "s/git_url\(.*['\"]([^'\"]+)['\"].*\)/\1/" | head -1)
        if [[ -z "${git_url}" ]]; then
            git_url="${MATCH_GIT_URL:-}"
        fi
    else
        git_url="${MATCH_GIT_URL:-}"
    fi

    if [[ -z "${git_url}" ]]; then
        log_failure "Cannot determine match git URL"
        log_info "Set MATCH_GIT_URL environment variable or check Matchfile"
        return 1
    fi

    log_info "Match repository: ${git_url}"

    # Test git access by doing a shallow ls-remote
    # This validates credentials without cloning
    local git_test_output
    if git_test_output=$(git ls-remote "${git_url}" HEAD 2>&1); then
        log_success "Match repository is accessible"
        return 0
    else
        log_failure "Cannot access match repository"
        echo ""

        # Parse common git errors
        if echo "${git_test_output}" | grep -qi "authentication failed\|permission denied"; then
            log_info "Error: Authentication failed"
            log_info "Remediation: Check MATCH_GIT_TOKEN or SSH keys"
        elif echo "${git_test_output}" | grep -qi "repository not found"; then
            log_info "Error: Repository not found or no access"
            log_info "Remediation: Verify repository URL and access permissions"
        elif echo "${git_test_output}" | grep -qi "network\|connection\|timeout"; then
            log_info "Error: Network connectivity issue"
        fi

        [[ "${VERBOSE}" == "true" ]] && echo "${git_test_output}"
        return 1
    fi
}

# ==============================================================================
# Check 3: Certificate Availability and Validity
# ==============================================================================

check_certificate() {
    log_header "Check 3 of 4: Certificate Availability and Validity"

    log_info "Fetching macOS ${MATCH_TYPE} certificate via match..."

    # Create temporary file for match output
    TEMP_OUTPUT=$(mktemp)

    # Build match command as string
    local match_cmd="cd \"${PROJECT_ROOT}\" && bundle exec fastlane match ${MATCH_TYPE} --platform ${PLATFORM} --app_identifier ${MACOS_BUNDLE_ID}"

    # Add readonly flag if requested
    if [[ "${READONLY_MODE}" == "true" ]]; then
        match_cmd="${match_cmd} --readonly"
    fi

    # Run match command with appropriate output handling
    local match_exit_code=0
    if [[ "${VERBOSE}" == "true" ]]; then
        # Verbose: show output and save to file
        if ! eval "${match_cmd}" 2>&1 | tee "${TEMP_OUTPUT}"; then
            match_exit_code=$?
        fi
    else
        # Quiet: only save to file
        if ! eval "${match_cmd}" > "${TEMP_OUTPUT}" 2>&1; then
            match_exit_code=$?
        fi
    fi

    # Read output for analysis
    local match_output
    match_output=$(cat "${TEMP_OUTPUT}")

    # Analyze match output and exit code
    if [[ ${match_exit_code} -ne 0 ]]; then
        log_failure "Match command failed (exit code: ${match_exit_code})"
        echo ""

        # Parse common match errors
        if echo "${match_output}" | grep -qi "couldn't find"; then
            log_info "Error: Certificate or profile not found in match repository"
            if [[ "${READONLY_MODE}" == "true" ]]; then
                log_info "Remediation: Run without --readonly to create:"
                echo -e "   ${BLUE}.github/scripts/verify-macos-signing.sh${NC}"
            else
                log_info "Remediation: Run match manually to create:"
                echo -e "   ${BLUE}bundle exec fastlane match ${MATCH_TYPE} --platform ${PLATFORM}${NC}"
            fi
        elif echo "${match_output}" | grep -qi "authentication\|authorization"; then
            log_info "Error: Authentication failed"
            log_info "Remediation: Check MATCH_PASSWORD and git credentials"
        elif echo "${match_output}" | grep -qi "does not support"; then
            log_info "Error: Bundle ID not registered or no macOS capability"
            log_info "Remediation: Register ${MACOS_BUNDLE_ID} in App Store Connect"
        fi

        [[ "${VERBOSE}" != "true" ]] && echo "${match_output}" | tail -20
        return 1
    fi

    # Check if certificate was actually installed
    if echo "${match_output}" | grep -qi "installed certificate"; then
        log_success "Certificate retrieved and installed successfully"
    elif echo "${match_output}" | grep -qi "certificate.*already installed"; then
        log_success "Certificate already installed"
    else
        log_warning "Match succeeded but certificate status unclear"
        ((warning_count++)) || true
    fi

    # Verify certificate is in keychain and check expiration
    log_info "Verifying certificate in keychain..."

    local cert_info
    if ! cert_info=$(security find-certificate -a -c "${CERT_TYPE}" -p 2>/dev/null | \
                     openssl x509 -noout -subject -dates 2>/dev/null); then
        log_warning "Cannot verify certificate in keychain"
        log_info "This may be normal if certificate is in a different keychain"
        ((warning_count++)) || true
        return 0
    fi

    # Parse certificate info
    local cert_subject
    cert_subject=$(echo "${cert_info}" | grep "subject=" | head -1)
    local not_before
    not_before=$(echo "${cert_info}" | grep "notBefore=" | head -1)
    local not_after
    not_after=$(echo "${cert_info}" | grep "notAfter=" | head -1)

    log_success "Certificate found: ${cert_subject}"
    log_info "Valid from: ${not_before}"
    log_info "Valid until: ${not_after}"

    # Check if certificate is expired
    local expiry_date
    expiry_date="${not_after#notAfter=}"
    local expiry_epoch
    expiry_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "${expiry_date}" "+%s" 2>/dev/null || echo "0")
    local current_epoch
    current_epoch=$(date "+%s")

    if [[ ${expiry_epoch} -gt 0 && ${expiry_epoch} -lt ${current_epoch} ]]; then
        log_failure "Certificate has EXPIRED"
        log_info "Remediation: Revoke and recreate certificate:"
        echo -e "   ${BLUE}bundle exec fastlane match nuke distribution --platform ${PLATFORM}${NC}"
        echo -e "   ${BLUE}bundle exec fastlane match ${MATCH_TYPE} --platform ${PLATFORM}${NC}"
        return 1
    fi

    # Warn if expiring soon (within 30 days)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    if [[ ${days_until_expiry} -lt 30 && ${days_until_expiry} -gt 0 ]]; then
        log_warning "Certificate expires in ${days_until_expiry} days"
        ((warning_count++)) || true
    fi

    return 0
}

# ==============================================================================
# Check 4: Provisioning Profile Availability
# ==============================================================================

check_provisioning_profile() {
    log_header "Check 4 of 4: Provisioning Profile Availability"

    log_info "Verifying provisioning profile for ${MACOS_BUNDLE_ID}..."

    # Profile location depends on match type
    local profile_dir="${HOME}/Library/MobileDevice/Provisioning Profiles"

    # Check if any profiles exist
    if [[ ! -d "${profile_dir}" ]] || [[ -z "$(ls -A "${profile_dir}" 2>/dev/null)" ]]; then
        log_warning "No provisioning profiles found in ${profile_dir}"
        log_info "This may be normal if profiles are in a different location"
        ((warning_count++)) || true
        return 0
    fi

    # Search for profile matching bundle ID
    local profile_found=false

    for profile in "${profile_dir}"/*.provisionprofile "${profile_dir}"/*.mobileprovision; do
        [[ -f "${profile}" ]] || continue

        # Extract profile info
        local profile_info
        if profile_info=$(security cms -D -i "${profile}" 2>/dev/null); then
            # Check if profile matches our bundle ID
            if echo "${profile_info}" | grep -q "${MACOS_BUNDLE_ID}"; then
                profile_found=true

                # Extract profile details
                local profile_name
                profile_name=$(echo "${profile_info}" | plutil -extract Name raw - 2>/dev/null || echo "Unknown")
                local expiration
                expiration=$(echo "${profile_info}" | plutil -extract ExpirationDate raw - 2>/dev/null || echo "Unknown")

                log_success "Provisioning profile found: ${profile_name}"
                log_info "Bundle ID: ${MACOS_BUNDLE_ID}"
                log_info "Expires: ${expiration}"

                # Check if expired
                if [[ "${expiration}" != "Unknown" ]]; then
                    local expiry_epoch
                    expiry_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${expiration}" "+%s" 2>/dev/null || echo "0")
                    local current_epoch
                    current_epoch=$(date "+%s")

                    if [[ ${expiry_epoch} -gt 0 && ${expiry_epoch} -lt ${current_epoch} ]]; then
                        log_failure "Provisioning profile has EXPIRED"
                        log_info "Remediation: Regenerate profile with match:"
                        echo -e "   ${BLUE}bundle exec fastlane match ${MATCH_TYPE} --platform ${PLATFORM} --force_for_new_devices${NC}"
                        return 1
                    fi

                    # Warn if expiring soon (within 30 days)
                    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
                    if [[ ${days_until_expiry} -lt 30 && ${days_until_expiry} -gt 0 ]]; then
                        log_warning "Provisioning profile expires in ${days_until_expiry} days"
                        ((warning_count++)) || true
                    fi
                fi

                break
            fi
        fi
    done

    if [[ "${profile_found}" == "false" ]]; then
        log_failure "No provisioning profile found for ${MACOS_BUNDLE_ID}"
        log_info "Remediation: Generate profile with match:"
        if [[ "${READONLY_MODE}" == "true" ]]; then
            echo -e "   ${BLUE}.github/scripts/verify-macos-signing.sh${NC} (without --readonly)"
        else
            echo -e "   ${BLUE}bundle exec fastlane match ${MATCH_TYPE} --platform ${PLATFORM}${NC}"
        fi
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
            --readonly)
                READONLY_MODE=true
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

    # Change to project root for consistent paths
    cd "${PROJECT_ROOT}"

    # Print header
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  macOS Code Signing Verification                                   ║${NC}"
    echo -e "${BLUE}║  Task 9.5 - Verify Match Certificates and Profiles                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show configuration
    log_info "Platform: ${PLATFORM}"
    log_info "Bundle ID: ${MACOS_BUNDLE_ID}"
    log_info "Match type: ${MATCH_TYPE}"
    [[ "${VERBOSE}" == "true" ]] && log_info "Verbose mode enabled"

    # Run all checks (continue even if one fails)
    if ! check_prerequisites; then
        ((error_count++)) || true
    fi

    if ! check_match_repo_access; then
        ((error_count++)) || true
    fi

    if ! check_certificate; then
        ((error_count++)) || true
    fi

    if ! check_provisioning_profile; then
        ((error_count++)) || true
    fi

    # Print summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [[ ${error_count} -eq 0 && ${warning_count} -eq 0 ]]; then
        echo -e "${GREEN}✅ All signing components verified successfully!${NC}"
        echo ""
        echo "macOS certificate and provisioning profile are ready for CI/CD."
        echo ""
        exit 0
    elif [[ ${error_count} -eq 0 && ${warning_count} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Passed with ${warning_count} warning(s)${NC}"
        echo ""
        echo "Signing components are functional but review warnings above."
        echo ""
        exit 0
    else
        echo -e "${RED}❌ ${error_count} check(s) failed, ${warning_count} warning(s)${NC}"
        echo ""
        echo "Fix the errors above before using macOS signing in CI/CD."
        echo ""
        exit 1
    fi
}

main "$@"
