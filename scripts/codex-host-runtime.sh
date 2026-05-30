#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

STATE_DIR="${CODEX_HOST_RUNTIME_STATE_DIR:-$HOME/Library/Application Support/CraftingTable/CodexHostRuntime}"
LOG_DIR="$STATE_DIR/logs"
PID_FILE="$STATE_DIR/runtime.pid"
STDOUT_LOG="$LOG_DIR/stdout.log"
STDERR_LOG="$LOG_DIR/stderr.log"
DEFAULT_BIND="${CODEX_HOST_RUNTIME_BIND:-${CODEX_REMOTE_BIND:-127.0.0.1:3765}}"
ENDPOINT="${CODEX_HOST_RUNTIME_ENDPOINT:-http://${DEFAULT_BIND/0.0.0.0/127.0.0.1}}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/codex-host-runtime.sh run
  scripts/codex-host-runtime.sh start
  scripts/codex-host-runtime.sh stop
  scripts/codex-host-runtime.sh restart
  scripts/codex-host-runtime.sh status
  scripts/codex-host-runtime.sh logs
  scripts/codex-host-runtime.sh smoke

Commands:
  run              Run the host runtime in the foreground.
  start            Start the host runtime in the background for development.
  stop             Stop the background host runtime started by this script.
  restart          Stop, then start the background host runtime.
  status           Print process and HTTP health status.
  logs             Tail runtime stdout and stderr logs.
  smoke            Probe health, runtime state, desktop snapshot, and threads.

Environment:
  CODEX_HOST_RUNTIME_BIND       Bind address, default 127.0.0.1:3765.
  CODEX_HOST_RUNTIME_BINARY     Optional packaged runtime binary path.
  CODEX_HOST_RUNTIME_STATE_DIR  Runtime state/log directory.
  CODEX_BIN                     Optional Codex CLI path passed through.
  CODEX_HOME                    Optional Codex home passed through.
USAGE
}

ensure_dirs() {
  mkdir -p "$STATE_DIR" "$LOG_DIR"
}

pid_is_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

runtime_pid() {
  if pid_is_running; then
    cat "$PID_FILE"
  fi
}

run_foreground() {
  ensure_dirs
  export CODEX_REMOTE_BIND="${CODEX_REMOTE_BIND:-$DEFAULT_BIND}"
  export CODEX_HOST_RUNTIME_LAUNCH_CONTEXT="${CODEX_HOST_RUNTIME_LAUNCH_CONTEXT:-app-supervised}"

  echo "$$" > "$PID_FILE"

  cleanup() {
    rm -f "$PID_FILE"
  }

  trap cleanup EXIT

  cd "$REPO_ROOT"

  if [[ -n "${CODEX_HOST_RUNTIME_BINARY:-}" ]]; then
    exec "$CODEX_HOST_RUNTIME_BINARY"
  fi

  exec cargo run --manifest-path Companion/Cargo.toml
}

start_background() {
  ensure_dirs

  if pid_is_running; then
    echo "Codex Host Runtime is already running with pid $(runtime_pid)."
    return
  fi

  ensure_runtime_binary
  local binary
  binary="$(runtime_binary)"

  CODEX_REMOTE_BIND="$DEFAULT_BIND" \
  CODEX_HOST_RUNTIME_LAUNCH_CONTEXT="app-supervised" \
    nohup "$binary" >"$STDOUT_LOG" 2>"$STDERR_LOG" &

  echo $! > "$PID_FILE"
  echo "Started Codex Host Runtime with pid $! on $DEFAULT_BIND."
}

stop_background() {
  if pid_is_running; then
    local pid
    pid="$(runtime_pid)"
    kill "$pid" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "Stopped Codex Host Runtime pid $pid."
    return
  fi

  rm -f "$PID_FILE"
  echo "Codex Host Runtime is not running."
}

status() {
  ensure_dirs

  if pid_is_running; then
    echo "process: running pid $(runtime_pid)"
  else
    echo "process: stopped"
  fi

  echo "bind: $DEFAULT_BIND"
  echo "endpoint: $ENDPOINT"

  local status_file
  status_file="$(mktemp)"
  if curl -fsS "$ENDPOINT/host/runtime" >"$status_file" 2>/dev/null; then
    echo "health: reachable"
    cat "$status_file"
    echo
  else
    echo "health: unreachable"
  fi
  rm -f "$status_file"
}

tail_logs() {
  ensure_dirs
  touch "$STDOUT_LOG" "$STDERR_LOG"
  tail -n 80 -f "$STDOUT_LOG" "$STDERR_LOG"
}

smoke() {
  echo "Probing ${ENDPOINT}/health"
  curl -fsS "${ENDPOINT}/health"
  echo
  echo "Probing ${ENDPOINT}/host/runtime"
  curl -fsS "${ENDPOINT}/host/runtime"
  echo
  echo "Probing ${ENDPOINT}/desktop/snapshot"
  curl -fsS "${ENDPOINT}/desktop/snapshot"
  echo
  echo "Probing ${ENDPOINT}/threads?limit=5"
  curl -fsS "${ENDPOINT}/threads?limit=5"
  echo
}

runtime_binary() {
  if [[ -n "${CODEX_HOST_RUNTIME_BINARY:-}" ]]; then
    echo "$CODEX_HOST_RUNTIME_BINARY"
    return
  fi

  echo "$REPO_ROOT/Companion/target/debug/codex-remote-companion"
}

ensure_runtime_binary() {
  if [[ -n "${CODEX_HOST_RUNTIME_BINARY:-}" ]]; then
    return
  fi

  cd "$REPO_ROOT"
  cargo build --manifest-path Companion/Cargo.toml
}

command="${1:-}"
case "$command" in
  run)
    run_foreground
    ;;
  start)
    start_background
    ;;
  stop)
    stop_background
    ;;
  restart)
    stop_background
    start_background
    ;;
  status)
    status
    ;;
  logs)
    tail_logs
    ;;
  smoke)
    smoke
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
