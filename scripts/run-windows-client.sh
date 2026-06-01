#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WINDOWS_ROOT="$REPO_ROOT/clients/windows"
NATIVE_MANIFEST="$WINDOWS_ROOT/native/Cargo.toml"
TAURI_MANIFEST="$WINDOWS_ROOT/src-tauri/Cargo.toml"

usage() {
  cat <<'USAGE'
Usage:
  scripts/run-windows-client.sh --check
  scripts/run-windows-client.sh --service-check
  scripts/run-windows-client.sh --service-smoke
  scripts/run-windows-client.sh --dev
  scripts/run-windows-client.sh --legacy-check
  scripts/run-windows-client.sh --legacy-build
  scripts/run-windows-client.sh --legacy-dev

Options:
  --check          Check the native Rust/GPUI client.
  --service-check  Check the native Rust Host Runtime service without GPUI.
  --service-smoke  Start the native Host Runtime service and verify /health.
  --dev            Run the native Rust/GPUI client.
  --legacy-check   Check the legacy Tauri client.
  --legacy-build   Build the legacy Tauri app for the current platform.
  --legacy-dev     Run the legacy Tauri dev app for the current platform.
USAGE
}

mode="${1:---check}"

case "$mode" in
  --check)
    cargo fmt --manifest-path "$NATIVE_MANIFEST" -- --check
    cargo check --manifest-path "$NATIVE_MANIFEST"
    ;;
  --service-check)
    cargo fmt --manifest-path "$NATIVE_MANIFEST" -- --check
    cargo check --manifest-path "$NATIVE_MANIFEST" --no-default-features --lib
    ;;
  --service-smoke)
    cargo run --manifest-path "$NATIVE_MANIFEST" --no-default-features --bin host_runtime_smoke
    ;;
  --dev)
    cargo run --manifest-path "$NATIVE_MANIFEST"
    ;;
  --legacy-check)
    pnpm --dir "$WINDOWS_ROOT" install
    pnpm --dir "$WINDOWS_ROOT" build
    cargo fmt --manifest-path "$TAURI_MANIFEST" -- --check
    cargo check --manifest-path "$TAURI_MANIFEST"
    ;;
  --legacy-build)
    pnpm --dir "$WINDOWS_ROOT" install
    pnpm --dir "$WINDOWS_ROOT" tauri:build
    ;;
  --legacy-dev)
    pnpm --dir "$WINDOWS_ROOT" install
    pnpm --dir "$WINDOWS_ROOT" tauri:dev
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
