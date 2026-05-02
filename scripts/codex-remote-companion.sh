#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  scripts/codex-remote-companion.sh companion
  scripts/codex-remote-companion.sh companion-lan
  scripts/codex-remote-companion.sh scout
  scripts/codex-remote-companion.sh smoke

Commands:
  companion      Start Codex Remote Companion on CODEX_REMOTE_BIND, default 127.0.0.1:3765.
  companion-lan  Start Codex Remote Companion on CODEX_REMOTE_BIND, default 0.0.0.0:3765.
  scout          Run one macOS Desktop Scout JSON snapshot.
  smoke          Probe Companion health, desktop snapshot, and thread list.
USAGE
}

cd "$REPO_ROOT"

command="${1:-}"
case "$command" in
  companion)
    export CODEX_REMOTE_BIND="${CODEX_REMOTE_BIND:-127.0.0.1:3765}"
    echo "Starting Codex Remote Companion on ${CODEX_REMOTE_BIND}"
    exec cargo run --manifest-path Companion/Cargo.toml
    ;;
  companion-lan)
    export CODEX_REMOTE_BIND="${CODEX_REMOTE_BIND:-0.0.0.0:3765}"
    echo "Starting Codex Remote Companion on ${CODEX_REMOTE_BIND}"
    echo "Use your Mac LAN IP in CraftingTable, for example http://$(ipconfig getifaddr en0 2>/dev/null || echo '<mac-lan-ip>'):3765"
    exec cargo run --manifest-path Companion/Cargo.toml
    ;;
  scout)
    exec swift run --package-path Companion/scouts/macos codex-macos-scout --pretty
    ;;
  smoke)
    endpoint="${CODEX_REMOTE_ENDPOINT:-http://127.0.0.1:3765}"
    echo "Probing ${endpoint}/health"
    curl -fsS "${endpoint}/health"
    echo
    echo "Probing ${endpoint}/desktop/snapshot"
    curl -fsS "${endpoint}/desktop/snapshot"
    echo
    echo "Probing ${endpoint}/threads?limit=5"
    curl -fsS "${endpoint}/threads?limit=5"
    echo
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
