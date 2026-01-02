#!/usr/bin/env bash
# macOS Screenshot Processing Helper Library
# Provides functions for processing raw screenshots into App Store format

set -euo pipefail

#------------------------------------------------------------------------------
# Constants
#------------------------------------------------------------------------------

readonly MACOS_CANVAS_WIDTH=2880
readonly MACOS_CANVAS_HEIGHT=1800
readonly MACOS_GRADIENT_CENTER="#2A5F6D"
readonly MACOS_GRADIENT_EDGE="#0D1F26"
readonly MACOS_SCALE_PERCENT=65
readonly MACOS_SHADOW_OPACITY=50
readonly MACOS_SHADOW_BLUR=30
readonly MACOS_SHADOW_OFFSET_Y=15
readonly MACOS_MAX_FILE_SIZE=10485760  # 10MB in bytes
readonly MACOS_CORNER_RADIUS_BASE=22   # Corner radius for 800px-wide window (measured: 16-21px visible desktop)
readonly MACOS_CORNER_RADIUS_REF_WIDTH=800  # Reference width for corner radius scaling
readonly MACOS_CORNER_RADIUS_MIN=8     # Minimum corner radius for very small windows

#------------------------------------------------------------------------------
# Logging Functions
#------------------------------------------------------------------------------

log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_success() {
    echo "[OK] $*"
}

#------------------------------------------------------------------------------
# Corner Radius Calculation
#------------------------------------------------------------------------------

# Calculate proportional corner radius based on window width
# macOS uses constant point-based radius, but when we apply radius before scaling,
# smaller windows end up with proportionally larger corners after upscaling.
# This function scales the radius to maintain consistent visual appearance.
calculate_corner_radius() {
    local input_width="$1"
    # Scale corner radius proportionally to window width
    # 22px was tuned for 800px wide windows
    local radius
    radius=$((MACOS_CORNER_RADIUS_BASE * input_width / MACOS_CORNER_RADIUS_REF_WIDTH))
    # Minimum radius to avoid issues with very small windows
    if [[ "${radius}" -lt "${MACOS_CORNER_RADIUS_MIN}" ]]; then
        radius="${MACOS_CORNER_RADIUS_MIN}"
    fi
    echo "${radius}"
}

#------------------------------------------------------------------------------
# Dependency Check
#------------------------------------------------------------------------------

check_imagemagick() {
    if ! command -v magick &>/dev/null; then
        if command -v convert &>/dev/null; then
            log_error "ImageMagick 6 detected. This script requires ImageMagick 7+"
            log_error "Upgrade with: brew upgrade imagemagick"
            return 1
        fi
        log_error "ImageMagick not found. Install with: brew install imagemagick"
        return 1
    fi

    # Verify it's version 7+
    local version
    version=$(magick --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    local major_version
    major_version=$(echo "${version}" | cut -d. -f1)

    if [[ "${major_version}" -lt 7 ]]; then
        log_error "ImageMagick ${version} detected. This script requires ImageMagick 7+"
        log_error "Upgrade with: brew upgrade imagemagick"
        return 1
    fi

    log_info "ImageMagick ${version} detected"
    return 0
}

#------------------------------------------------------------------------------
# Input Validation
#------------------------------------------------------------------------------

validate_input_image() {
    local input_file="$1"

    # Check file exists
    if [[ ! -f "${input_file}" ]]; then
        log_error "Input file not found: ${input_file}"
        return 1
    fi

    # Check file is readable
    if [[ ! -r "${input_file}" ]]; then
        log_error "Input file not readable: ${input_file}"
        return 1
    fi

    # Check file is not empty
    if [[ ! -s "${input_file}" ]]; then
        log_error "Input file is empty: ${input_file}"
        return 1
    fi

    # Check MIME type is PNG
    local file_type
    file_type=$(file -b --mime-type "${input_file}" 2>/dev/null)
    if [[ "${file_type}" != "image/png" ]]; then
        log_error "Input file is not a PNG: ${input_file} (type: ${file_type})"
        return 1
    fi

    # Check file is a valid image (not corrupt)
    if ! magick identify "${input_file}" &>/dev/null; then
        log_error "Input file is corrupt or not a valid image: ${input_file}"
        return 1
    fi

    return 0
}

#------------------------------------------------------------------------------
# Core Processing Function
#------------------------------------------------------------------------------

process_single_screenshot() {
    local input_file="$1"
    local output_file="$2"

    # Validate input
    if ! validate_input_image "${input_file}"; then
        return 1
    fi

    # Calculate max dimensions (85% of canvas, fits within both bounds)
    local max_width=$((MACOS_CANVAS_WIDTH * MACOS_SCALE_PERCENT / 100))   # 2448
    local max_height=$((MACOS_CANVAS_HEIGHT * MACOS_SCALE_PERCENT / 100)) # 1530

    # Create output directory if needed
    mkdir -p "$(dirname "${output_file}")"

    # Get input image dimensions for rounded corner mask
    local input_dims
    input_dims=$(magick identify -format "%wx%h" "${input_file}")
    local input_width="${input_dims%x*}"
    local input_height="${input_dims#*x}"

    # Create temp file for intermediate rounded corners image
    # NOTE: Two-step process required because nested composition with DstIn
    #       causes colorspace issues in ImageMagick when combined with gradient
    local temp_rounded
    temp_rounded=$(mktemp /tmp/macos_rounded_XXXXXX.png)

    # Calculate proportional corner radius based on window width
    # This ensures consistent visual corner appearance after scaling
    local corner_radius
    corner_radius=$(calculate_corner_radius "${input_width}")

    # Step 1: Apply rounded corner mask to input image (macOS windows have rounded corners)
    # NOTE: macOS uses "continuous corners" (squircles) not perfect circles.
    #       ImageMagick's roundrectangle uses circular arcs. The blur+level creates anti-aliased edges.
    #       Radius is scaled proportionally: 22px for 800px windows, ~13px for 482px windows.
    if ! magick "${input_file}" \
        \( -size "${input_width}x${input_height}" xc:none -fill white \
           -draw "roundrectangle 0,0,$((input_width-1)),$((input_height-1)),${corner_radius},${corner_radius}" \
           -blur 0x0.5 -level 50%,100% \
        \) -alpha set -compose DstIn -composite \
        "${temp_rounded}"; then
        rm -f "${temp_rounded}"
        log_error "Failed to apply rounded corners for: ${input_file}"
        return 1
    fi

    # Step 2: Create final output
    # - Scale to fit within max bounds (preserving aspect ratio)
    # - Add drop shadow
    # - Composite onto radial gradient background
    # NOTE: -resize "WxH>" fits within bounds while preserving aspect ratio
    #       No > flag - allows upscaling small windows to fill the canvas
    if ! magick -size "${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT}" -depth 8 \
        radial-gradient:"${MACOS_GRADIENT_CENTER}-${MACOS_GRADIENT_EDGE}" \
        \( "${temp_rounded}" \
            -resize "${max_width}x${max_height}" \
            \( +clone -background black \
               -shadow "${MACOS_SHADOW_OPACITY}x${MACOS_SHADOW_BLUR}+0+${MACOS_SHADOW_OFFSET_Y}" \) \
            +swap \
            -background none \
            -layers merge \
            +repage \
        \) \
        -gravity center \
        -composite \
        -flatten \
        -alpha off \
        -strip \
        -colorspace sRGB \
        -define png:compression-level=9 \
        "${output_file}"; then
        rm -f "${temp_rounded}"
        log_error "ImageMagick processing failed for: ${input_file}"
        return 1
    fi

    # Clean up temp file
    rm -f "${temp_rounded}"

    # Validate output was created
    if [[ ! -f "${output_file}" ]]; then
        log_error "Output file not created: ${output_file}"
        return 1
    fi

    # Validate output file size (not suspiciously small)
    local output_size
    output_size=$(stat -f%z "${output_file}" 2>/dev/null || stat -c%s "${output_file}" 2>/dev/null)
    if [[ "${output_size}" -lt 10000 ]]; then
        log_error "Output file suspiciously small (${output_size} bytes): ${output_file}"
        return 1
    fi

    # Validate output dimensions
    local output_dims
    output_dims=$(magick identify -format "%wx%h" "${output_file}")
    if [[ "${output_dims}" != "${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT}" ]]; then
        log_error "Output dimensions incorrect: ${output_dims} (expected ${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT})"
        return 1
    fi

    # Log input -> output transformation
    local input_dims
    input_dims=$(magick identify -format "%wx%h" "${input_file}")
    log_success "Processed: $(basename "${output_file}") [${input_dims} -> ${output_dims}]"
    return 0
}

#------------------------------------------------------------------------------
# Validation Function
#------------------------------------------------------------------------------

validate_macos_screenshot() {
    local screenshot="$1"

    # Check file exists
    if [[ ! -f "${screenshot}" ]]; then
        log_error "Screenshot not found: ${screenshot}"
        return 1
    fi

    # Check dimensions = 2880x1800
    local dims
    dims=$(magick identify -format "%wx%h" "${screenshot}" 2>/dev/null)
    if [[ "${dims}" != "${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT}" ]]; then
        log_error "Invalid dimensions: ${dims} (expected ${MACOS_CANVAS_WIDTH}x${MACOS_CANVAS_HEIGHT})"
        return 1
    fi

    # Check no alpha channel (flattened RGB)
    local channels
    channels=$(magick identify -format "%[channels]" "${screenshot}" 2>/dev/null)
    if [[ "${channels}" == *"a"* ]] || [[ "${channels}" == *"alpha"* ]]; then
        log_error "Screenshot has alpha channel: ${channels}"
        return 1
    fi

    # Check file size < 10MB
    local size
    size=$(stat -f%z "${screenshot}" 2>/dev/null || stat -c%s "${screenshot}" 2>/dev/null)
    if [[ ${size} -gt ${MACOS_MAX_FILE_SIZE} ]]; then
        log_error "Screenshot too large: ${size} bytes (max ${MACOS_MAX_FILE_SIZE})"
        return 1
    fi

    return 0
}
