#!/bin/bash
# More tolerant error handling for diagnostic script
set -e

# Enhanced Simulator Cleanup & Diagnostics
# CRITICAL FIX: Previous cleanup was fire-and-forget with || true
# New approach: Verify cleanup succeeded, detect hung processes, log diagnostics
# This prevents simulator state issues that caused 100% iPad test failures

echo "========================================"
echo "🧹 Enhanced Simulator Cleanup & Diagnostics"
echo "========================================"

# 1. Check for hung simulator processes
echo ""
echo "1️⃣ Checking for hung simulator processes..."
# Look for Simulator.app specifically, not simctl commands
HUNG_SIMS=$(ps aux | grep "Simulator\.app/Contents/MacOS/Simulator" | grep -v grep | wc -l | xargs)
if [ "$HUNG_SIMS" -gt 0 ]; then
  echo "⚠️  Found $HUNG_SIMS Simulator.app processes"
  ps aux | grep "Simulator\.app/Contents/MacOS/Simulator" | grep -v grep || true
  echo "🔨 Killing Simulator.app processes (will restart cleanly)..."
  pkill -9 -f "Simulator.app/Contents/MacOS/Simulator" 2>/dev/null || true
  sleep 3
else
  echo "✅ No Simulator.app processes found (this is normal if using simctl)"
fi

# 2. Shutdown all simulators with verification
echo ""
echo "2️⃣ Shutting down all simulators..."
xcrun simctl shutdown all 2>&1 || true
sleep 3

# 3. Verify all simulators are shutdown
echo ""
echo "3️⃣ Verifying all simulators are shutdown..."
BOOTED=$(xcrun simctl list devices | grep "Booted" | wc -l | xargs)
if [ "$BOOTED" -gt 0 ]; then
  echo "❌ ERROR: $BOOTED simulators still booted after shutdown"
  xcrun simctl list devices | grep "Booted"
  echo "🔨 Force killing booted simulators..."
  # Get UDIDs of booted simulators and force shutdown
  xcrun simctl list devices | grep "Booted" | grep -oE '\([A-F0-9-]{36}\)' | tr -d '()' | while read -r udid; do
    echo "  Shutting down $udid..."
    xcrun simctl shutdown "$udid" 2>&1 || true
  done
  sleep 2
  # Final check
  STILL_BOOTED=$(xcrun simctl list devices | grep "Booted" | wc -l | xargs)
  if [ "$STILL_BOOTED" -gt 0 ]; then
    echo "❌ CRITICAL: $STILL_BOOTED simulators STILL booted - manual intervention needed"
    exit 1
  fi
fi
echo "✅ All simulators shutdown successfully"

# 4. Delete unavailable simulators
echo ""
echo "4️⃣ Deleting unavailable simulators..."
xcrun simctl delete unavailable 2>&1 || true
echo "✅ Unavailable simulators deleted"

# 5. Check CoreSimulatorService health
echo ""
echo "5️⃣ Checking CoreSimulatorService health..."
if pgrep -f "CoreSimulatorService" > /dev/null; then
  CORE_SIM_PID=$(pgrep -f "CoreSimulatorService" | head -1)
  echo "✅ CoreSimulatorService is running (PID: $CORE_SIM_PID)"
else
  echo "⚠️  CoreSimulatorService not running (may cause boot issues)"
  echo "   This is unusual but not necessarily a problem - it starts on demand"
fi

# 6. Log system resources
echo ""
echo "6️⃣ System resource status:"
FREE_PAGES=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
echo "  Memory: $FREE_PAGES pages free"
TOP_OUTPUT=$(top -l 1 | grep "CPU usage" || echo "CPU info unavailable")
echo "  CPU: $TOP_OUTPUT"

# 7. List available simulators
echo ""
echo "7️⃣ Available simulators:"
IPHONE_COUNT=$(xcrun simctl list devices available | grep "iPhone" | wc -l | xargs)
IPAD_COUNT=$(xcrun simctl list devices available | grep "iPad" | wc -l | xargs)
WATCH_COUNT=$(xcrun simctl list devices available | grep "Watch" | wc -l | xargs)
echo "  iPhone simulators: $IPHONE_COUNT"
echo "  iPad simulators: $IPAD_COUNT"
echo "  Watch simulators: $WATCH_COUNT"

echo ""
echo "========================================"
echo "✅ Simulator cleanup complete"
echo "========================================"
