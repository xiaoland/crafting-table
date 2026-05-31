#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
WINDOWS_ROOT="$REPO_ROOT/clients/windows"

usage() {
  cat <<'USAGE'
Usage:
  scripts/run-windows-client.sh --check
  scripts/run-windows-client.sh --build
  scripts/run-windows-client.sh --dev

Options:
  --check   Check Rust backend and frontend TypeScript build.
  --build   Build the Tauri app for the current platform.
  --dev     Run the Tauri dev app for the current platform.
USAGE
}

mode="${1:---check}"

case "$mode" in
  --check)
    pnpm --dir "$WINDOWS_ROOT" install
    pnpm --dir "$WINDOWS_ROOT" build
    cargo fmt --manifest-path "$WINDOWS_ROOT/src-tauri/Cargo.toml" -- --check
    cargo check --manifest-path "$WINDOWS_ROOT/src-tauri/Cargo.toml"
    ;;
  --build)
    pnpm --dir "$WINDOWS_ROOT" install
    pnpm --dir "$WINDOWS_ROOT" tauri:build
    ;;
  --dev)
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
