#!/bin/bash
set -euo pipefail

# Find and validate an iOS/watchOS simulator by name
# Usage: find-simulator.sh "iPhone 16 Pro Max" [iOS|watchOS]
# Returns: Simulator UDID on success, exits with error on failure

DEVICE_NAME="${1:-}"
OS_TYPE="${2:-iOS}"

if [ -z "$DEVICE_NAME" ]; then
    echo "❌ Error: Device name required" >&2
    echo "Usage: $0 \"Device Name\" [iOS|watchOS]" >&2
    exit 1
fi

echo "🔍 Searching for simulator: $DEVICE_NAME (${OS_TYPE}*)" >&2

# Get list of available simulators as JSON
SIMULATORS_JSON=$(xcrun simctl list devices available -j 2>&1)
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to list simulators" >&2
    echo "$SIMULATORS_JSON" >&2
    exit 2
fi

# Find matching device using Python (more reliable than jq which may not be installed)
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

# Validate UDID format (should be UUID format)
if ! echo "$DEVICE_UDID" | grep -qE '^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$'; then
    echo "❌ Error: Invalid UDID format returned: $DEVICE_UDID" >&2
    exit 5
fi

# Verify simulator can actually be booted (check device exists)
if ! xcrun simctl list devices "$DEVICE_UDID" &>/dev/null; then
    echo "❌ Error: Simulator $DEVICE_UDID exists in JSON but not bootable" >&2
    exit 6
fi

# Return UDID (this goes to stdout, captured by caller)
echo "$DEVICE_UDID"
