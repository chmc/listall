#!/bin/bash
set -euo pipefail

# Monitor active CI pipeline runs and alert when they complete
# Usage: monitor-active-runs.sh [--watch]
#
# Exit codes:
#   0 - Success
#   1 - Invalid arguments

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

WATCH_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --watch)
            WATCH_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--watch]"
            echo ""
            echo "Monitor active CI pipeline runs and alert when they complete."
            echo ""
            echo "Options:"
            echo "  --watch       Continuously monitor and refresh every 2 minutes"
            echo "  --help, -h    Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

monitor_runs() {
    clear
    echo -e "${BOLD}=== CI Pipeline Monitor ===${NC}"
    echo -e "Time: $(date '+%Y-%m-%d %H:%M:%S')\n"

    # Check dependencies
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) not installed"
        exit 1
    fi

    # Get active runs
    RUNS=$(gh run list --workflow=prepare-appstore.yml --limit 10 --json databaseId,number,status,conclusion,createdAt,headSha 2>/dev/null || echo '[]')

    if [ "$RUNS" = "[]" ]; then
        print_error "Failed to fetch runs"
        return 1
    fi

    # Count active runs
    ACTIVE_COUNT=$(echo "$RUNS" | jq '[.[] | select(.status != "completed")] | length')
    COMPLETED_COUNT=$(echo "$RUNS" | jq '[.[] | select(.status == "completed" and .conclusion != "")] | length')

    echo -e "${BOLD}📊 Summary:${NC}"
    echo "  Active Runs: $ACTIVE_COUNT"
    echo "  Recently Completed: $COMPLETED_COUNT"
    echo ""

    # Show active runs with details
    if [ $ACTIVE_COUNT -gt 0 ]; then
        echo -e "${BOLD}🔄 Active Runs:${NC}\n"

        echo "$RUNS" | jq -c '.[] | select(.status != "completed")' | while IFS= read -r run; do
            RUN_ID=$(echo "$run" | jq -r '.databaseId')
            RUN_NUM=$(echo "$run" | jq -r '.number')
            STATUS=$(echo "$run" | jq -r '.status')
            CREATED=$(echo "$run" | jq -r '.createdAt')
            COMMIT=$(echo "$run" | jq -r '.headSha' | cut -c1-7)

            # Calculate elapsed time
            CREATED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED" "+%s" 2>/dev/null || echo "0")
            NOW_TS=$(date "+%s")
            ELAPSED=$((NOW_TS - CREATED_TS))
            ELAPSED_MIN=$((ELAPSED / 60))
            ELAPSED_HR=$((ELAPSED_MIN / 60))
            ELAPSED_MIN_REMAINDER=$((ELAPSED_MIN % 60))

            if [ $STATUS = "in_progress" ]; then
                print_info "Run #$RUN_NUM ($RUN_ID) - ${ELAPSED_HR}h ${ELAPSED_MIN_REMAINDER}m elapsed"
            else
                print_warning "Run #$RUN_NUM ($RUN_ID) - Status: $STATUS"
            fi

            # Get job details
            JOBS=$(gh run view "$RUN_ID" --json jobs --jq '.jobs[] | {name: .name, status: .status, conclusion: .conclusion, started: .startedAt, completed: .completedAt}' 2>/dev/null || echo "")

            if [ -n "$JOBS" ]; then
                echo "$JOBS" | jq -c '.' | while IFS= read -r job; do
                    JOB_NAME=$(echo "$job" | jq -r '.name')
                    JOB_STATUS=$(echo "$job" | jq -r '.status')
                    JOB_CONCLUSION=$(echo "$job" | jq -r '.conclusion')
                    JOB_STARTED=$(echo "$job" | jq -r '.started')
                    JOB_COMPLETED=$(echo "$job" | jq -r '.completed')

                    # Calculate job duration
                    if [ "$JOB_COMPLETED" != "0001-01-01T00:00:00Z" ]; then
                        STARTED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$JOB_STARTED" "+%s" 2>/dev/null || echo "0")
                        COMPLETED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$JOB_COMPLETED" "+%s" 2>/dev/null || echo "0")
                        JOB_DURATION=$((COMPLETED_TS - STARTED_TS))
                        JOB_DURATION_MIN=$((JOB_DURATION / 60))

                        if [ "$JOB_CONCLUSION" = "success" ]; then
                            echo -e "    ${GREEN}✅${NC} $JOB_NAME: ${JOB_DURATION_MIN}m"
                        elif [ "$JOB_CONCLUSION" = "failure" ]; then
                            echo -e "    ${RED}❌${NC} $JOB_NAME: ${JOB_DURATION_MIN}m (failed)"
                        else
                            echo -e "    ${YELLOW}⚠️${NC} $JOB_NAME: ${JOB_DURATION_MIN}m ($JOB_CONCLUSION)"
                        fi
                    else
                        STARTED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$JOB_STARTED" "+%s" 2>/dev/null || echo "0")
                        JOB_ELAPSED=$((NOW_TS - STARTED_TS))
                        JOB_ELAPSED_MIN=$((JOB_ELAPSED / 60))

                        if [ $JOB_STATUS = "in_progress" ]; then
                            # Check if approaching timeout
                            TIMEOUT_LIMIT=90
                            if echo "$JOB_NAME" | grep -qi "iPad"; then
                                TIMEOUT_LIMIT=120
                            fi

                            TIMEOUT_PERCENT=$((JOB_ELAPSED_MIN * 100 / TIMEOUT_LIMIT))

                            if [ $TIMEOUT_PERCENT -gt 100 ]; then
                                echo -e "    ${RED}🚨${NC} $JOB_NAME: ${JOB_ELAPSED_MIN}m (OVER TIMEOUT)"
                            elif [ $TIMEOUT_PERCENT -gt 80 ]; then
                                echo -e "    ${YELLOW}⚠️${NC} $JOB_NAME: ${JOB_ELAPSED_MIN}m (${TIMEOUT_PERCENT}% of timeout)"
                            else
                                echo -e "    ${BLUE}⏳${NC} $JOB_NAME: ${JOB_ELAPSED_MIN}m"
                            fi
                        elif [ $JOB_STATUS = "queued" ]; then
                            echo -e "    ${BLUE}🕐${NC} $JOB_NAME: queued"
                        else
                            echo -e "    ${BLUE}•${NC} $JOB_NAME: $JOB_STATUS"
                        fi
                    fi
                done
            fi

            echo ""
        done
    fi

    # Show recently completed runs
    if [ $COMPLETED_COUNT -gt 0 ]; then
        echo -e "${BOLD}✅ Recently Completed:${NC}\n"

        echo "$RUNS" | jq -c '.[] | select(.status == "completed" and .conclusion != "")' | head -n 3 | while IFS= read -r run; do
            RUN_ID=$(echo "$run" | jq -r '.databaseId')
            RUN_NUM=$(echo "$run" | jq -r '.number')
            CONCLUSION=$(echo "$run" | jq -r '.conclusion')
            CREATED=$(echo "$run" | jq -r '.createdAt')
            COMMIT=$(echo "$run" | jq -r '.headSha' | cut -c1-7)

            if [ "$CONCLUSION" = "success" ]; then
                print_success "Run #$RUN_NUM ($RUN_ID) - SUCCESS at commit $COMMIT"
                echo "  Analyze: .github/scripts/track-performance.sh $RUN_ID"
            elif [ "$CONCLUSION" = "failure" ]; then
                print_error "Run #$RUN_NUM ($RUN_ID) - FAILED at commit $COMMIT"
                echo "  Analyze: .github/scripts/analyze-ci-failure.sh $RUN_ID"
            else
                print_warning "Run #$RUN_NUM ($RUN_ID) - $CONCLUSION at commit $COMMIT"
            fi
            echo ""
        done
    fi

    # Show recommended actions
    if [ $ACTIVE_COUNT -gt 0 ]; then
        echo -e "${BOLD}💡 Recommended Actions:${NC}"
        echo "  • Keep monitoring active runs"
        echo "  • Run analyzer when complete: .github/scripts/analyze-ci-failure.sh <run-id>"
        echo "  • Track performance: .github/scripts/track-performance.sh <run-id>"
        echo "  • Compare results: see pipeline-runs-comparison.md"
    else
        echo -e "${BOLD}💡 Next Steps:${NC}"
        echo "  • Analyze completed runs"
        echo "  • Compare performance across commits"
        echo "  • Review pipeline-runs-comparison.md for details"
    fi
}

# Main execution
if [ "$WATCH_MODE" = true ]; then
    echo "Starting continuous monitoring (Ctrl+C to stop)..."
    echo "Refreshing every 2 minutes..."
    sleep 2

    while true; do
        monitor_runs
        echo ""
        echo -e "${BLUE}Next refresh in 2 minutes...${NC}"
        sleep 120
    done
else
    monitor_runs
fi

exit 0
