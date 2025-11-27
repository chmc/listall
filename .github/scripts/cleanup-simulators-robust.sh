#!/usr/bin/env bash
# More tolerant error handling for diagnostic script
set -euo pipefail

# Enhanced Simulator Cleanup & Diagnostics
# CRITICAL FIX: Previous cleanup was fire-and-forget with || true
# New approach: Verify cleanup succeeded, detect hung processes, log diagnostics
# This prevents simulator state issues that caused 100% iPad test failures

# Timestamp function for all log messages
log_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]" "$@"
}

# Timeout wrapper - prevents commands from hanging indefinitely
# Usage: run_with_timeout <timeout_seconds> <command> [args...]
run_with_timeout() {
    local timeout_secs="${1}"
    shift
    local cmd=("$@")

    # Create background process
    "${cmd[@]}" &
    local pid=$!

    # Wait with timeout
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ $elapsed -ge "$timeout_secs" ]; then
            log_timestamp "⚠️  Command exceeded ${timeout_secs}s timeout, killing: ${cmd[*]}"
            kill -9 "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            return 124  # Standard timeout exit code
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Get exit code
    wait "$pid"
    return $?
}

log_timestamp "========================================"
log_timestamp "🧹 Enhanced Simulator Cleanup & Diagnostics"
log_timestamp "========================================"

# 1. Check for hung simulator processes
log_timestamp ""
log_timestamp "1️⃣ Checking for hung simulator processes..."
# Look for Simulator.app specifically, not simctl commands
HUNG_SIMS=$(ps aux | grep "Simulator\.app/Contents/MacOS/Simulator" | grep -v grep | wc -l | xargs)
if [ "$HUNG_SIMS" -gt 0 ]; then
  log_timestamp "⚠️  Found $HUNG_SIMS Simulator.app processes"
  ps aux | grep "Simulator\.app/Contents/MacOS/Simulator" | grep -v grep || true
  log_timestamp "🔨 Killing Simulator.app processes (will restart cleanly)..."
  if ! run_with_timeout 10 pkill -9 -f "Simulator.app/Contents/MacOS/Simulator"; then
    log_timestamp "⚠️  pkill command timed out or failed, but continuing"
  fi
  sleep 3

  # Verify processes were killed
  REMAINING_SIMS=$(ps aux | grep "Simulator\.app/Contents/MacOS/Simulator" | grep -v grep | wc -l | xargs)
  if [ "$REMAINING_SIMS" -gt 0 ]; then
    log_timestamp "⚠️  Warning: $REMAINING_SIMS Simulator.app processes still running after kill attempt"
  else
    log_timestamp "✅ All Simulator.app processes killed successfully"
  fi
else
  log_timestamp "✅ No Simulator.app processes found (this is normal if using simctl)"
fi

# 2. Shutdown all simulators with verification
log_timestamp ""
log_timestamp "2️⃣ Shutting down all simulators..."
if run_with_timeout 30 xcrun simctl shutdown all 2>&1; then
  log_timestamp "✅ Shutdown command completed successfully"
else
  local exit_code=$?
  if [ $exit_code -eq 124 ]; then
    log_timestamp "❌ Shutdown command timed out after 30s - may indicate hung simulators"
  else
    log_timestamp "⚠️  Shutdown command failed with exit code $exit_code, but continuing"
  fi
fi
sleep 3

# 3. Verify all simulators are shutdown
log_timestamp ""
log_timestamp "3️⃣ Verifying all simulators are shutdown..."
if ! SIMCTL_LIST_OUTPUT=$(run_with_timeout 20 xcrun simctl list devices 2>&1); then
  log_timestamp "❌ ERROR: simctl list devices timed out after 20s"
  log_timestamp "   This likely indicates CoreSimulatorService is hung"
  log_timestamp "🔨 Attempting to restart CoreSimulatorService..."
  pkill -9 -f "CoreSimulatorService" 2>/dev/null || true
  sleep 2
  SIMCTL_LIST_OUTPUT=$(xcrun simctl list devices 2>&1 || echo "FAILED")
fi

BOOTED=$(echo "$SIMCTL_LIST_OUTPUT" | grep "Booted" | wc -l | xargs)
if [ "$BOOTED" -gt 0 ]; then
  log_timestamp "❌ ERROR: $BOOTED simulators still booted after shutdown"
  echo "$SIMCTL_LIST_OUTPUT" | grep "Booted"
  log_timestamp "🔨 Force killing booted simulators..."
  # Get UDIDs of booted simulators and force shutdown
  echo "$SIMCTL_LIST_OUTPUT" | grep "Booted" | grep -oE '\([A-F0-9-]{36}\)' | tr -d '()' | while read -r udid; do
    log_timestamp "  Shutting down $udid..."
    run_with_timeout 10 xcrun simctl shutdown "$udid" 2>&1 || log_timestamp "  Failed to shutdown $udid"
  done
  sleep 2
  # Final check
  STILL_BOOTED=$(xcrun simctl list devices 2>&1 | grep "Booted" | wc -l | xargs)
  if [ "$STILL_BOOTED" -gt 0 ]; then
    log_timestamp "❌ CRITICAL: $STILL_BOOTED simulators STILL booted - manual intervention needed"
    exit 1
  fi
fi
log_timestamp "✅ All simulators shutdown successfully"

# 4. Delete unavailable simulators
log_timestamp ""
log_timestamp "4️⃣ Deleting unavailable simulators..."
if run_with_timeout 20 xcrun simctl delete unavailable 2>&1; then
  log_timestamp "✅ Unavailable simulators deleted"
else
  log_timestamp "⚠️  Delete unavailable command timed out or failed, but continuing"
fi

# 5. Check CoreSimulatorService health
log_timestamp ""
log_timestamp "5️⃣ Checking CoreSimulatorService health..."
if pgrep -f "CoreSimulatorService" > /dev/null; then
  CORE_SIM_PID=$(pgrep -f "CoreSimulatorService" | head -1)
  log_timestamp "✅ CoreSimulatorService is running (PID: $CORE_SIM_PID)"

  # Check if process is responsive (not zombie)
  if ps -p "$CORE_SIM_PID" -o stat= | grep -q "Z"; then
    log_timestamp "❌ CoreSimulatorService is a ZOMBIE process - killing and restarting"
    kill -9 "$CORE_SIM_PID" 2>/dev/null || true
    sleep 2
  fi
else
  log_timestamp "⚠️  CoreSimulatorService not running (may cause boot issues)"
  log_timestamp "   This is unusual but not necessarily a problem - it starts on demand"
fi

# 6. Log system resources
log_timestamp ""
log_timestamp "6️⃣ System resource status:"
if FREE_PAGES=$(run_with_timeout 5 vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.'); then
  # Convert pages to MB (4096 bytes per page)
  FREE_MB=$((FREE_PAGES * 4096 / 1024 / 1024))
  log_timestamp "  Memory: $FREE_PAGES pages free (~${FREE_MB}MB)"
else
  log_timestamp "  Memory: Unable to check (vm_stat timed out)"
fi

if TOP_OUTPUT=$(run_with_timeout 5 bash -c "top -l 1 | grep 'CPU usage'"); then
  log_timestamp "  CPU: $TOP_OUTPUT"
else
  log_timestamp "  CPU: Unable to check (top timed out)"
fi

# Check for high load average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
log_timestamp "  Load average: $LOAD_AVG"

# 7. List available simulators
log_timestamp ""
log_timestamp "7️⃣ Available simulators:"
if SIMCTL_AVAILABLE=$(run_with_timeout 20 xcrun simctl list devices available 2>&1); then
  IPHONE_COUNT=$(echo "$SIMCTL_AVAILABLE" | grep "iPhone" | wc -l | xargs)
  IPAD_COUNT=$(echo "$SIMCTL_AVAILABLE" | grep "iPad" | wc -l | xargs)
  WATCH_COUNT=$(echo "$SIMCTL_AVAILABLE" | grep "Watch" | wc -l | xargs)
  log_timestamp "  iPhone simulators: $IPHONE_COUNT"
  log_timestamp "  iPad simulators: $IPAD_COUNT"
  log_timestamp "  Watch simulators: $WATCH_COUNT"
else
  log_timestamp "  Unable to list simulators (command timed out)"
fi

log_timestamp ""
log_timestamp "========================================"
log_timestamp "✅ Simulator cleanup complete"
log_timestamp "========================================"
