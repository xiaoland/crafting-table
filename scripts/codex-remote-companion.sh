#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  scripts/codex-remote-companion.sh scout
  scripts/codex-remote-companion.sh smoke

Commands:
  scout  Run one macOS Desktop Scout JSON snapshot.
  smoke  Legacy alias for scripts/codex-host-runtime.sh smoke.

Host Runtime lifecycle commands now live in:
  scripts/codex-host-runtime.sh run|start|stop|restart|status|logs|smoke
USAGE
}

cd "$REPO_ROOT"

command="${1:-}"
case "$command" in
  companion|companion-lan)
    echo "The direct Companion launcher has moved to Host Runtime development commands." >&2
    echo "Use ./scripts/codex-host-runtime.sh run or ./scripts/codex-host-runtime.sh start." >&2
    if [[ "$command" == "companion-lan" ]]; then
      echo "For LAN testing: CODEX_HOST_RUNTIME_BIND=0.0.0.0:3765 ./scripts/codex-host-runtime.sh start" >&2
    fi
    exit 64
    ;;
  scout)
    exec swift run --package-path Companion/scouts/macos codex-macos-scout --pretty
    ;;
  smoke)
    exec "$SCRIPT_DIR/codex-host-runtime.sh" smoke
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
