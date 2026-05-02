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
- `GET /threads?limit=20`: cold thread list from `session_index.jsonl`

## Current Scope

This slice proves the runnable Companion Core boundary. Semantic resume, send input, event streaming, and scouts land in later slices.
