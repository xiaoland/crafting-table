#!/usr/bin/env bash
set -euo pipefail

PROJECT="CraftingTable.xcodeproj"
SCHEME="CraftingTable"
CONFIGURATION="Debug"
DERIVED_DATA_PATH=".build/DerivedData"
PREFERRED_DEVICE_NAME="${SIMULATOR_NAME:-iPad Pro 11-inch (M4)}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to choose an iPad simulator." >&2
  exit 1
fi

DEVICE_INFO="$(
  PREFERRED_DEVICE_NAME="$PREFERRED_DEVICE_NAME" python3 - <<'PY'
import json
import os
import subprocess
import sys

preferred_name = os.environ["PREFERRED_DEVICE_NAME"]
devices_json = subprocess.check_output(
    ["xcrun", "simctl", "list", "devices", "available", "-j"],
    text=True,
)
devices_by_runtime = json.loads(devices_json)["devices"]

preferred_matches = []
ipad_matches = []

for runtime, devices in devices_by_runtime.items():
    for device in devices:
        if not device.get("isAvailable", False):
            continue

        name = device.get("name", "")
        record = (name, device["udid"], runtime)

        if name == preferred_name:
            preferred_matches.append(record)
        elif "iPad" in name:
            ipad_matches.append(record)

matches = preferred_matches or ipad_matches
if not matches:
    print("No available iPad simulator found.", file=sys.stderr)
    sys.exit(1)

print("\t".join(matches[0]))
PY
)"

IFS=$'\t' read -r DEVICE_NAME DEVICE_UDID DEVICE_RUNTIME <<< "$DEVICE_INFO"

echo "Using simulator: $DEVICE_NAME ($DEVICE_RUNTIME)"

xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_UDID" -b

open -a Simulator --args -CurrentDeviceUDID "$DEVICE_UDID"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphonesimulator/${SCHEME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app was not found at $APP_PATH." >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_PATH/Info.plist")"

xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID"

echo "Launched $SCHEME on $DEVICE_NAME."
