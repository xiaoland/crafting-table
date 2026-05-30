# Codex Host Runtime Development Harness

Legacy host-side service code for Codex Remote. The product direction is in-process Host Runtime embedding through CTCore and desktop clients; this crate remains the development harness and migration source while that work proceeds.

## Run

Use the repo Host Runtime lifecycle helper for development:

```sh
./scripts/codex-host-runtime.sh start
./scripts/codex-host-runtime.sh status
./scripts/codex-host-runtime.sh smoke
./scripts/codex-host-runtime.sh stop
```

Run the service directly when debugging the Rust crate:

```sh
cargo run --manifest-path Companion/Cargo.toml
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

- `CODEX_REMOTE_BIND`: legacy runtime bind address
- `CODEX_HOME`: Codex state directory, defaulting to `~/.codex`
- `CODEX_BIN`: explicit Codex CLI path

For iPad LAN testing:

```sh
CODEX_HOST_RUNTIME_BIND=0.0.0.0:3765 ./scripts/codex-host-runtime.sh start
```

Run one macOS Scout snapshot:

```sh
./scripts/codex-remote-companion.sh scout
```

Probe a running development Host Runtime:

```sh
./scripts/codex-host-runtime.sh smoke
```

Host Runtime and macOS client commands are exposed as Codex App Local Environment actions in:

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

This slice proves host-runtime semantic handoff through a loopback Codex app-server and Desktop Scout snapshotting through a small route layer.

The host runtime script is an interim development sidecar boundary. It supports background start/stop for local development, but it deliberately does not own login launch or app lifecycle policy. Pairing, authorization, packaged binary distribution, and in-app controls land in client-specific slices.
