#!/usr/bin/env bash
#
# resolve-simulator.sh — Print the UDID of a simulator pinned to the selected Xcode
#
# Usage:
#   .github/scripts/resolve-simulator.sh <iOS|watchOS> "<exact device name>"
#
# The runtime is derived from the active Xcode's simulator SDK version
# (e.g. Xcode 26.6 -> iOS/watchOS 26.5), so local and CI always test on the
# runtime that ships with the Xcode pinned in .xcode-version. Other installed
# runtimes are ignored. Device names are matched exactly ("iPhone 17 Pro" never
# matches "iPhone 17 Pro Max"). If the device does not exist on that runtime it
# is created. watchOS devices are also paired with a companion iPhone (default
# "iPhone 17 Pro", override with WATCH_COMPANION_IPHONE): the watch app is
# embedded in the iOS app, so Xcode only accepts a paired watch as destination.
#
# Exit codes: 0 = UDID printed, 1 = runtime/device type unavailable, 2 = usage
#
# Example:
#   UDID=$(.github/scripts/resolve-simulator.sh iOS "iPhone 17 Pro")
#

set -euo pipefail

usage() {
    echo "Usage: $0 <iOS|watchOS> \"<exact device name>\"" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage

readonly PLATFORM="$1"
readonly DEVICE_NAME="$2"

case "${PLATFORM}" in
    iOS) readonly SDK="iphonesimulator" ;;
    watchOS) readonly SDK="watchsimulator" ;;
    *) usage ;;
esac

sdk_version=$(xcrun --sdk "${SDK}" --show-sdk-version)
readonly RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.${PLATFORM}-${sdk_version//./-}"

# Runs Python snippet $1 over JSON on stdin; remaining args become sys.argv[1:].
json_query() {
    python3 -I -c "$1" "${@:2}"
}

existing_udid=$(xcrun simctl list devices available -j | json_query '
import json, sys
runtime, name = sys.argv[1], sys.argv[2]
for d in json.load(sys.stdin).get("devices", {}).get(runtime, []):
    if d.get("isAvailable") and d.get("name") == name:
        print(d["udid"]); break
' "${RUNTIME_ID}" "${DEVICE_NAME}")

# Ensures watch UDID $1 is paired with the companion iPhone on the same Xcode's runtime.
ensure_watch_paired() {
    local watch_udid="$1"
    local paired
    paired=$(xcrun simctl list pairs -j | json_query '
import json, sys
for p in json.load(sys.stdin).get("pairs", {}).values():
    if p.get("watch", {}).get("udid") == sys.argv[1]:
        print("yes"); break
' "${watch_udid}")
    [[ -n "${paired}" ]] && return 0

    local companion="${WATCH_COMPANION_IPHONE:-iPhone 17 Pro}"
    local phone_udid
    phone_udid=$("${BASH_SOURCE[0]}" iOS "${companion}")
    echo "Pairing watch ${watch_udid} with \"${companion}\" (${phone_udid})" >&2
    xcrun simctl pair "${watch_udid}" "${phone_udid}" >/dev/null
}

# Prints the UDID, pairing watches first.
finish() {
    local udid="$1"
    if [[ "${PLATFORM}" == "watchOS" ]]; then
        ensure_watch_paired "${udid}"
    fi
    echo "${udid}"
}

if [[ -n "${existing_udid}" ]]; then
    finish "${existing_udid}"
    exit 0
fi

runtime_available=$(xcrun simctl list runtimes -j | json_query '
import json, sys
for r in json.load(sys.stdin).get("runtimes", []):
    if r.get("identifier") == sys.argv[1] and r.get("isAvailable"):
        print("yes"); break
' "${RUNTIME_ID}")

if [[ -z "${runtime_available}" ]]; then
    echo "ERROR: Runtime ${RUNTIME_ID} (from Xcode SDK ${SDK} ${sdk_version}) is not installed." >&2
    echo "Install it with: xcodebuild -downloadPlatform ${PLATFORM}" >&2
    exit 1
fi

devicetype_id=$(xcrun simctl list devicetypes -j | json_query '
import json, sys
for t in json.load(sys.stdin).get("devicetypes", []):
    if t.get("name") == sys.argv[1]:
        print(t["identifier"]); break
' "${DEVICE_NAME}")

if [[ -z "${devicetype_id}" ]]; then
    echo "ERROR: Device type \"${DEVICE_NAME}\" is not available in this Xcode." >&2
    exit 1
fi

echo "Creating simulator \"${DEVICE_NAME}\" on ${RUNTIME_ID}" >&2
created_udid=$(xcrun simctl create "${DEVICE_NAME}" "${devicetype_id}" "${RUNTIME_ID}")
finish "${created_udid}"
