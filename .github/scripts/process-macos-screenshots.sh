#!/usr/bin/env bash
# process-macos-screenshots.sh
# Processes raw macOS screenshots into App Store format (2880x1800)
# Creates marketing-style screenshots with radial gradient background and drop shadow

set -euo pipefail

#------------------------------------------------------------------------------
# Script Setup
#------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly PROJECT_ROOT

# Source helper library
# shellcheck source=lib/macos-screenshot-helper.sh
source "${SCRIPT_DIR}/lib/macos-screenshot-helper.sh"

#------------------------------------------------------------------------------
# Default Configuration
#------------------------------------------------------------------------------

DEFAULT_INPUT_DIR="${PROJECT_ROOT}/fastlane/screenshots/mac"
DEFAULT_OUTPUT_DIR="${PROJECT_ROOT}/fastlane/screenshots/mac/processed"

#------------------------------------------------------------------------------
# Script Variables
#------------------------------------------------------------------------------

INPUT_DIR=""
OUTPUT_DIR=""
DRY_RUN=false
VERBOSE=false

#------------------------------------------------------------------------------
# Verbose Logging
#------------------------------------------------------------------------------

log_verbose() {
    if ${VERBOSE}; then
        log_info "$@"
    fi
}

#------------------------------------------------------------------------------
# Help Function
#------------------------------------------------------------------------------

show_help() {
    cat << 'EOF'
Usage: process-macos-screenshots.sh [OPTIONS]

Process raw macOS screenshots into App Store format (2880x1800).
Creates marketing-style screenshots with radial gradient background and drop shadow.

Options:
    -i, --input DIR     Input directory containing locale subdirectories
                        Default: fastlane/screenshots/mac
    -o, --output DIR    Output directory for processed screenshots
                        Default: fastlane/screenshots/mac/processed
    -n, --dry-run       Show what would be done without processing
    -v, --verbose       Enable verbose output
    -h, --help          Show this help message

Examples:
    process-macos-screenshots.sh
    process-macos-screenshots.sh -i ./input -o ./output
    process-macos-screenshots.sh --dry-run

Exit Codes:
    0   Success
    1   Invalid arguments
    2   Missing dependencies
    3   Processing failed

EOF
}

#------------------------------------------------------------------------------
# Argument Parsing
#------------------------------------------------------------------------------

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--input)
                INPUT_DIR="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Set defaults if not provided
    INPUT_DIR="${INPUT_DIR:-${DEFAULT_INPUT_DIR}}"
    OUTPUT_DIR="${OUTPUT_DIR:-${DEFAULT_OUTPUT_DIR}}"
}

#------------------------------------------------------------------------------
# Validation Functions
#------------------------------------------------------------------------------

validate_input_directory() {
    if [[ ! -d "${INPUT_DIR}" ]]; then
        log_error "Input directory does not exist: ${INPUT_DIR}"
        exit 1
    fi
}

#------------------------------------------------------------------------------
# Locale Discovery
#------------------------------------------------------------------------------

discover_locales() {
    local -a locales=()

    for locale_dir in "${INPUT_DIR}"/*/; do
        if [[ -d "${locale_dir}" ]]; then
            local locale_name
            locale_name="$(basename "${locale_dir}")"

            # Skip the processed directory
            if [[ "${locale_name}" != "processed" ]]; then
                locales+=("${locale_name}")
            fi
        fi
    done

    if [[ ${#locales[@]} -eq 0 ]]; then
        log_warn "No locale directories found in: ${INPUT_DIR}"
    else
        # Log to stderr to avoid corrupting the return value
        log_info "Discovered locales: ${locales[*]}" >&2
    fi

    # Output only locale names to stdout
    if [[ ${#locales[@]} -gt 0 ]]; then
        echo "${locales[@]}"
    fi
}

#------------------------------------------------------------------------------
# Batch Processing
#------------------------------------------------------------------------------

process_all_screenshots() {
    local -a locales
    local locale_output_raw
    locale_output_raw="$(discover_locales)"

    if [[ -z "${locale_output_raw}" ]]; then
        log_warn "No locales to process"
        return 0
    fi

    read -ra locales <<< "${locale_output_raw}"

    if [[ ${#locales[@]} -eq 0 ]]; then
        log_warn "No locales to process"
        return 0
    fi

    local success_count=0
    local fail_count=0
    local skip_count=0

    # Create temporary directory for atomic processing
    local temp_dir=""
    temp_dir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '${temp_dir}'" EXIT

    log_info "Processing screenshots to temporary directory..."

    for locale in "${locales[@]}"; do
        local locale_input="${INPUT_DIR}/${locale}"
        local locale_output="${temp_dir}/${locale}"

        if [[ ! -d "${locale_input}" ]]; then
            log_warn "Locale directory not found: ${locale_input}"
            continue
        fi

        mkdir -p "${locale_output}"

        local png_count=0
        for screenshot in "${locale_input}"/*.png; do
            if [[ -f "${screenshot}" ]]; then
                ((png_count++)) || true
            fi
        done

        if [[ ${png_count} -eq 0 ]]; then
            log_warn "No PNG files in locale: ${locale}"
            continue
        fi

        log_info "Processing locale: ${locale} (${png_count} files)"

        for screenshot in "${locale_input}"/*.png; do
            if [[ -f "${screenshot}" ]]; then
                local filename
                filename="$(basename "${screenshot}")"

                if ${DRY_RUN}; then
                    log_info "[DRY-RUN] Would process: ${locale}/${filename}"
                    ((skip_count++)) || true
                    continue
                fi

                log_verbose "Processing: ${locale}/${filename}"
                if process_single_screenshot "${screenshot}" "${locale_output}/${filename}"; then
                    ((success_count++)) || true
                else
                    ((fail_count++)) || true
                    log_error "Failed to process: ${locale}/${filename}"
                fi
            fi
        done
    done

    # Summary
    echo ""
    log_info "Processing complete:"
    log_info "  Success: ${success_count}"
    log_info "  Failed:  ${fail_count}"
    if ${DRY_RUN}; then
        log_info "  Skipped (dry-run): ${skip_count}"
    fi

    # Move successful files to output, even if some failed (continue after failures)
    if [[ ${success_count} -gt 0 ]]; then
        log_info "Moving processed screenshots to output directory..."

        # Create output directory structure and move files
        for locale_dir in "${temp_dir}"/*/; do
            if [[ -d "${locale_dir}" ]]; then
                local locale_name
                locale_name="$(basename "${locale_dir}")"
                local final_output="${OUTPUT_DIR}/${locale_name}"

                mkdir -p "${final_output}"

                # Move only successfully processed files
                for processed_file in "${locale_dir}"/*.png; do
                    if [[ -f "${processed_file}" ]]; then
                        mv "${processed_file}" "${final_output}/"
                    fi
                done
            fi
        done

        log_success "Output saved to: ${OUTPUT_DIR}"
    fi

    if [[ ${fail_count} -gt 0 ]]; then
        log_error "Some screenshots failed to process (${fail_count} failures)."
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Main Entry Point
#------------------------------------------------------------------------------

main() {
    parse_arguments "$@"

    log_info "macOS Screenshot Processor"
    log_info "=========================="

    # Check dependencies
    if ! check_imagemagick; then
        exit 2
    fi

    # Validate input
    validate_input_directory

    log_info "Input:  ${INPUT_DIR}"
    log_info "Output: ${OUTPUT_DIR}"
    echo ""

    # Process screenshots
    if ! process_all_screenshots; then
        exit 3
    fi

    exit 0
}

main "$@"
