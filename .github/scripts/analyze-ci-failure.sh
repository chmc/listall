#!/bin/bash
set -euo pipefail

# Analyze GitHub Actions CI logs to diagnose screenshot pipeline failures
# Usage: analyze-ci-failure.sh <run-id>
#        analyze-ci-failure.sh --latest
#        gh run view <run-id> --log | analyze-ci-failure.sh --stdin
#
# Exit codes:
#   0 - Analysis completed (may have found issues)
#   1 - Invalid arguments or gh command failed

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

RUN_ID="${1:-}"

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_issue() {
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

# Check if we have gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) not installed" >&2
    echo "Install: brew install gh" >&2
    exit 1
fi

# Get logs
LOG_FILE=$(mktemp)
trap 'rm -f "$LOG_FILE"' EXIT

if [ "$RUN_ID" == "--stdin" ]; then
    # Read from stdin
    cat > "$LOG_FILE"
elif [ "$RUN_ID" == "--latest" ]; then
    # Get latest run
    print_info "Fetching latest workflow run..."
    RUN_ID=$(gh run list --workflow=prepare-appstore.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    if [ -z "$RUN_ID" ]; then
        echo "❌ Error: No workflow runs found" >&2
        exit 1
    fi
    print_info "Analyzing run #$RUN_ID"
    gh run view "$RUN_ID" --log > "$LOG_FILE"
elif [ -z "$RUN_ID" ]; then
    echo "❌ Error: Run ID required" >&2
    echo "Usage: $0 <run-id>" >&2
    echo "       $0 --latest" >&2
    echo "       gh run view <run-id> --log | $0 --stdin" >&2
    exit 1
else
    # Fetch specific run
    print_info "Fetching logs for run #$RUN_ID..."
    if ! gh run view "$RUN_ID" --log > "$LOG_FILE"; then
        echo "❌ Error: Failed to fetch run logs" >&2
        exit 1
    fi
fi

# Analysis counters
ERRORS=0
WARNINGS=0
SUSPICIOUS=0

print_header "🔍 CI Failure Analysis"

# Check run status
if grep -q "conclusion: failure" "$LOG_FILE" || grep -q "❌" "$LOG_FILE"; then
    print_issue "Run failed"
    ERRORS=$((ERRORS + 1))
elif grep -q "conclusion: cancelled" "$LOG_FILE"; then
    print_warning "Run was cancelled"
    WARNINGS=$((WARNINGS + 1))
elif grep -q "conclusion: success" "$LOG_FILE"; then
    print_success "Run succeeded"
else
    print_info "Run status unknown"
fi

# Analyze pre-flight failures
print_header "1️⃣ Pre-flight Checks"

if grep -qi "Xcode.*not found" "$LOG_FILE" || grep -qi "xcode.*version.*mismatch" "$LOG_FILE"; then
    print_issue "Xcode version issue detected"
    grep -i "xcode" "$LOG_FILE" | grep -v "xcode-select" | head -3
    echo ""
    print_info "Fix: Check if GitHub runner image changed"
    print_info "See: TROUBLESHOOTING.md#pre-flight-check-failures"
    ERRORS=$((ERRORS + 1))
fi

if grep -qi "simulator not found" "$LOG_FILE" || grep -qi "No available simulator" "$LOG_FILE"; then
    print_issue "Simulator not found"
    grep -i "simulator.*not found\|No available simulator" "$LOG_FILE" | head -3
    echo ""
    print_info "Fix: Check simulator names in workflow match available simulators"
    print_info "See: TROUBLESHOOTING.md#simulator-not-found"
    ERRORS=$((ERRORS + 1))
fi

if grep -qi "ruby.*not found\|bundler.*not found" "$LOG_FILE"; then
    print_issue "Ruby/Bundler issue"
    grep -i "ruby\|bundler" "$LOG_FILE" | grep -i "not found\|error" | head -3
    echo ""
    print_info "Fix: Check ruby/setup-ruby@v1 step in workflow"
    ERRORS=$((ERRORS + 1))
fi

# Analyze simulator boot failures
print_header "2️⃣ Simulator Boot"

if grep -qi "Unable to boot device\|Simulator failed to boot\|bootstatus.*failed" "$LOG_FILE"; then
    print_issue "Simulator boot failure detected"
    grep -i "unable to boot\|failed to boot\|bootstatus" "$LOG_FILE" | head -5
    echo ""
    print_info "Fix: Check for simulator state corruption"
    print_info "See: TROUBLESHOOTING.md#simulator-boot-failures"
    ERRORS=$((ERRORS + 1))
fi

if grep -qi "Multiple devices matched" "$LOG_FILE"; then
    print_issue "Duplicate simulators found"
    grep -i "multiple devices" "$LOG_FILE" | head -3
    echo ""
    print_info "Fix: cleanup-watch-duplicates.sh should handle this"
    print_info "See: TROUBLESHOOTING.md#multiple-devices-matched"
    ERRORS=$((ERRORS + 1))
fi

# Analyze screenshot generation failures
print_header "3️⃣ Screenshot Generation"

if grep -qi "timeout\|timed out\|Execution timed out" "$LOG_FILE"; then
    print_issue "Timeout detected"
    grep -i "timeout\|timed out" "$LOG_FILE" | head -5
    echo ""

    # Check which job timed out
    if grep -qi "Generate iPhone screenshots.*timeout\|screenshots_iphone.*timeout" "$LOG_FILE"; then
        print_info "iPhone job timed out"
        print_info "Current timeout: 45min per attempt (90min total)"
    elif grep -qi "Generate iPad screenshots.*timeout\|screenshots_ipad.*timeout" "$LOG_FILE"; then
        print_info "iPad job timed out"
        print_info "Current timeout: 60min per attempt (120min total)"
    elif grep -qi "Generate Watch screenshots.*timeout\|watch_screenshots.*timeout" "$LOG_FILE"; then
        print_info "Watch job timed out"
        print_info "Current timeout: 45min per attempt (90min total)"
    fi

    print_info "Fix: Check if pre-boot succeeded, increase timeout if needed"
    print_info "See: TROUBLESHOOTING.md#screenshot-generation-timeouts"
    ERRORS=$((ERRORS + 1))
fi

if grep -qi "App failed to launch\|launch attempt.*failed" "$LOG_FILE"; then
    print_issue "App launch failures detected"
    grep -i "app.*launch\|launch attempt" "$LOG_FILE" | head -5
    echo ""
    print_info "Fix: Check test implementation and simulator readiness"
    ERRORS=$((ERRORS + 1))
fi

if grep -qi "Failed to terminate.*Runner" "$LOG_FILE"; then
    print_warning "App termination issue (iPad common)"
    grep -i "failed to terminate" "$LOG_FILE" | head -3
    echo ""
    print_info "This is a known iPad simulator issue, retry should handle it"
    print_info "See: TROUBLESHOOTING.md#failed-to-terminate-error"
    WARNINGS=$((WARNINGS + 1))
fi

# Analyze screenshot validation failures
print_header "4️⃣ Screenshot Validation"

if grep -qi "Wrong dimensions\|dimensions.*failed" "$LOG_FILE"; then
    print_issue "Screenshot dimension validation failed"
    grep -i "wrong dimensions\|Expected:.*Actual:" "$LOG_FILE" | head -5
    echo ""
    print_info "Fix: Check if correct device generated screenshots"
    print_info "See: TROUBLESHOOTING.md#screenshot-validation-failures"
    ERRORS=$((ERRORS + 1))
fi

if grep -qi "No PNG screenshots found\|No screenshots captured" "$LOG_FILE"; then
    print_issue "No screenshots were generated"
    grep -i "no.*screenshot" "$LOG_FILE" | head -3
    echo ""
    print_info "Fix: Check if tests actually ran and snapshot() was called"
    print_info "See: TROUBLESHOOTING.md#no-png-screenshots-found"
    ERRORS=$((ERRORS + 1))
fi

if grep -qi "Possibly blank.*screenshot\|brightness:" "$LOG_FILE"; then
    print_warning "Blank screenshots detected"
    grep -i "possibly blank\|brightness:" "$LOG_FILE" | head -5
    echo ""
    print_info "Screenshots may have been captured before UI loaded"
    print_info "See: TROUBLESHOOTING.md#possibly-blank-screenshot"
    SUSPICIOUS=$((SUSPICIOUS + 1))
fi

# Analyze ImageMagick failures
print_header "5️⃣ ImageMagick"

if grep -qi "ImageMagick.*not found\|magick.*not found\|identify.*not found" "$LOG_FILE"; then
    print_issue "ImageMagick not found"
    grep -i "imagemagick\|magick.*not found" "$LOG_FILE" | head -3
    echo ""
    print_info "Fix: Check if ImageMagick install step ran before usage"
    print_info "See: TROUBLESHOOTING.md#imagemagick-issues"
    ERRORS=$((ERRORS + 1))
fi

if grep -qi "ImageMagick conversion failed\|magick.*failed" "$LOG_FILE"; then
    print_issue "ImageMagick conversion failed"
    grep -i "conversion failed\|magick.*exit" "$LOG_FILE" | head -5
    echo ""
    print_info "Fix: Check for corrupt input files or version mismatch"
    print_info "See: TROUBLESHOOTING.md#imagemagick-conversion-failed"
    ERRORS=$((ERRORS + 1))
fi

# Analyze upload failures
print_header "6️⃣ Upload to App Store Connect"

if grep -qi "Authentication failed\|API.*failed\|Unauthorized" "$LOG_FILE"; then
    print_issue "App Store Connect authentication failed"
    grep -i "authentication\|unauthorized\|api.*failed" "$LOG_FILE" | head -3
    echo ""
    print_info "Fix: Check if API credentials are valid and not expired"
    print_info "See: TROUBLESHOOTING.md#upload-to-appstore-connect-failures"
    ERRORS=$((ERRORS + 1))
fi

# Performance analysis
print_header "⏱️  Performance Analysis"

# Extract job durations if available
if grep -q "Duration:" "$LOG_FILE"; then
    echo "Job durations found:"
    grep "Duration:" "$LOG_FILE" | head -10
    echo ""
fi

# Check for performance issues
if grep -qi "pre-boot.*failed\|bootstatus.*failed" "$LOG_FILE"; then
    print_warning "Pre-boot may have failed, expect slower performance"
    WARNINGS=$((WARNINGS + 1))
fi

# Collect warnings
print_header "⚠️  Other Warnings"

WARNING_PATTERNS=(
    "⚠️"
    "WARNING"
    "Warning:"
    "WARN"
)

for pattern in "${WARNING_PATTERNS[@]}"; do
    if grep -q "$pattern" "$LOG_FILE"; then
        grep "$pattern" "$LOG_FILE" | grep -v "Pre-flight passed with WARNINGS" | head -5
    fi
done

# Summary
print_header "📊 Analysis Summary"

echo ""
echo -e "${RED}❌ Errors found: $ERRORS${NC}"
echo -e "${YELLOW}⚠️  Warnings: $WARNINGS${NC}"
echo -e "${BLUE}🔍 Suspicious patterns: $SUSPICIOUS${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ] && [ $SUSPICIOUS -eq 0 ]; then
    print_success "No obvious issues found in logs"
    echo ""
    print_info "If run still failed, check for:"
    echo "  - Flaky tests"
    echo "  - Resource exhaustion"
    echo "  - Transient network issues"
    echo ""
else
    print_info "Next steps:"
    if [ $ERRORS -gt 0 ]; then
        echo "  1. Review errors above and check linked troubleshooting sections"
        echo "  2. Fix root causes before retrying"
    fi
    if [ $WARNINGS -gt 0 ] || [ $SUSPICIOUS -gt 0 ]; then
        echo "  3. Review warnings - they may indicate underlying issues"
    fi
    echo "  4. Consult: .github/workflows/TROUBLESHOOTING.md"
    echo "  5. Retry workflow if issues are transient"
    echo ""
fi

print_info "Full troubleshooting guide: .github/workflows/TROUBLESHOOTING.md"
print_info "View run in browser: gh run view $RUN_ID --web"

exit 0
