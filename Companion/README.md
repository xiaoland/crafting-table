# Codex Remote Companion

Host-side MVP service for the standalone Codex Remote slice.

## Run

```sh
cargo run --manifest-path Companion/Cargo.toml
```

Or use the repo launch helper:

```sh
./scripts/codex-remote-companion.sh companion
```

For the app-supervised host runtime path:

```sh
./scripts/codex-host-runtime.sh start
./scripts/codex-host-runtime.sh status
./scripts/codex-host-runtime.sh stop
```

Desktop clients should own login launch, background residency, and packaged helper supervision. This crate can also be embedded directly by linking the library API:

- `Config`
- `build_router(config)`
- `serve(config)`
- `serve_with_shutdown(config, shutdown)`

Default bind address:

```text
127.0.0.1:3765
```

Useful environment variables:

- `CODEX_REMOTE_BIND`: companion bind address
- `CODEX_HOME`: Codex state directory, defaulting to `~/.codex`
- `CODEX_BIN`: explicit Codex CLI path

For iPad LAN testing:

```sh
./scripts/codex-remote-companion.sh companion-lan
```

Run one macOS Scout snapshot:

```sh
./scripts/codex-remote-companion.sh scout
```

Probe a running Companion:

```sh
./scripts/codex-remote-companion.sh smoke
```

The same commands are exposed as Codex App Local Environment actions in:

```text
.codex/environments/environment.toml
```

## Endpoints

- `GET /health`: companion, platform, Codex CLI, app-server reachability, and scout placeholders
- `GET /threads?limit=20`: semantic thread list from Codex app-server with `cwd`, `project_key`, and `project_name`; falls back to `session_index.jsonl` with `Unknown Project`
- `POST /threads`: create a non-ephemeral project-scoped thread from `cwd`, optional `model`, and optional `service_tier`
- `GET /threads/{thread_id}`: read normalized thread metadata and message history
- `POST /threads/{thread_id}/resume`: resume a Codex thread through app-server
- `POST /threads/{thread_id}/turns`: submit one text turn, optionally with a model override, and return the completed assistant text
- `GET /models`: list visible Codex models for the host account
- `GET /desktop/snapshot`: run the platform Desktop Scout and return normalized hot-handoff clues
- `GET /host/runtime`: report host runtime process state, bind address, Codex home, launch context, and login/background residency flags

## Current Scope

This slice proves Companion-owned semantic handoff through a loopback Codex app-server and Desktop Scout snapshotting through a small Companion route.

The host runtime script is an interim development sidecar boundary. It supports background start/stop for local development, but it deliberately does not own login launch or app lifecycle policy. Pairing, authorization, packaged binary distribution, and in-app controls land in client-specific slices.
