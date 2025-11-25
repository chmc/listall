#!/bin/bash
set -euo pipefail

# Track CI pipeline performance metrics over time
# Usage: track-performance.sh <run-id>
#        track-performance.sh --latest
#        track-performance.sh --history [N]
#
# Stores metrics in .github/performance-history.csv
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

RUN_ID="${1:-}"
HISTORY_FILE=".github/performance-history.csv"

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

# Handle --history flag
if [ "$RUN_ID" == "--history" ]; then
    LIMIT="${2:-10}"

    if [ ! -f "$HISTORY_FILE" ]; then
        print_error "No performance history found"
        exit 0
    fi

    print_header "📊 Performance History (Last $LIMIT runs)"

    echo ""
    # Show header
    head -1 "$HISTORY_FILE"
    echo ""

    # Show last N entries
    tail -n "$LIMIT" "$HISTORY_FILE" | column -t -s ','

    # Calculate statistics
    print_header "📈 Statistics"

    # Extract timing columns (skip header)
    IPHONE_TIMES=$(tail -n +2 "$HISTORY_FILE" | cut -d',' -f4 | grep -E '^[0-9]+$' || echo "")
    IPAD_TIMES=$(tail -n +2 "$HISTORY_FILE" | cut -d',' -f5 | grep -E '^[0-9]+$' || echo "")
    WATCH_TIMES=$(tail -n +2 "$HISTORY_FILE" | cut -d',' -f6 | grep -E '^[0-9]+$' || echo "")
    TOTAL_TIMES=$(tail -n +2 "$HISTORY_FILE" | cut -d',' -f7 | grep -E '^[0-9]+$' || echo "")

    if [ -n "$IPHONE_TIMES" ]; then
        IPHONE_AVG=$(echo "$IPHONE_TIMES" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
        IPHONE_MIN=$(echo "$IPHONE_TIMES" | sort -n | head -1)
        IPHONE_MAX=$(echo "$IPHONE_TIMES" | sort -n | tail -1)

        echo ""
        echo -e "${BOLD}iPhone Screenshots:${NC}"
        echo "  Average: ${IPHONE_AVG}s"
        echo "  Min: ${IPHONE_MIN}s"
        echo "  Max: ${IPHONE_MAX}s"
    fi

    if [ -n "$IPAD_TIMES" ]; then
        IPAD_AVG=$(echo "$IPAD_TIMES" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
        IPAD_MIN=$(echo "$IPAD_TIMES" | sort -n | head -1)
        IPAD_MAX=$(echo "$IPAD_TIMES" | sort -n | tail -1)

        echo ""
        echo -e "${BOLD}iPad Screenshots:${NC}"
        echo "  Average: ${IPAD_AVG}s"
        echo "  Min: ${IPAD_MIN}s"
        echo "  Max: ${IPAD_MAX}s"
    fi

    if [ -n "$WATCH_TIMES" ]; then
        WATCH_AVG=$(echo "$WATCH_TIMES" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
        WATCH_MIN=$(echo "$WATCH_TIMES" | sort -n | head -1)
        WATCH_MAX=$(echo "$WATCH_TIMES" | sort -n | tail -1)

        echo ""
        echo -e "${BOLD}Watch Screenshots:${NC}"
        echo "  Average: ${WATCH_AVG}s"
        echo "  Min: ${WATCH_MIN}s"
        echo "  Max: ${WATCH_MAX}s"
    fi

    if [ -n "$TOTAL_TIMES" ]; then
        TOTAL_AVG=$(echo "$TOTAL_TIMES" | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')
        TOTAL_MIN=$(echo "$TOTAL_TIMES" | sort -n | head -1)
        TOTAL_MAX=$(echo "$TOTAL_TIMES" | sort -n | tail -1)

        echo ""
        echo -e "${BOLD}Total Pipeline:${NC}"
        echo "  Average: ${TOTAL_AVG}s"
        echo "  Min: ${TOTAL_MIN}s"
        echo "  Max: ${TOTAL_MAX}s"
    fi

    echo ""
    exit 0
fi

# Handle --latest flag
if [ "$RUN_ID" == "--latest" ]; then
    print_info "Fetching latest workflow run..."
    RUN_ID=$(gh run list --workflow=prepare-appstore.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    if [ -z "$RUN_ID" ]; then
        print_error "No workflow runs found"
        exit 1
    fi
    print_info "Analyzing run #$RUN_ID"
fi

if [ -z "$RUN_ID" ]; then
    print_error "Run ID required"
    echo "Usage: $0 <run-id>" >&2
    echo "       $0 --latest" >&2
    echo "       $0 --history [N]" >&2
    exit 1
fi

print_header "⏱️  Performance Tracking"

# Fetch run details
print_info "Fetching run details for #$RUN_ID..."

RUN_JSON=$(gh run view "$RUN_ID" --json databaseId,number,status,conclusion,createdAt,updatedAt,startedAt,jobs 2>/dev/null || echo "")

if [ -z "$RUN_JSON" ]; then
    print_error "Failed to fetch run details"
    exit 1
fi

# Extract basic info
STATUS=$(echo "$RUN_JSON" | jq -r '.status // "unknown"')
CONCLUSION=$(echo "$RUN_JSON" | jq -r '.conclusion // "unknown"')
CREATED_AT=$(echo "$RUN_JSON" | jq -r '.createdAt // ""')
UPDATED_AT=$(echo "$RUN_JSON" | jq -r '.updatedAt // ""')

print_info "Status: $STATUS"
print_info "Conclusion: $CONCLUSION"

# Extract job timings
IPHONE_DURATION=0
IPAD_DURATION=0
WATCH_DURATION=0
UPLOAD_DURATION=0

# Parse jobs
JOBS=$(echo "$RUN_JSON" | jq -c '.jobs[]')

while IFS= read -r job; do
    JOB_NAME=$(echo "$job" | jq -r '.name // ""')
    JOB_STATUS=$(echo "$job" | jq -r '.status // ""')
    JOB_CONCLUSION=$(echo "$job" | jq -r '.conclusion // ""')
    JOB_STARTED=$(echo "$job" | jq -r '.startedAt // ""')
    JOB_COMPLETED=$(echo "$job" | jq -r '.completedAt // ""')

    # Calculate duration
    if [ "$JOB_STATUS" == "completed" ] && [ -n "$JOB_STARTED" ] && [ -n "$JOB_COMPLETED" ]; then
        START_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$JOB_STARTED" "+%s" 2>/dev/null || echo "0")
        END_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$JOB_COMPLETED" "+%s" 2>/dev/null || echo "0")
        DURATION=$((END_TS - START_TS))

        case "$JOB_NAME" in
            *"iPhone"*)
                IPHONE_DURATION=$DURATION
                IPHONE_CONCLUSION=$JOB_CONCLUSION
                ;;
            *"iPad"*)
                IPAD_DURATION=$DURATION
                IPAD_CONCLUSION=$JOB_CONCLUSION
                ;;
            *"Watch"*)
                WATCH_DURATION=$DURATION
                WATCH_CONCLUSION=$JOB_CONCLUSION
                ;;
            *"Upload"*|*"upload"*)
                UPLOAD_DURATION=$DURATION
                UPLOAD_CONCLUSION=$JOB_CONCLUSION
                ;;
        esac
    fi
done <<< "$JOBS"

# Calculate total duration (jobs run in parallel, so max of device jobs + upload)
MAX_DEVICE_DURATION=$IPHONE_DURATION
if [ $IPAD_DURATION -gt $MAX_DEVICE_DURATION ]; then
    MAX_DEVICE_DURATION=$IPAD_DURATION
fi
if [ $WATCH_DURATION -gt $MAX_DEVICE_DURATION ]; then
    MAX_DEVICE_DURATION=$WATCH_DURATION
fi

TOTAL_DURATION=$((MAX_DEVICE_DURATION + UPLOAD_DURATION))

# Display results
print_header "📊 Job Durations"

echo ""
printf "%-20s %10s %12s\n" "Job" "Duration" "Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

format_duration() {
    local seconds=$1
    if [ $seconds -eq 0 ]; then
        echo "N/A"
    elif [ $seconds -lt 60 ]; then
        echo "${seconds}s"
    else
        local minutes=$((seconds / 60))
        local secs=$((seconds % 60))
        echo "${minutes}m ${secs}s"
    fi
}

format_status() {
    local status=$1
    case "$status" in
        success) echo -e "${GREEN}✅ success${NC}" ;;
        failure) echo -e "${RED}❌ failure${NC}" ;;
        cancelled) echo -e "${YELLOW}⚠️  cancelled${NC}" ;;
        *) echo "$status" ;;
    esac
}

printf "%-20s %10s %s\n" "iPhone" "$(format_duration $IPHONE_DURATION)" "$(format_status ${IPHONE_CONCLUSION:-unknown})"
printf "%-20s %10s %s\n" "iPad" "$(format_duration $IPAD_DURATION)" "$(format_status ${IPAD_CONCLUSION:-unknown})"
printf "%-20s %10s %s\n" "Watch" "$(format_duration $WATCH_DURATION)" "$(format_status ${WATCH_CONCLUSION:-unknown})"
printf "%-20s %10s %s\n" "Upload" "$(format_duration $UPLOAD_DURATION)" "$(format_status ${UPLOAD_CONCLUSION:-unknown})"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-20s %10s\n" "Total Pipeline" "$(format_duration $TOTAL_DURATION)"
echo ""

# Save to history file
if [ ! -f "$HISTORY_FILE" ]; then
    # Create header
    echo "run_id,date,status,iphone_sec,ipad_sec,watch_sec,total_sec,conclusion" > "$HISTORY_FILE"
    print_info "Created performance history file: $HISTORY_FILE"
fi

# Append data
DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "$RUN_ID,$DATE,$STATUS,$IPHONE_DURATION,$IPAD_DURATION,$WATCH_DURATION,$TOTAL_DURATION,$CONCLUSION" >> "$HISTORY_FILE"

print_success "Performance data saved to $HISTORY_FILE"

# Performance analysis
print_header "🔍 Performance Analysis"

# Check if performance is degrading
RECENT_RUNS=$(tail -n 5 "$HISTORY_FILE" | tail -n +2)
if [ -n "$RECENT_RUNS" ]; then
    RECENT_TOTAL_AVG=$(echo "$RECENT_RUNS" | cut -d',' -f7 | grep -E '^[0-9]+$' | awk '{sum+=$1; count++} END {if(count>0) print int(sum/count); else print 0}')

    if [ $RECENT_TOTAL_AVG -gt 0 ] && [ $TOTAL_DURATION -gt 0 ]; then
        DIFF_PERCENT=$(awk "BEGIN {print (($TOTAL_DURATION - $RECENT_TOTAL_AVG) * 100) / $RECENT_TOTAL_AVG}")

        if awk -v d="$DIFF_PERCENT" 'BEGIN {exit !(d > 20)}'; then
            print_warning "Performance degradation detected!"
            print_info "This run: $(format_duration $TOTAL_DURATION)"
            print_info "Recent avg: $(format_duration $RECENT_TOTAL_AVG)"
            print_info "Difference: +${DIFF_PERCENT}%"
        elif awk -v d="$DIFF_PERCENT" 'BEGIN {exit !(d < -20)}'; then
            print_success "Performance improvement detected!"
            print_info "This run: $(format_duration $TOTAL_DURATION)"
            print_info "Recent avg: $(format_duration $RECENT_TOTAL_AVG)"
            print_info "Difference: ${DIFF_PERCENT}%"
        else
            print_success "Performance within expected range"
            print_info "This run: $(format_duration $TOTAL_DURATION)"
            print_info "Recent avg: $(format_duration $RECENT_TOTAL_AVG)"
        fi
    fi
fi

# Timeout warnings
print_header "⚠️  Timeout Analysis"

IPHONE_TIMEOUT=5400  # 90 min
IPAD_TIMEOUT=7200    # 120 min
WATCH_TIMEOUT=5400   # 90 min

check_timeout_risk() {
    local name=$1
    local duration=$2
    local timeout=$3
    local usage_percent=$(awk "BEGIN {print ($duration * 100) / $timeout}")

    if awk -v u="$usage_percent" 'BEGIN {exit !(u > 80)}'; then
        print_error "$name using ${usage_percent}% of timeout ($(format_duration $duration) / $(format_duration $timeout))"
    elif awk -v u="$usage_percent" 'BEGIN {exit !(u > 60)}'; then
        print_warning "$name using ${usage_percent}% of timeout ($(format_duration $duration) / $(format_duration $timeout))"
    else
        print_success "$name healthy (${usage_percent}% of timeout)"
    fi
}

if [ $IPHONE_DURATION -gt 0 ]; then
    check_timeout_risk "iPhone" $IPHONE_DURATION $IPHONE_TIMEOUT
fi

if [ $IPAD_DURATION -gt 0 ]; then
    check_timeout_risk "iPad" $IPAD_DURATION $IPAD_TIMEOUT
fi

if [ $WATCH_DURATION -gt 0 ]; then
    check_timeout_risk "Watch" $WATCH_DURATION $WATCH_TIMEOUT
fi

echo ""
print_info "View history: $0 --history"
print_info "View run: gh run view $RUN_ID --web"

exit 0
