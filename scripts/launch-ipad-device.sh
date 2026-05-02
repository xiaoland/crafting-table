#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-CraftingTable.xcodeproj}"
SCHEME="${SCHEME:-CraftingTable}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build/DerivedData}"
DEVICE_ID="${IPAD_DEVICE_ID:-}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to choose a connected iPad." >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required." >&2
  exit 1
fi

if [[ -z "$DEVELOPMENT_TEAM" ]]; then
  DEVELOPMENT_TEAM="$(defaults read com.apple.dt.Xcode IDEProvisioningTeamManagerLastSelectedTeamID 2>/dev/null || true)"
fi

if [[ -z "$DEVELOPMENT_TEAM" ]]; then
  echo "No Xcode development team found. Set DEVELOPMENT_TEAM or choose a Personal Team in Xcode." >&2
  exit 1
fi

DEVICE_INFO="$(
  DEVICE_ID="$DEVICE_ID" python3 - <<'PY'
import os
import re
import subprocess
import sys

requested_device_id = os.environ.get("DEVICE_ID", "").strip()
output = subprocess.check_output(["xcrun", "xctrace", "list", "devices"], text=True, stderr=subprocess.DEVNULL)

in_devices = False
matches = []

for raw_line in output.splitlines():
    line = raw_line.strip()
    if line == "== Devices ==":
        in_devices = True
        continue
    if line.startswith("== ") and line != "== Devices ==":
        in_devices = False
    if not in_devices or "iPad" not in line:
        continue

    id_matches = re.findall(r"\(([0-9A-Fa-f-]{20,})\)", line)
    if not id_matches:
        continue

    device_id = id_matches[-1]
    name = line[: line.rfind("(")].strip()
    name = re.sub(r"\s+\([^)]*\)$", "", name).strip()
    matches.append((name, device_id))

if requested_device_id:
    for name, device_id in matches:
        if device_id == requested_device_id:
            print(f"{name}\t{device_id}")
            break
    else:
        print(f"Requested iPad was not found: {requested_device_id}", file=sys.stderr)
        sys.exit(1)
elif matches:
    print("\t".join(matches[0]))
else:
    print("No connected iPad found.", file=sys.stderr)
    sys.exit(1)
PY
)"

IFS=$'\t' read -r DEVICE_NAME DEVICE_ID <<< "$DEVICE_INFO"

echo "Using iPad: $DEVICE_NAME ($DEVICE_ID)"
echo "Using development team: $DEVELOPMENT_TEAM"

if ! xcrun devicectl device info ddiServices --device "$DEVICE_ID" >/dev/null; then
  echo "Preparing Xcode device support components..."
  xcodebuild -runFirstLaunch -checkForNewerComponents
  xcrun devicectl device info ddiServices --device "$DEVICE_ID" >/dev/null
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  "DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/${SCHEME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app was not found at $APP_PATH." >&2
  exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_PATH/Info.plist")"

xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID"

echo "Launched $SCHEME on $DEVICE_NAME."
