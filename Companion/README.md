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
- `GET /desktop/snapshot`: run the platform Desktop Scout and return normalized hot-handoff clues

## Current Scope

This slice proves Companion-owned semantic handoff through a loopback Codex app-server and Desktop Scout snapshotting through a small Companion route. Event streaming, approval handling, persistent app-server supervision, and pairing land in later slices.
