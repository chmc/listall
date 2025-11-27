#!/usr/bin/env bash
set -euo pipefail

# Pre-flight checks for App Store screenshot pipeline
# Validates environment before starting 90+ minute CI run
# Exit codes: 0 = all checks passed, 1+ = check failed

# Timeout wrapper for hanging commands
run_with_timeout() {
    local timeout_secs="${1}"
    shift
    local cmd=("$@")

    "${cmd[@]}" &
    local pid=$!

    local elapsed=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ $elapsed -ge "$timeout_secs" ]; then
            echo "⚠️  Command exceeded ${timeout_secs}s timeout: ${cmd[*]}" >&2
            kill -9 "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            return 124
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    wait "$pid"
    return $?
}

log_timestamp() {
    echo "[$(date '+%H:%M:%S')]" "$@"
}

log_timestamp "🚀 Running pre-flight checks..." >&2
echo "" >&2

ERRORS=0
WARNINGS=0

# Check 1: Xcode version
log_timestamp "📱 Checking Xcode..." >&2
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ xcodebuild not found" >&2
    ERRORS=$((ERRORS + 1))
else
    # Test xcodebuild with timeout (can hang if Xcode is corrupted)
    if XCODE_VERSION=$(run_with_timeout 10 xcodebuild -version 2>&1 | head -1); then
        XCODE_PATH=$(xcode-select -p || echo "Unknown")
        echo "✅ $XCODE_VERSION" >&2
        echo "   Path: $XCODE_PATH" >&2

        # Check if required Xcode 16.1 is available
        if [ ! -d "/Applications/Xcode_16.1.app" ]; then
            echo "⚠️  Warning: Xcode 16.1 not found at /Applications/Xcode_16.1.app" >&2
            echo "   Workflow expects this specific version" >&2
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo "❌ xcodebuild command timed out or failed" >&2
        echo "   This may indicate Xcode is corrupted or hung" >&2
        ERRORS=$((ERRORS + 1))
    fi
fi
echo "" >&2

# Check 2: Required simulators
log_timestamp "📱 Checking simulators..." >&2
if ! SIMCTL_OUTPUT=$(run_with_timeout 30 xcrun simctl list devices available 2>&1); then
    echo "❌ Failed to list simulators (timeout after 30s)" >&2
    echo "   simctl may be hung or CoreSimulatorService unresponsive" >&2
    ERRORS=$((ERRORS + 1))
elif echo "$SIMCTL_OUTPUT" | grep -q "ERROR"; then
    echo "❌ Failed to list simulators" >&2
    ERRORS=$((ERRORS + 1))
else
    # Check for required devices
    if echo "$SIMCTL_OUTPUT" | grep -q "iPhone 16 Pro Max"; then
        echo "✅ iPhone 16 Pro Max available" >&2
    else
        echo "❌ iPhone 16 Pro Max NOT found" >&2
        ERRORS=$((ERRORS + 1))
    fi

    if echo "$SIMCTL_OUTPUT" | grep -q "iPad Pro 13-inch (M4)"; then
        echo "✅ iPad Pro 13-inch (M4) available" >&2
    else
        echo "❌ iPad Pro 13-inch (M4) NOT found" >&2
        ERRORS=$((ERRORS + 1))
    fi

    if echo "$SIMCTL_OUTPUT" | grep -q "Apple Watch Series 10 (46mm)"; then
        echo "✅ Apple Watch Series 10 (46mm) available" >&2
    else
        echo "❌ Apple Watch Series 10 (46mm) NOT found" >&2
        ERRORS=$((ERRORS + 1))
    fi
fi
echo "" >&2

# Check 3: ImageMagick (optional - workflow installs it)
log_timestamp "🎨 Checking ImageMagick..." >&2
if ! command -v convert &> /dev/null && ! command -v magick &> /dev/null; then
    echo "ℹ️  ImageMagick not yet installed (workflow will install it)" >&2
else
    if command -v magick &> /dev/null; then
        if MAGICK_VERSION=$(run_with_timeout 5 magick --version 2>&1 | head -1); then
            echo "✅ $MAGICK_VERSION" >&2
        else
            echo "⚠️  ImageMagick installed but not responsive (timeout)" >&2
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        if CONVERT_VERSION=$(run_with_timeout 5 convert --version 2>&1 | head -1); then
            echo "✅ $CONVERT_VERSION" >&2
        else
            echo "⚠️  ImageMagick installed but not responsive (timeout)" >&2
            WARNINGS=$((WARNINGS + 1))
        fi
    fi

    # Check specific commands needed
    if ! command -v identify &> /dev/null; then
        echo "⚠️  Warning: ImageMagick 'identify' command not found" >&2
        WARNINGS=$((WARNINGS + 1))
    elif ! run_with_timeout 5 identify -version > /dev/null 2>&1; then
        echo "⚠️  Warning: ImageMagick 'identify' not responsive" >&2
        WARNINGS=$((WARNINGS + 1))
    fi
fi
echo "" >&2

# Check 4: Ruby and Bundler
log_timestamp "💎 Checking Ruby..." >&2
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby not installed" >&2
    ERRORS=$((ERRORS + 1))
else
    if RUBY_VERSION=$(run_with_timeout 5 ruby --version 2>&1); then
        echo "✅ $RUBY_VERSION" >&2
    else
        echo "❌ Ruby command timed out" >&2
        ERRORS=$((ERRORS + 1))
    fi

    if ! command -v bundle &> /dev/null; then
        echo "❌ Bundler not installed" >&2
        ERRORS=$((ERRORS + 1))
    else
        if BUNDLER_VERSION=$(run_with_timeout 5 bundle --version 2>&1); then
            echo "✅ $BUNDLER_VERSION" >&2
        else
            echo "❌ Bundler command timed out" >&2
            ERRORS=$((ERRORS + 1))
        fi
    fi
fi
echo "" >&2

# Check 5: Disk space
log_timestamp "💾 Checking disk space..." >&2
if command -v df &> /dev/null; then
    # macOS uses -m for megabytes (with timeout to handle hung filesystem)
    if FREE_SPACE_MB=$(run_with_timeout 10 bash -c "df -m . | tail -1 | awk '{print \$4}'" 2>&1); then
        FREE_SPACE_GB=$((FREE_SPACE_MB / 1024))

        # Pipeline needs: ~5-10GB for derived data, 1-2GB for xcresult, 1-2GB for screenshots
        # Minimum: 10GB required, 15GB recommended
        if [ "$FREE_SPACE_MB" -lt 10240 ]; then
            echo "❌ Insufficient disk space: ${FREE_SPACE_GB}GB (need at least 10GB)" >&2
            echo "   Pipeline requires ~5-10GB for derived data + 1-2GB for xcresult + 1-2GB for screenshots" >&2
            ERRORS=$((ERRORS + 1))
        elif [ "$FREE_SPACE_MB" -lt 15360 ]; then
            echo "⚠️  Warning: Low disk space: ${FREE_SPACE_GB}GB (recommended: 15GB+)" >&2
            echo "   Pipeline may succeed but could run out of space if CI is slower than usual" >&2
            WARNINGS=$((WARNINGS + 1))
        else
            echo "✅ Disk space: ${FREE_SPACE_GB}GB available" >&2
        fi
    else
        echo "⚠️  Warning: Cannot check disk space (df timed out - possible hung filesystem)" >&2
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "⚠️  Warning: Cannot check disk space (df command not found)" >&2
    WARNINGS=$((WARNINGS + 1))
fi
echo "" >&2

# Check 6: Required files
log_timestamp "📁 Checking required files..." >&2
REQUIRED_FILES=(
    "fastlane/Fastfile"
    "fastlane/Snapfile"
    "Gemfile"
    "Gemfile.lock"
)

FILE_ERRORS=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Required file missing: $file" >&2
        ERRORS=$((ERRORS + 1))
        FILE_ERRORS=$((FILE_ERRORS + 1))
    fi
done

if [ $FILE_ERRORS -eq 0 ]; then
    echo "✅ All required files present" >&2
fi
echo "" >&2

# Check 7: Network connectivity (for App Store Connect)
log_timestamp "🌐 Checking network connectivity..." >&2
if run_with_timeout 5 ping -c 1 -W 2 appstoreconnect.apple.com &> /dev/null; then
    echo "✅ Can reach appstoreconnect.apple.com" >&2
elif run_with_timeout 5 ping -c 1 -W 2 apple.com &> /dev/null; then
    echo "✅ Network connectivity OK (apple.com reachable)" >&2
else
    echo "⚠️  Warning: Cannot reach apple.com (network may be unavailable or ping timed out)" >&2
    WARNINGS=$((WARNINGS + 1))
fi
echo "" >&2

# Summary
log_timestamp "════════════════════════════════════" >&2
if [ $ERRORS -gt 0 ]; then
    log_timestamp "❌ Pre-flight FAILED: $ERRORS error(s), $WARNINGS warning(s)" >&2
    log_timestamp "   Fix errors above before running pipeline" >&2
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    log_timestamp "⚠️  Pre-flight passed with WARNINGS: $WARNINGS warning(s)" >&2
    log_timestamp "   Pipeline may encounter issues" >&2
    exit 0
else
    log_timestamp "✅ All pre-flight checks PASSED" >&2
    log_timestamp "   Environment ready for screenshot generation" >&2
    exit 0
fi
