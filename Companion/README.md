# Codex Remote Companion

Host-side MVP service for the standalone Codex Remote slice.

## Run

```sh
cargo run --manifest-path Companion/Cargo.toml
```

Default bind address:

```text
127.0.0.1:3765
```

Useful environment variables:

- `CODEX_REMOTE_BIND`: companion bind address
- `CODEX_HOME`: Codex state directory, defaulting to `~/.codex`
- `CODEX_BIN`: explicit Codex CLI path

## Endpoints

- `GET /health`: companion, platform, Codex CLI, app-server reachability, and scout placeholders
- `GET /threads?limit=20`: semantic thread list from Codex app-server with `session_index.jsonl` fallback
- `POST /threads/{thread_id}/resume`: resume a Codex thread through app-server
- `POST /threads/{thread_id}/turns`: submit one text turn and return the completed assistant text

## Current Scope

This slice proves Companion-owned semantic handoff through a loopback Codex app-server. Event streaming, approval handling, and persistent app-server supervision land in later slices.
