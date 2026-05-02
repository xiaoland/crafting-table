# Implementation Plan

## Goal

Bring up the first Codex Remote handoff MVP with the smallest runnable host companion and the thinnest CraftingTable surface that proves useful remote Codex control.

## Implementation Locations

- `Companion/`: host-side companion root, independent from the iPad SwiftUI app.
- `Companion/src/`: Companion Core.
- `Companion/scouts/macos/`: macOS Desktop Scout.
- `Companion/scouts/windows/`: Windows Desktop Scout.
- `CraftingTable/Features/CodexRemote/`: iPad-side Codex Remote UI and state after companion snapshots are stable.
- `CraftingTable/Features/Shared/`: only the shared models proven necessary by the standalone Codex Remote slice.

## Technology Stack

### Companion Core

Use Rust for the first host companion core.

Planned libraries:

- `tokio`: async runtime
- `axum`: minimal HTTP and WebSocket service
- `serde` and `serde_json`: JSON models
- `tokio::process`: launch and supervise local Codex app-server or CLI helper process

First transport target:

- connect to local Codex app-server through loopback for fastest verification
- keep the adapter boundary narrow so a later stdio adapter can replace loopback

### macOS Desktop Scout

Use a Swift executable.

Planned APIs:

- `ApplicationServices`
- `AXUIElement`
- focused window and focused element queries
- visible text, modal, and button clues where AX exposes them

Output shape:

- JSON snapshot consumed by Rust Companion Core

### Windows Desktop Scout

Use a C#/.NET console executable.

Planned APIs:

- Windows UI Automation
- top-level window lookup
- Raw View and Control View traversal
- focused element query
- visible text, modal, and action clues where UIA exposes them

Output shape:

- JSON snapshot matching the macOS Desktop Scout contract

Deployment options for `ws.yyh`:

- self-contained Windows build from another machine, or
- install .NET runtime/SDK on the host, then run framework-dependent builds

SSH belongs to development and smoke-test automation. The Windows Scout runtime is a local Windows executable launched by the host companion.

### iPad Client

Use native SwiftUI and URLSession.

Planned APIs:

- `URLSession` for request/response calls
- `URLSessionWebSocketTask` for companion event stream
- self-contained Codex Remote runtime state for the MVP

## MVP Execution Slices

1. Companion Core bootstrap
   - create `Companion/`
   - expose `health`
   - locate Codex CLI/app bundle
   - check app-server reachability

2. Semantic handoff spike
   - list threads through app-server adapter
   - resume a selected thread
   - send one input
   - stream status and assistant output

3. macOS Desktop Scout spike
   - detect active Codex Desktop window
   - emit active snapshot JSON
   - add confidence fields for reconciliation

4. Windows Desktop Scout spike
   - implement UIA snapshot using the proven scheduled-task execution path
   - emit the same snapshot schema as macOS
   - include structured error output for permissions, missing app, and empty UIA tree

5. CraftingTable Codex Remote spike
   - add host companion connection state
   - show thread list and selected snapshot
   - send input to selected thread
   - keep Goal Forest, Work Session, and Remote Control integration as later decisions

## Validation Steps

- `health` returns companion version, platform, Codex location, and scout availability.
- Companion can list at least one Codex thread.
- Companion can resume a known thread and send a marker input.
- Event stream reports status and assistant output.
- macOS Scout can produce active window snapshot.
- Windows Scout can produce active Codex top-level window snapshot on `ws.yyh`.
- CraftingTable can hold active host and thread state inside Codex Remote.

## Slice 1 Outcome

Companion Core bootstrap now exists in `Companion/`.

Implemented:

- Rust binary package `codex-remote-companion`
- `GET /health` for companion, platform, Codex CLI, app-server reachability, and scout placeholders
- `GET /threads?limit=20` for cold thread listing from `session_index.jsonl`
- unit coverage for session index parsing and malformed-record handling

Verified:

- `cargo test --manifest-path Companion/Cargo.toml`
- local HTTP smoke for `/health`
- local HTTP smoke for `/threads?limit=3`

## Open Technical Questions

- First companion transport: HTTP plus WebSocket, or one WebSocket RPC channel.
- First pairing UX for LAN use.
- Minimum app-server event set for a useful mobile projection.
- Amount of approval and user-input resolution in the first CraftingTable UI.
- CLI PTY fallback ownership between this task and task 0011.
