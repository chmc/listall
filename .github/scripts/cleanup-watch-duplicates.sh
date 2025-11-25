#!/bin/bash
set -euo pipefail

# Clean up duplicate Watch simulators, keeping the oldest watchOS version
# This prevents "multiple devices matched" errors during screenshot generation
# Xcode 16.1 bundles watchOS 11.1, so we keep that version

echo "🧹 Cleaning duplicate Apple Watch Series 10 (46mm) simulators..." >&2

# Get list of Watch simulators as JSON
SIMULATORS_JSON=$(xcrun simctl list devices available -j 2>&1)
if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to list simulators" >&2
    echo "$SIMULATORS_JSON" >&2
    exit 1
fi

# Find duplicates and determine which to delete
UDIDS_TO_DELETE=$(python3 -c "
import json, sys, re

try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f'❌ Error parsing simulator JSON: {e}', file=sys.stderr)
    sys.exit(2)

watches = []

# Find all Watch Series 10 (46mm) simulators
for runtime, devices in data.get('devices', {}).items():
    if 'watchOS' not in runtime:
        continue

    # Parse version from runtime string (e.g., 'com.apple.CoreSimulator.SimRuntime.watchOS-11-1')
    match = re.search(r'watchOS-(\d+)-(\d+)', runtime)
    if not match:
        continue

    version_tuple = (int(match.group(1)), int(match.group(2)))

    for device in devices:
        if 'Apple Watch Series 10 (46mm)' in device.get('name', '') and device.get('isAvailable', False):
            watches.append({
                'udid': device['udid'],
                'runtime': runtime,
                'version': version_tuple
            })

if len(watches) <= 1:
    print(f'ℹ️  Found {len(watches)} Watch Series 10 simulators - no cleanup needed', file=sys.stderr)
    sys.exit(0)

# Sort by version (ascending) - oldest first
watches.sort(key=lambda x: x['version'])

print(f'ℹ️  Found {len(watches)} Watch Series 10 simulators:', file=sys.stderr)
for w in watches:
    print(f'  - {w[\"runtime\"]} (watchOS {w[\"version\"][0]}.{w[\"version\"][1]})', file=sys.stderr)

# Keep the oldest (index 0), delete the rest
print(f'✅ Keeping oldest: {watches[0][\"runtime\"]}', file=sys.stderr)
print(f'🗑️  Deleting {len(watches) - 1} duplicate(s)', file=sys.stderr)

# Output UDIDs to delete (one per line)
for watch in watches[1:]:
    print(watch['udid'])
" <<< "$SIMULATORS_JSON")

# Check Python exit code
PYTHON_EXIT_CODE=$?
if [ $PYTHON_EXIT_CODE -eq 0 ] && [ -z "$UDIDS_TO_DELETE" ]; then
    # No duplicates found (Python exited with 0 and empty output)
    exit 0
elif [ $PYTHON_EXIT_CODE -ne 0 ]; then
    # Python script failed
    echo "$UDIDS_TO_DELETE" >&2
    exit $PYTHON_EXIT_CODE
fi

# If no UDIDs to delete, exit successfully
if [ -z "$UDIDS_TO_DELETE" ]; then
    echo "✅ No duplicate simulators to delete" >&2
    exit 0
fi

# Delete each UDID
DELETED_COUNT=0
while IFS= read -r UDID; do
    if [ -n "$UDID" ]; then
        echo "🗑️  Deleting simulator: $UDID" >&2
        if xcrun simctl delete "$UDID" 2>&1; then
            DELETED_COUNT=$((DELETED_COUNT + 1))
        else
            echo "⚠️  Warning: Failed to delete $UDID (may not exist)" >&2
        fi
    fi
done <<< "$UDIDS_TO_DELETE"

echo "✅ Cleanup complete: deleted $DELETED_COUNT duplicate simulator(s)" >&2
