#!/bin/bash
set -euo pipefail

# Track GitHub Actions CI costs and usage
# Usage: track-ci-cost.sh [--month YYYY-MM] [--detailed]
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments or API error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Defaults
MONTH=""
DETAILED=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --month)
            MONTH="$2"
            shift 2
            ;;
        --detailed)
            DETAILED=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--month YYYY-MM] [--detailed]"
            echo ""
            echo "Track GitHub Actions CI costs and usage."
            echo ""
            echo "Options:"
            echo "  --month YYYY-MM  Show stats for specific month (default: current)"
            echo "  --detailed       Show detailed per-run breakdown"
            echo "  --help, -h       Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                      # Current month summary"
            echo "  $0 --month 2025-11      # November 2025"
            echo "  $0 --detailed           # Detailed breakdown"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
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

# Set month
if [ -z "$MONTH" ]; then
    MONTH=$(date '+%Y-%m')
fi

print_header "💰 GitHub Actions Cost Tracker"

print_info "Month: $MONTH"
echo ""

# Get repository info
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
if [ -z "$REPO" ]; then
    print_error "Failed to get repository information"
    exit 1
fi

OWNER=$(echo "$REPO" | cut -d'/' -f1)
print_info "Repository: $REPO"
print_info "Owner: $OWNER"

# Fetch workflow runs for the month
START_DATE="${MONTH}-01"
YEAR=$(echo "$MONTH" | cut -d'-' -f1)
MONTH_NUM=$(echo "$MONTH" | cut -d'-' -f2)

# Calculate last day of month
if [ "$MONTH_NUM" == "12" ]; then
    NEXT_MONTH="${YEAR}-01-01"
    NEXT_YEAR=$((YEAR + 1))
    NEXT_MONTH="${NEXT_YEAR}-01-01"
else
    NEXT_MONTH_NUM=$((10#$MONTH_NUM + 1))
    NEXT_MONTH=$(printf "%s-%02d-01" "$YEAR" "$NEXT_MONTH_NUM")
fi

END_DATE=$(date -j -v-1d -f "%Y-%m-%d" "$NEXT_MONTH" "+%Y-%m-%d" 2>/dev/null || date -d "$NEXT_MONTH - 1 day" "+%Y-%m-%d")

print_info "Date range: $START_DATE to $END_DATE"
echo ""

# Fetch runs
print_info "Fetching workflow runs..."

RUNS_JSON=$(gh run list \
    --workflow=prepare-appstore.yml \
    --json databaseId,name,status,conclusion,createdAt,updatedAt \
    --limit 100 \
    2>/dev/null || echo '[]')

if [ "$RUNS_JSON" == "[]" ]; then
    print_warning "No workflow runs found"
    exit 0
fi

# Filter runs by date range
FILTERED_RUNS=$(echo "$RUNS_JSON" | jq --arg start "$START_DATE" --arg end "$END_DATE" \
    '[.[] | select(.createdAt >= $start and .createdAt < $end)]')

RUN_COUNT=$(echo "$FILTERED_RUNS" | jq 'length')

if [ "$RUN_COUNT" == "0" ]; then
    print_warning "No runs found in $MONTH"
    exit 0
fi

print_success "Found $RUN_COUNT runs"

# Initialize counters
TOTAL_MINUTES=0
SUCCESSFUL_RUNS=0
FAILED_RUNS=0
CANCELLED_RUNS=0

# macOS pricing (private repos)
MACOS_RATE=0.08  # $0.08 per minute

print_header "📊 Run Statistics"

# Process each run
echo "$FILTERED_RUNS" | jq -c '.[]' | while IFS= read -r run; do
    RUN_ID=$(echo "$run" | jq -r '.databaseId')
    STATUS=$(echo "$run" | jq -r '.status')
    CONCLUSION=$(echo "$run" | jq -r '.conclusion // "unknown"')
    CREATED=$(echo "$run" | jq -r '.createdAt')

    # Track conclusions
    case "$CONCLUSION" in
        success)
            SUCCESSFUL_RUNS=$((SUCCESSFUL_RUNS + 1))
            ;;
        failure)
            FAILED_RUNS=$((FAILED_RUNS + 1))
            ;;
        cancelled)
            CANCELLED_RUNS=$((CANCELLED_RUNS + 1))
            ;;
    esac

    # Fetch detailed run info for timing
    RUN_DETAILS=$(gh run view "$RUN_ID" --json jobs 2>/dev/null || echo '{"jobs":[]}')

    # Calculate total minutes for this run
    RUN_MINUTES=0
    echo "$RUN_DETAILS" | jq -c '.jobs[]?' | while IFS= read -r job; do
        JOB_STATUS=$(echo "$job" | jq -r '.status // ""')

        if [ "$JOB_STATUS" == "completed" ]; then
            STARTED=$(echo "$job" | jq -r '.startedAt // ""')
            COMPLETED=$(echo "$job" | jq -r '.completedAt // ""')

            if [ -n "$STARTED" ] && [ -n "$COMPLETED" ]; then
                START_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED" "+%s" 2>/dev/null || echo "0")
                END_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$COMPLETED" "+%s" 2>/dev/null || echo "0")

                if [ $START_TS -gt 0 ] && [ $END_TS -gt 0 ]; then
                    DURATION_SEC=$((END_TS - START_TS))
                    DURATION_MIN=$((DURATION_SEC / 60))
                    RUN_MINUTES=$((RUN_MINUTES + DURATION_MIN))
                fi
            fi
        fi
    done

    TOTAL_MINUTES=$((TOTAL_MINUTES + RUN_MINUTES))

    if [ "$DETAILED" = true ] && [ $RUN_MINUTES -gt 0 ]; then
        DATE=$(echo "$CREATED" | cut -d'T' -f1)
        COST=$(awk "BEGIN {printf \"%.2f\", $RUN_MINUTES * $MACOS_RATE}")
        echo "  Run $RUN_ID ($DATE): ${RUN_MINUTES} min, \$${COST}, $CONCLUSION"
    fi

done | tee /tmp/cost_output.txt

# Read totals from temp output
SUCCESSFUL_RUNS=$(echo "$FILTERED_RUNS" | jq '[.[] | select(.conclusion == "success")] | length')
FAILED_RUNS=$(echo "$FILTERED_RUNS" | jq '[.[] | select(.conclusion == "failure")] | length')
CANCELLED_RUNS=$(echo "$FILTERED_RUNS" | jq '[.[] | select(.conclusion == "cancelled")] | length')

# Parse total minutes from detailed output
if [ "$DETAILED" = true ]; then
    TOTAL_MINUTES=$(grep -oE '[0-9]+ min' /tmp/cost_output.txt | grep -oE '[0-9]+' | awk '{sum+=$1} END {print sum}')
fi
rm -f /tmp/cost_output.txt

echo ""
echo -e "${BOLD}Total Runs:${NC} $RUN_COUNT"
echo -e "  ${GREEN}✅ Successful:${NC} $SUCCESSFUL_RUNS"
echo -e "  ${RED}❌ Failed:${NC} $FAILED_RUNS"
echo -e "  ${YELLOW}⚠️  Cancelled:${NC} $CANCELLED_RUNS"

# Estimate total minutes (if not detailed)
if [ $TOTAL_MINUTES -eq 0 ]; then
    # Estimate based on average duration (60 min per successful run)
    AVG_DURATION=60
    TOTAL_MINUTES=$((SUCCESSFUL_RUNS * AVG_DURATION + FAILED_RUNS * 30 + CANCELLED_RUNS * 15))
    print_warning "Minutes estimated (use --detailed for accurate count)"
fi

print_header "💵 Cost Breakdown"

# Calculate costs
TOTAL_COST=$(awk "BEGIN {printf \"%.2f\", $TOTAL_MINUTES * $MACOS_RATE}")
TOTAL_HOURS=$(awk "BEGIN {printf \"%.1f\", $TOTAL_MINUTES / 60}")

echo ""
echo -e "${BOLD}Total Minutes:${NC} $TOTAL_MINUTES ($TOTAL_HOURS hours)"
echo -e "${BOLD}macOS Runner Rate:${NC} \$${MACOS_RATE}/min"
echo -e "${BOLD}Total Cost:${NC} \$${TOTAL_COST}"

# Projections
print_header "📈 Projections"

# Days elapsed in month
CURRENT_DATE=$(date '+%Y-%m-%d')
if [[ "$CURRENT_DATE" > "$START_DATE" ]] && [[ "$CURRENT_DATE" < "$END_DATE" ]]; then
    DAYS_ELAPSED=$(( ($(date +%s) - $(date -j -f "%Y-%m-%d" "$START_DATE" "+%s")) / 86400 ))
    DAYS_IN_MONTH=$(( ($(date -j -f "%Y-%m-%d" "$END_DATE" "+%s") - $(date -j -f "%Y-%m-%d" "$START_DATE" "+%s")) / 86400 ))

    if [ $DAYS_ELAPSED -gt 0 ]; then
        DAILY_COST=$(awk "BEGIN {printf \"%.2f\", $TOTAL_COST / $DAYS_ELAPSED}")
        PROJECTED_COST=$(awk "BEGIN {printf \"%.2f\", $DAILY_COST * $DAYS_IN_MONTH}")

        echo ""
        echo -e "${BOLD}Days Elapsed:${NC} $DAYS_ELAPSED / $DAYS_IN_MONTH"
        echo -e "${BOLD}Daily Average:${NC} \$${DAILY_COST}"
        echo -e "${BOLD}Projected Month Cost:${NC} \$${PROJECTED_COST}"
    fi
fi

# GitHub Actions limits
print_header "📊 GitHub Limits"

echo ""
echo "Free Tier (Public repos):"
echo "  - Unlimited minutes"
echo "  - 2GB artifact storage"
echo ""
echo "Free Tier (Private repos):"
echo "  - 2,000 Linux minutes/month"
echo "  - 10x multiplier for macOS = 200 macOS minutes"
echo "  - Additional: \$0.008/min (Linux), \$0.08/min (macOS)"
echo ""

# Check if over free tier
FREE_MACOS_MINUTES=200
if [ $TOTAL_MINUTES -gt $FREE_MACOS_MINUTES ]; then
    OVERAGE_MINUTES=$((TOTAL_MINUTES - FREE_MACOS_MINUTES))
    OVERAGE_COST=$(awk "BEGIN {printf \"%.2f\", $OVERAGE_MINUTES * $MACOS_RATE}")

    print_warning "Over free tier by $OVERAGE_MINUTES minutes"
    echo -e "  Free tier cost: \$0.00"
    echo -e "  Overage cost: \$${OVERAGE_COST}"
else
    REMAINING=$((FREE_MACOS_MINUTES - TOTAL_MINUTES))
    print_success "Within free tier ($REMAINING minutes remaining)"
fi

# Optimization tips
print_header "💡 Cost Optimization Tips"

echo ""
echo "1. **Reduce job timeouts** - Current: 90-120 min"
echo "   Actual usage: ~20 min → Could reduce to 40-60 min"
echo ""
echo "2. **Cache dependencies** - Bundle gems, Homebrew packages"
echo ""
echo "3. **Optimize pre-boot** - Already done! (76% faster)"
echo ""
echo "4. **Reduce retries** - Currently 2 attempts (good)"
echo ""
echo "5. **Test locally first** - Use test-pipeline-locally.sh"
echo "   Saves ~60 min × \$0.08 = \$4.80 per avoided CI run"
echo ""
echo "6. **Clean artifacts** - Run cleanup-artifacts.sh monthly"
echo ""
echo "7. **Monitor performance** - Use track-performance.sh"
echo "   Catch degradation early"

# Cost per successful release
print_header "📦 Cost Per Release"

if [ $SUCCESSFUL_RUNS -gt 0 ]; then
    COST_PER_SUCCESS=$(awk "BEGIN {printf \"%.2f\", $TOTAL_COST / $SUCCESSFUL_RUNS}")
    MINUTES_PER_SUCCESS=$((TOTAL_MINUTES / SUCCESSFUL_RUNS))

    echo ""
    echo -e "${BOLD}Successful Releases:${NC} $SUCCESSFUL_RUNS"
    echo -e "${BOLD}Average Time:${NC} $MINUTES_PER_SUCCESS minutes"
    echo -e "${BOLD}Cost Per Release:${NC} \$${COST_PER_SUCCESS}"
fi

exit 0
