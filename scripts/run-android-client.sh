#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="${ROOT_DIR}/clients/android"
MODE="${1:-debug}"
ANDROID_PACKAGE="com.xiaoland.craftingtable"
ANDROID_ACTIVITY="com.xiaoland.craftingtable.android.MainActivity"

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" && -d "${HOME}/Library/Android/sdk" ]]; then
  export ANDROID_HOME="${HOME}/Library/Android/sdk"
  export ANDROID_SDK_ROOT="${ANDROID_HOME}"
  export PATH="${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/cmdline-tools/latest/bin:${PATH}"
fi

gradle_cmd() {
  if [[ -x "${ANDROID_DIR}/gradlew" ]]; then
    printf '%s\n' "${ANDROID_DIR}/gradlew"
    return
  fi

  if command -v gradle >/dev/null 2>&1; then
    command -v gradle
    return
  fi

  return 1
}

run_gradle_if_available() {
  local task="$1"
  local gradle
  if ! gradle="$(gradle_cmd)"; then
    echo "Gradle is not installed and clients/android/gradlew does not exist; skipping ${task}." >&2
    return 0
  fi

  "${gradle}" -p "${ANDROID_DIR}" "${task}"
}

launch_android_app() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb is not available; install Android SDK Platform-Tools or set ANDROID_HOME." >&2
    exit 1
  fi

  adb start-server >/dev/null
  local devices
  devices="$(adb devices | awk 'NR > 1 && $2 == "device" { print $1 }')"
  if [[ -z "${devices}" ]]; then
    adb devices -l >&2
    echo "No authorized Android device is connected. Confirm the USB debugging prompt on the device." >&2
    exit 1
  fi

  adb shell am start -n "${ANDROID_PACKAGE}/${ANDROID_ACTIVITY}"
}

case "${MODE}" in
  --check|check)
    cargo fmt --manifest-path "${ROOT_DIR}/CTCore/Cargo.toml" -- --check
    cargo check --manifest-path "${ROOT_DIR}/CTCore/Cargo.toml" --features kotlin-bindings
    bash -n "${ROOT_DIR}/scripts/build-ctcore-android.sh" "${ROOT_DIR}/scripts/run-android-client.sh"
    run_gradle_if_available ":app:assembleDebug"
    ;;
  --bindings|bindings)
    "${ROOT_DIR}/scripts/build-ctcore-android.sh"
    ;;
  --build|build)
    run_gradle_if_available ":app:assembleDebug"
    ;;
  debug|--debug)
    run_gradle_if_available ":app:installDebug"
    launch_android_app
    ;;
  *)
    echo "Usage: $0 [--check|--bindings|--build|--debug]" >&2
    exit 2
    ;;
esac
