#!/bin/bash
set -euo pipefail

# Pre-flight checks for App Store screenshot pipeline
# Validates environment before starting 90+ minute CI run
# Exit codes: 0 = all checks passed, 1+ = check failed

echo "🚀 Running pre-flight checks..." >&2
echo "" >&2

ERRORS=0
WARNINGS=0

# Check 1: Xcode version
echo "📱 Checking Xcode..." >&2
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ xcodebuild not found" >&2
    ERRORS=$((ERRORS + 1))
else
    XCODE_VERSION=$(xcodebuild -version | head -1 || echo "Unknown")
    XCODE_PATH=$(xcode-select -p || echo "Unknown")
    echo "✅ $XCODE_VERSION" >&2
    echo "   Path: $XCODE_PATH" >&2

    # Check if required Xcode 16.1 is available
    if [ ! -d "/Applications/Xcode_16.1.app" ]; then
        echo "⚠️  Warning: Xcode 16.1 not found at /Applications/Xcode_16.1.app" >&2
        echo "   Workflow expects this specific version" >&2
        WARNINGS=$((WARNINGS + 1))
    fi
fi
echo "" >&2

# Check 2: Required simulators
echo "📱 Checking simulators..." >&2
SIMCTL_OUTPUT=$(xcrun simctl list devices available 2>&1 || echo "ERROR")
if echo "$SIMCTL_OUTPUT" | grep -q "ERROR"; then
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

# Check 3: ImageMagick
echo "🎨 Checking ImageMagick..." >&2
if ! command -v convert &> /dev/null && ! command -v magick &> /dev/null; then
    echo "❌ ImageMagick not installed" >&2
    echo "   Install with: brew install imagemagick" >&2
    ERRORS=$((ERRORS + 1))
else
    if command -v magick &> /dev/null; then
        MAGICK_VERSION=$(magick --version | head -1 || echo "Unknown")
        echo "✅ $MAGICK_VERSION" >&2
    else
        CONVERT_VERSION=$(convert --version | head -1 || echo "Unknown")
        echo "✅ $CONVERT_VERSION" >&2
    fi

    # Check specific commands needed
    if ! command -v identify &> /dev/null; then
        echo "❌ ImageMagick 'identify' command not found" >&2
        ERRORS=$((ERRORS + 1))
    fi
fi
echo "" >&2

# Check 4: Ruby and Bundler
echo "💎 Checking Ruby..." >&2
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby not installed" >&2
    ERRORS=$((ERRORS + 1))
else
    RUBY_VERSION=$(ruby --version || echo "Unknown")
    echo "✅ $RUBY_VERSION" >&2

    if ! command -v bundle &> /dev/null; then
        echo "❌ Bundler not installed" >&2
        ERRORS=$((ERRORS + 1))
    else
        BUNDLER_VERSION=$(bundle --version || echo "Unknown")
        echo "✅ $BUNDLER_VERSION" >&2
    fi
fi
echo "" >&2

# Check 5: Disk space
echo "💾 Checking disk space..." >&2
if command -v df &> /dev/null; then
    # macOS uses -h for human readable
    FREE_SPACE_MB=$(df -m . | tail -1 | awk '{print $4}' || echo "0")
    FREE_SPACE_GB=$((FREE_SPACE_MB / 1024))

    if [ "$FREE_SPACE_MB" -lt 500 ]; then
        echo "❌ Insufficient disk space: ${FREE_SPACE_GB}GB (need at least 500MB)" >&2
        ERRORS=$((ERRORS + 1))
    elif [ "$FREE_SPACE_MB" -lt 2000 ]; then
        echo "⚠️  Warning: Low disk space: ${FREE_SPACE_GB}GB (recommended: 2GB+)" >&2
        WARNINGS=$((WARNINGS + 1))
    else
        echo "✅ Disk space: ${FREE_SPACE_GB}GB available" >&2
    fi
else
    echo "⚠️  Warning: Cannot check disk space (df command not found)" >&2
    WARNINGS=$((WARNINGS + 1))
fi
echo "" >&2

# Check 6: Required files
echo "📁 Checking required files..." >&2
REQUIRED_FILES=(
    "fastlane/Fastfile"
    "fastlane/Snapfile"
    "Gemfile"
    "Gemfile.lock"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ Required file missing: $file" >&2
        ERRORS=$((ERRORS + 1))
    fi
done

if [ $ERRORS -eq 0 ]; then
    echo "✅ All required files present" >&2
fi
echo "" >&2

# Check 7: Network connectivity (for App Store Connect)
echo "🌐 Checking network connectivity..." >&2
if ping -c 1 -W 2 appstoreconnect.apple.com &> /dev/null; then
    echo "✅ Can reach appstoreconnect.apple.com" >&2
elif ping -c 1 -W 2 apple.com &> /dev/null; then
    echo "✅ Network connectivity OK (apple.com reachable)" >&2
else
    echo "⚠️  Warning: Cannot reach apple.com (network may be unavailable)" >&2
    WARNINGS=$((WARNINGS + 1))
fi
echo "" >&2

# Summary
echo "════════════════════════════════════" >&2
if [ $ERRORS -gt 0 ]; then
    echo "❌ Pre-flight FAILED: $ERRORS error(s), $WARNINGS warning(s)" >&2
    echo "   Fix errors above before running pipeline" >&2
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "⚠️  Pre-flight passed with WARNINGS: $WARNINGS warning(s)" >&2
    echo "   Pipeline may encounter issues" >&2
    exit 0
else
    echo "✅ All pre-flight checks PASSED" >&2
    echo "   Environment ready for screenshot generation" >&2
    exit 0
fi
