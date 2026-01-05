#!/bin/bash
#
# check-cloudkit-schema.sh
#
# Compares CloudKit Development vs Production schemas.
# Fails if Development has changes not deployed to Production.
#
# Requirements:
# - macOS with Xcode 13+
# - CLOUDKIT_MANAGEMENT_TOKEN environment variable
# - APPLE_TEAM_ID environment variable (or pass as argument)
#
# Usage:
#   ./check-cloudkit-schema.sh [TEAM_ID]
#
set -euo pipefail

TEAM_ID="${1:-${APPLE_TEAM_ID:-}}"
CONTAINER_ID="iCloud.io.github.chmc.ListAll"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Validate required environment
if [[ -z "${TEAM_ID}" ]]; then
    log_error "APPLE_TEAM_ID not set. Pass as argument or set environment variable."
    exit 1
fi

if [[ -z "${CLOUDKIT_MANAGEMENT_TOKEN:-}" ]]; then
    log_error "CLOUDKIT_MANAGEMENT_TOKEN not set."
    log_error "Get it from: https://icloud.developer.apple.com/ -> API Tokens"
    exit 1
fi

# Check cktool is available
if ! xcrun cktool --help &>/dev/null; then
    log_error "cktool not found. Requires Xcode 13+."
    exit 1
fi

log_info "Checking CloudKit schema drift..."
log_info "Container: ${CONTAINER_ID}"
log_info "Team: ${TEAM_ID}"

# Create temp directory for schema files
SCHEMA_DIR=$(mktemp -d)
trap 'rm -rf "${SCHEMA_DIR}"' EXIT

DEV_SCHEMA="${SCHEMA_DIR}/development.ckdb"
PROD_SCHEMA="${SCHEMA_DIR}/production.ckdb"

# Export Development schema
log_info "Exporting Development schema..."
if ! xcrun cktool export-schema \
    --team-id "${TEAM_ID}" \
    --container-id "${CONTAINER_ID}" \
    --environment development \
    --output-file "${DEV_SCHEMA}" 2>&1; then
    log_error "Failed to export Development schema"
    exit 1
fi

# Export Production schema
log_info "Exporting Production schema..."
if ! xcrun cktool export-schema \
    --team-id "${TEAM_ID}" \
    --container-id "${CONTAINER_ID}" \
    --environment production \
    --output-file "${PROD_SCHEMA}" 2>&1; then
    log_error "Failed to export Production schema"
    exit 1
fi

# Compare schemas
log_info "Comparing schemas..."

if diff -q "${PROD_SCHEMA}" "${DEV_SCHEMA}" &>/dev/null; then
    log_info "Schemas match - no drift detected"
    echo ""
    echo "Development and Production CloudKit schemas are in sync."
    exit 0
else
    log_error "Schema drift detected!"
    echo ""
    echo "Development schema has changes not deployed to Production:"
    echo ""
    echo "--- Production"
    echo "+++ Development"
    diff -u "${PROD_SCHEMA}" "${DEV_SCHEMA}" || true
    echo ""
    log_error "You must deploy schema changes via CloudKit Dashboard before releasing."
    log_error "Go to: https://icloud.developer.apple.com/"
    log_error "Select container -> Schema -> Deploy Schema Changes..."
    echo ""

    # GitHub Actions annotation
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        echo "::error::CloudKit schema drift detected! Deploy schema via CloudKit Dashboard before releasing."
    fi

    exit 1
fi
