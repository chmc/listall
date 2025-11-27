#!/usr/bin/env bash
# Simplified cleanup for ephemeral GitHub runners
# Previous 190-line script was over-engineered and had grep/arithmetic bugs

set -euo pipefail

echo "🧹 Cleaning simulator state..."
echo "⏱️  Started at: $(date '+%Y-%m-%d %H:%M:%S')"

# 1. Shutdown all simulators (graceful)
echo "[1/3] Shutting down simulators..."
xcrun simctl shutdown all 2>/dev/null || true

# 2. Erase all simulator data (fresh state)
echo "[2/3] Erasing simulator data..."
xcrun simctl erase all 2>/dev/null || true

# 3. Remove unavailable simulators
echo "[3/3] Removing unavailable simulators..."
xcrun simctl delete unavailable 2>/dev/null || true

echo "✅ Cleanup complete at: $(date '+%Y-%m-%d %H:%M:%S')"
