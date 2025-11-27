#!/bin/bash
set -euo pipefail

# Cleanup old GitHub Actions artifacts to save storage
# Usage: cleanup-artifacts.sh [--older-than DAYS] [--dry-run]
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments or gh command failed

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
DAYS_OLD=30
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --older-than)
            DAYS_OLD="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--older-than DAYS] [--dry-run]"
            echo ""
            echo "Cleanup old GitHub Actions artifacts to save storage."
            echo ""
            echo "Options:"
            echo "  --older-than DAYS  Delete artifacts older than N days (default: 30)"
            echo "  --dry-run          Show what would be deleted without deleting"
            echo "  --help, -h         Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                           # Delete artifacts older than 30 days"
            echo "  $0 --older-than 60           # Delete artifacts older than 60 days"
            echo "  $0 --older-than 7 --dry-run  # Preview what would be deleted"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Check dependencies
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) not installed"
    echo "Install: brew install gh" >&2
    exit 1
fi

print_header "🧹 Artifact Cleanup"

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No artifacts will be deleted"
fi

print_info "Cleaning artifacts older than $DAYS_OLD days"
echo ""

# Get repository info
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
if [ -z "$REPO" ]; then
    print_error "Failed to get repository information"
    print_info "Make sure you're in a git repository with GitHub remote"
    exit 1
fi

print_info "Repository: $REPO"

# Calculate cutoff date
CUTOFF_DATE=$(date -v-${DAYS_OLD}d '+%Y-%m-%d' 2>/dev/null || date -d "${DAYS_OLD} days ago" '+%Y-%m-%d' 2>/dev/null)
CUTOFF_TS=$(date -j -f "%Y-%m-%d" "$CUTOFF_DATE" "+%s" 2>/dev/null || date -d "$CUTOFF_DATE" "+%s")

print_info "Cutoff date: $CUTOFF_DATE"
echo ""

# Fetch artifacts
print_info "Fetching artifacts..."

ARTIFACTS_JSON=$(gh api "repos/$REPO/actions/artifacts?per_page=100" 2>/dev/null || echo '{"artifacts":[]}')

if [ -z "$ARTIFACTS_JSON" ] || [ "$ARTIFACTS_JSON" = '{"artifacts":[]}' ]; then
    print_info "No artifacts found"
    exit 0
fi

# Parse and filter artifacts
TOTAL_COUNT=0
OLD_COUNT=0
TOTAL_SIZE=0
OLD_SIZE=0
DELETED_COUNT=0

echo "$ARTIFACTS_JSON" | jq -c '.artifacts[]' | while IFS= read -r artifact; do
    ARTIFACT_ID=$(echo "$artifact" | jq -r '.id')
    ARTIFACT_NAME=$(echo "$artifact" | jq -r '.name')
    CREATED_AT=$(echo "$artifact" | jq -r '.created_at')
    SIZE_BYTES=$(echo "$artifact" | jq -r '.size_in_bytes')

    # Convert size to MB
    SIZE_MB=$(awk "BEGIN {print $SIZE_BYTES / 1024 / 1024}")

    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    TOTAL_SIZE=$((TOTAL_SIZE + SIZE_BYTES))

    # Parse creation date
    CREATED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED_AT" "+%s" 2>/dev/null || echo "0")

    # Check if older than cutoff
    if [ $CREATED_TS -lt $CUTOFF_TS ] && [ $CREATED_TS -gt 0 ]; then
        OLD_COUNT=$((OLD_COUNT + 1))
        OLD_SIZE=$((OLD_SIZE + SIZE_BYTES))

        AGE_DAYS=$(( ($(date +%s) - CREATED_TS) / 86400 ))

        if [ "$DRY_RUN" = true ]; then
            echo -e "${YELLOW}Would delete:${NC} $ARTIFACT_NAME (${SIZE_MB} MB, ${AGE_DAYS} days old)"
        else
            echo -e "${YELLOW}Deleting:${NC} $ARTIFACT_NAME (${SIZE_MB} MB, ${AGE_DAYS} days old)"

            if gh api "repos/$REPO/actions/artifacts/$ARTIFACT_ID" -X DELETE 2>/dev/null; then
                DELETED_COUNT=$((DELETED_COUNT + 1))
                echo -e "  ${GREEN}✓${NC} Deleted"
            else
                echo -e "  ${RED}✗${NC} Failed to delete"
            fi
        fi
    fi
done | tee /tmp/cleanup_output.txt

# Read counters from temp output (since subshell doesn't propagate variables)
# Note: grep -c returns exit 1 when count is 0, so we use || true and default to 0
OLD_COUNT=$(grep -c "Would delete:\|Deleting:" /tmp/cleanup_output.txt 2>/dev/null || true)
OLD_COUNT=${OLD_COUNT:-0}
DELETED_COUNT=$(grep -c "✓ Deleted" /tmp/cleanup_output.txt 2>/dev/null || true)
DELETED_COUNT=${DELETED_COUNT:-0}
rm -f /tmp/cleanup_output.txt

# Get total artifacts count
TOTAL_COUNT=$(echo "$ARTIFACTS_JSON" | jq '.artifacts | length')

# Calculate total size
TOTAL_SIZE_MB=$(echo "$ARTIFACTS_JSON" | jq '[.artifacts[].size_in_bytes] | add / 1024 / 1024' | awk '{printf "%.2f", $1}')

# Calculate old size (approximate based on old count ratio)
if [ $TOTAL_COUNT -gt 0 ]; then
    OLD_SIZE_MB=$(echo "$ARTIFACTS_JSON" | jq --argjson cutoff "$CUTOFF_TS" '[.artifacts[] | select((.created_at | fromdateiso8601) < $cutoff) | .size_in_bytes] | add / 1024 / 1024' | awk '{printf "%.2f", $1}')
else
    OLD_SIZE_MB="0.00"
fi

# Summary
print_header "📊 Summary"

echo ""
echo -e "${BOLD}Total Artifacts:${NC} $TOTAL_COUNT (${TOTAL_SIZE_MB} MB)"
echo -e "${BOLD}Old Artifacts (>$DAYS_OLD days):${NC} $OLD_COUNT (${OLD_SIZE_MB} MB)"

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Would delete:${NC} $OLD_COUNT artifacts (${OLD_SIZE_MB} MB)"
    echo ""
    print_warning "This was a dry run - no artifacts were deleted"
    print_info "Run without --dry-run to actually delete"
else
    echo -e "${GREEN}Deleted:${NC} $DELETED_COUNT artifacts"

    if [ $DELETED_COUNT -lt $OLD_COUNT ]; then
        FAILED=$((OLD_COUNT - DELETED_COUNT))
        print_warning "$FAILED artifact(s) failed to delete"
    fi

    echo ""
    print_success "Cleanup complete!"
    print_info "Freed approximately ${OLD_SIZE_MB} MB"
fi

# Storage recommendations
print_header "💡 Storage Tips"

if [ $TOTAL_COUNT -gt 100 ]; then
    print_warning "You have $TOTAL_COUNT artifacts - consider more aggressive cleanup"
    print_info "Try: $0 --older-than 14"
fi

if [ "$TOTAL_SIZE_MB" != "null" ] && awk "BEGIN {exit !($TOTAL_SIZE_MB > 1000)}"; then
    print_warning "Total artifact size: ${TOTAL_SIZE_MB} MB (>1GB)"
    print_info "GitHub has 2GB storage limit on free plan"
fi

echo ""
print_info "Artifact retention settings:"
echo "  - Default: 90 days (GitHub Actions default)"
echo "  - Recommended: 30-60 days for screenshot artifacts"
echo "  - Test results: 7-14 days sufficient"
echo ""
print_info "Configure in workflow:"
echo "  uses: actions/upload-artifact@v4"
echo "  with:"
echo "    retention-days: 30"

exit 0
