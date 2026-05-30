#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-clients/apple/CraftingTable.xcodeproj}"
SCHEME="${SCHEME:-CraftingTableMac}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build/DerivedData}"
PROCESS_NAME="${PROCESS_NAME:-CraftingTableMac}"

usage() {
  cat <<'USAGE'
Usage: scripts/run-macos-client.sh [--build-only] [--verify]

Build and launch the macOS Crafting Table client.
USAGE
}

BUILD_ONLY=0
VERIFY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-only)
      BUILD_ONLY=1
      shift
      ;;
    --verify)
      VERIFY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required." >&2
  exit 1
fi

pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}/${SCHEME}.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app was not found at $APP_PATH." >&2
  exit 1
fi

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  echo "Built $SCHEME at $APP_PATH."
  exit 0
fi

/usr/bin/open -n "$APP_PATH"

if [[ "$VERIFY" -eq 1 ]]; then
  sleep 1
  if ! pgrep -x "$PROCESS_NAME" >/dev/null; then
    echo "$PROCESS_NAME did not appear to launch." >&2
    exit 1
  fi
fi

echo "Launched $SCHEME."
