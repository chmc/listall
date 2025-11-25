#!/bin/bash
set -euo pipefail

# Local CI Pipeline Test Runner
# Simulates the GitHub Actions workflow locally for validation before push
#
# Usage: .github/scripts/test-pipeline-locally.sh [--full|--quick|--validate-only]
#   --full: Run complete pipeline including screenshot generation (60-90 min)
#   --quick: Run all checks but skip actual screenshot generation (5-10 min)
#   --validate-only: Only run validation scripts, no simulator operations (1-2 min)
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#   2 - Invalid arguments

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test mode
MODE="${1:-quick}"

# Timing
SCRIPT_START=$(date +%s)

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_skip() {
    echo -e "${YELLOW}⏭️  $1${NC}"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Validate mode
case "$MODE" in
    --full|full)
        MODE="full"
        print_info "Running FULL pipeline test (including screenshot generation)"
        ;;
    --quick|quick)
        MODE="quick"
        print_info "Running QUICK pipeline test (no screenshot generation)"
        ;;
    --validate-only|validate)
        MODE="validate"
        print_info "Running VALIDATION ONLY test"
        ;;
    *)
        echo "❌ Error: Invalid mode: $MODE" >&2
        echo "Usage: $0 [--full|--quick|--validate-only]" >&2
        exit 2
        ;;
esac

# Check we're in the right directory
if [ ! -f ".github/workflows/prepare-appstore.yml" ]; then
    print_error "Must run from repository root"
    exit 1
fi

print_header "Test 1: Validate Helper Scripts Exist"

SCRIPTS=(
    ".github/scripts/preflight-check.sh"
    ".github/scripts/find-simulator.sh"
    ".github/scripts/cleanup-watch-duplicates.sh"
    ".github/scripts/validate-screenshots.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        print_success "$(basename "$script") exists and is executable"
    else
        print_error "$(basename "$script") missing or not executable"
    fi
done

print_header "Test 2: Shell Script Syntax Check"

for script in "${SCRIPTS[@]}"; do
    if bash -n "$script" 2>/dev/null; then
        print_success "$(basename "$script") syntax valid"
    else
        print_error "$(basename "$script") syntax error"
    fi
done

print_header "Test 3: Pre-flight Environment Check"

if .github/scripts/preflight-check.sh; then
    print_success "Pre-flight checks passed"
else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        print_success "Pre-flight checks passed with warnings"
    else
        print_error "Pre-flight checks failed (exit code: $EXIT_CODE)"
    fi
fi

if [ "$MODE" == "validate" ]; then
    print_skip "Skipping simulator tests (validate-only mode)"
    print_skip "Skipping screenshot generation (validate-only mode)"
    print_skip "Skipping screenshot validation (validate-only mode)"
else
    print_header "Test 4: Simulator Discovery"

    # Test iPhone simulator
    if IPHONE_UDID=$(.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS 2>&1); then
        print_success "iPhone 16 Pro Max found: ${IPHONE_UDID:0:8}..."
    else
        print_error "iPhone 16 Pro Max not found"
    fi

    # Test iPad simulator
    if IPAD_UDID=$(.github/scripts/find-simulator.sh "iPad Pro 13-inch (M4)" iOS 2>&1); then
        print_success "iPad Pro 13-inch (M4) found: ${IPAD_UDID:0:8}..."
    else
        print_error "iPad Pro 13-inch (M4) not found"
    fi

    # Test Watch simulator
    if WATCH_UDID=$(.github/scripts/find-simulator.sh "Apple Watch Series 10 (46mm)" watchOS 2>&1); then
        print_success "Apple Watch Series 10 (46mm) found: ${WATCH_UDID:0:8}..."
    else
        print_error "Apple Watch Series 10 (46mm) not found"
    fi

    print_header "Test 5: Watch Duplicate Cleanup"

    if .github/scripts/cleanup-watch-duplicates.sh; then
        print_success "Watch duplicate cleanup succeeded"
    else
        print_error "Watch duplicate cleanup failed"
    fi

    if [ "$MODE" == "quick" ]; then
        print_header "Test 6: Simulator Boot Test (Quick)"

        print_info "Testing iPhone simulator boot..."
        if IPHONE_UDID=$(.github/scripts/find-simulator.sh "iPhone 16 Pro Max" iOS 2>/dev/null); then
            # Check current state
            CURRENT_STATE=$(xcrun simctl list devices "$IPHONE_UDID" | grep "$IPHONE_UDID" | grep -oE '\(Booted\)|\(Shutdown\)' || echo "(Unknown)")

            if [[ "$CURRENT_STATE" == *"Booted"* ]]; then
                print_success "iPhone simulator already booted"
            else
                # Shutdown first to ensure clean state
                xcrun simctl shutdown "$IPHONE_UDID" 2>/dev/null || true
                sleep 1

                # Try to boot using bootstatus (blocks until ready or fails)
                if xcrun simctl boot "$IPHONE_UDID" 2>/dev/null && xcrun simctl bootstatus "$IPHONE_UDID" -b 2>/dev/null; then
                    print_success "iPhone simulator boots successfully"

                    # Clean up
                    xcrun simctl shutdown "$IPHONE_UDID" 2>/dev/null || true
                else
                    # Check if it's already booted (race condition)
                    if xcrun simctl list devices "$IPHONE_UDID" | grep -q "Booted"; then
                        print_success "iPhone simulator is booted"
                        xcrun simctl shutdown "$IPHONE_UDID" 2>/dev/null || true
                    else
                        print_error "iPhone simulator failed to boot (this may be okay if already in use)"
                    fi
                fi
            fi
        else
            print_error "Could not find iPhone simulator"
        fi

        print_skip "Skipping screenshot generation (quick mode)"
        print_skip "Skipping screenshot validation (quick mode - no screenshots)"

    elif [ "$MODE" == "full" ]; then
        print_header "Test 6: Full Screenshot Generation Pipeline"

        print_warning "This will take 60-90 minutes and generate actual screenshots"
        print_info "Starting in 5 seconds... (Ctrl+C to cancel)"
        sleep 5

        # Clean simulators
        print_info "Cleaning simulator state..."
        xcrun simctl shutdown all 2>/dev/null || true
        xcrun simctl delete unavailable 2>/dev/null || true

        # iPhone screenshots
        print_info "Generating iPhone screenshots..."
        IPHONE_START=$(date +%s)
        if bundle exec fastlane ios screenshots_iphone; then
            IPHONE_END=$(date +%s)
            IPHONE_DURATION=$((IPHONE_END - IPHONE_START))
            print_success "iPhone screenshots generated (${IPHONE_DURATION}s)"
        else
            print_error "iPhone screenshot generation failed"
        fi

        # iPad screenshots
        print_info "Generating iPad screenshots..."
        IPAD_START=$(date +%s)
        if bundle exec fastlane ios screenshots_ipad; then
            IPAD_END=$(date +%s)
            IPAD_DURATION=$((IPAD_END - IPAD_START))
            print_success "iPad screenshots generated (${IPAD_DURATION}s)"
        else
            print_error "iPad screenshot generation failed"
        fi

        # Watch screenshots
        print_info "Generating Watch screenshots..."
        WATCH_START=$(date +%s)
        if bundle exec fastlane ios watch_screenshots; then
            WATCH_END=$(date +%s)
            WATCH_DURATION=$((WATCH_END - WATCH_START))
            print_success "Watch screenshots generated (${WATCH_DURATION}s)"
        else
            print_error "Watch screenshot generation failed"
        fi

        print_header "Test 7: Screenshot Validation"

        # Validate iPhone screenshots
        if [ -d "fastlane/screenshots_compat" ]; then
            if .github/scripts/validate-screenshots.sh fastlane/screenshots_compat iphone; then
                print_success "iPhone screenshots validated"
            else
                print_error "iPhone screenshot validation failed"
            fi
        else
            print_warning "iPhone screenshots directory not found"
        fi

        # Validate iPad screenshots
        if [ -d "fastlane/screenshots_compat" ]; then
            if .github/scripts/validate-screenshots.sh fastlane/screenshots_compat ipad; then
                print_success "iPad screenshots validated"
            else
                print_error "iPad screenshot validation failed"
            fi
        else
            print_warning "iPad screenshots directory not found"
        fi

        # Validate Watch screenshots
        if [ -d "fastlane/screenshots/watch_normalized" ]; then
            if .github/scripts/validate-screenshots.sh fastlane/screenshots/watch_normalized watch; then
                print_success "Watch screenshots validated"
            else
                print_error "Watch screenshot validation failed"
            fi
        else
            print_warning "Watch screenshots directory not found"
        fi
    fi
fi

print_header "Test 8: Fastfile Syntax Check"

if bundle exec ruby -c fastlane/Fastfile >/dev/null 2>&1; then
    print_success "Fastfile syntax valid"
else
    print_error "Fastfile syntax error"
fi

print_header "Test 9: Workflow YAML Syntax"

if ruby -ryaml -e "YAML.safe_load(File.read('.github/workflows/prepare-appstore.yml'))" >/dev/null 2>&1; then
    print_success "Workflow YAML syntax valid"
else
    print_error "Workflow YAML syntax error"
fi

print_header "Test 10: Documentation Exists"

DOCS=(
    ".github/scripts/README.md"
    ".github/workflows/TROUBLESHOOTING.md"
    "fastlane/README.md"
)

for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        print_success "$(basename "$doc") exists"
    else
        print_warning "$(basename "$doc") not found"
    fi
done

# Summary
SCRIPT_END=$(date +%s)
TOTAL_DURATION=$((SCRIPT_END - SCRIPT_START))

print_header "Test Summary"

echo ""
echo -e "${GREEN}✅ Passed: $TESTS_PASSED${NC}"
echo -e "${RED}❌ Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}⏭️  Skipped: $TESTS_SKIPPED${NC}"
echo ""
echo -e "Total duration: ${TOTAL_DURATION}s"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    print_error "Some tests failed - DO NOT PUSH until fixed"
    exit 1
else
    print_success "All tests passed - Safe to push!"

    if [ "$MODE" == "quick" ] || [ "$MODE" == "validate" ]; then
        print_info "Note: Quick/validation mode used - consider running full test before major releases"
    fi

    exit 0
fi
