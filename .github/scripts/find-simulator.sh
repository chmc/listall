#!/usr/bin/env bash
set -euo pipefail

# Find and validate an iOS/watchOS simulator by name
# Usage: find-simulator.sh "iPhone 16 Pro Max" [iOS|watchOS]
# Returns: Simulator UDID on success, exits with error on failure

# Timeout wrapper - prevents commands from hanging indefinitely
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

DEVICE_NAME="${1:-}"
OS_TYPE="${2:-iOS}"

if [ -z "$DEVICE_NAME" ]; then
    echo "❌ Error: Device name required" >&2
    echo "Usage: $0 \"Device Name\" [iOS|watchOS]" >&2
    exit 1
fi

echo "[$(date '+%H:%M:%S')] 🔍 Searching for simulator: $DEVICE_NAME (${OS_TYPE}*)" >&2

# Get list of available simulators as JSON with timeout
echo "[$(date '+%H:%M:%S')] Querying simctl list devices..." >&2
if ! SIMULATORS_JSON=$(run_with_timeout 30 xcrun simctl list devices available -j 2>&1); then
    echo "❌ Error: Failed to list simulators (timeout after 30s)" >&2
    echo "$SIMULATORS_JSON" >&2
    exit 2
fi

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to list simulators" >&2
    echo "$SIMULATORS_JSON" >&2
    exit 2
fi

# Find matching device using Python (more reliable than jq which may not be installed)
echo "[$(date '+%H:%M:%S')] Parsing JSON with Python..." >&2
DEVICE_UDID=$(DEVICE_NAME="$DEVICE_NAME" OS_TYPE="$OS_TYPE" python3 -c "
import json, sys, os

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f'❌ Error parsing simulator JSON: {e}', file=sys.stderr)
    sys.exit(3)

device_name = os.environ.get('DEVICE_NAME', '')
os_type = os.environ.get('OS_TYPE', '')

# Search through all runtimes
matches = []
for runtime, devices in data.get('devices', {}).items():
    # Filter by OS type (iOS, watchOS, etc.)
    if os_type not in runtime:
        continue

    for device in devices:
        if device_name in device.get('name', '') and device.get('isAvailable', False):
            matches.append({
                'udid': device['udid'],
                'name': device['name'],
                'runtime': runtime,
                'state': device.get('state', 'Unknown')
            })

if not matches:
    print(f\"❌ No available simulator found matching '{device_name}' with {os_type}\", file=sys.stderr)
    print(f\"💡 Hint: Run 'xcrun simctl list devices available' to see available devices\", file=sys.stderr)
    sys.exit(4)

# If multiple matches, prefer the first one (usually newest runtime)
match = matches[0]
print(match['udid'])

# Log match details to stderr (not captured in UDID variable)
print(f\"✅ Found: {match['name']} ({match['runtime']}) - {match['state']}\", file=sys.stderr)
if len(matches) > 1:
    print(f\"ℹ️  Note: {len(matches)} matches found, using first one\", file=sys.stderr)
" <<< "$SIMULATORS_JSON")

# Check if Python script succeeded
PYTHON_EXIT_CODE=$?
if [ $PYTHON_EXIT_CODE -ne 0 ]; then
    echo "$DEVICE_UDID" >&2
    exit $PYTHON_EXIT_CODE
fi

# Validate UDID format (should be UUID format, case-insensitive)
echo "[$(date '+%H:%M:%S')] Validating UDID format..." >&2
if ! echo "$DEVICE_UDID" | grep -qE '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'; then
    echo "❌ Error: Invalid UDID format returned: $DEVICE_UDID" >&2
    exit 5
fi

# Verify simulator can actually be booted (check device exists in simctl list)
echo "[$(date '+%H:%M:%S')] Verifying simulator exists in device list..." >&2
if ! VERIFY_LIST=$(run_with_timeout 20 xcrun simctl list devices available 2>&1); then
    echo "⚠️  Warning: Could not verify simulator (simctl timed out), but continuing" >&2
elif ! echo "$VERIFY_LIST" | grep -q "$DEVICE_UDID"; then
    echo "❌ Error: Simulator $DEVICE_UDID exists in JSON but not found in device list" >&2
    exit 6
fi

# Return UDID (this goes to stdout, captured by caller)
echo "[$(date '+%H:%M:%S')] ✅ Successfully found simulator: $DEVICE_UDID" >&2
echo "$DEVICE_UDID"
