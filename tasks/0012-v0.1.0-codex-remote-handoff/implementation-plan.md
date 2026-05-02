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

2. macOS Desktop Scout spike
   - detect active Codex Desktop window
   - emit active snapshot JSON
   - add confidence fields for reconciliation

3. Windows Desktop Scout spike
   - implement UIA snapshot using the proven scheduled-task execution path
   - emit the same snapshot schema as macOS
   - include structured error output for permissions, missing app, and empty UIA tree

4. CraftingTable Codex Remote surface spike
   - add host companion connection state
   - show thread list and selected snapshot
   - keep Goal Forest, Work Session, and Remote Control integration as later decisions

5. Semantic handoff spike
   - inspect the installed Codex app-server protocol
   - resume a selected thread
   - send one input
   - stream or poll status and assistant output

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

## Slice 2 Outcome

macOS Desktop Scout now exists in `Companion/scouts/macos/`.

Implemented:

- Swift executable package `codex-macos-scout`
- Codex running-app discovery through `NSWorkspace`
- AX window snapshot with title, role, subrole, focus, main-window state, and bounds
- JSON output with app snapshots, window snapshots, errors, and confidence

Verified:

- `swift build --package-path Companion/scouts/macos`
- `swift run --package-path Companion/scouts/macos codex-macos-scout --pretty`
- local run found `com.openai.codex`, AX trusted state, and visible Codex windows

## Slice 3 Outcome

Windows Desktop Scout now exists in `Companion/scouts/windows/`.

Implemented:

- C#/.NET executable project `CodexWindowsScout`
- Windows UI Automation snapshot for Codex top-level windows, focused element, shell elements, bounds, and confidence
- finite-bound sanitization for UIA rectangles
- SSH-based development smoke harness in `scripts/windows-smoke/run-codex-windows-scout.sh`

Verified:

- `dotnet build Companion/scouts/windows/CodexWindowsScout.csproj`
- `scripts/windows-smoke/run-codex-windows-scout.sh ws.yyh`
- real Windows smoke found the Codex window, WebView shell, Chrome render host, and emitted `confidence: Low` with no scout errors

## Slice 4 Outcome

Standalone CraftingTable Codex Remote now exists in `CraftingTable/Features/CodexRemote/`.

Implemented:

- `AppRoute.codexRemote` and a dedicated sidebar entry
- `CodexRemoteScreen` with editable companion endpoint, host health, scout status, and Codex thread list
- `CodexRemoteClient` for Companion `GET /health` and `GET /threads?limit=20`
- target `Info.plist` entries for local-network usage and ATS local networking
- Codex Remote runtime state remains self-contained inside the feature

Verified:

- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- built app `Info.plist` contains `NSLocalNetworkUsageDescription` and `NSAppTransportSecurity.NSAllowsLocalNetworking`
- `git diff --check`

## Slice 5 Outcome

Companion semantic handoff now exists behind a CraftingTable-owned HTTP contract.

Implemented:

- `CodexAppServerClient` that launches local Codex app-server on an ephemeral loopback WebSocket port
- app-server `initialize` and `initialized` handshake
- app-server-backed `GET /threads?limit=20` with `session_index.jsonl` fallback
- `POST /threads/{thread_id}/resume` backed by `thread/resume`
- `POST /threads/{thread_id}/turns` backed by `thread/resume` plus `turn/start`
- synchronous MVP turn completion that aggregates `item/agentMessage/delta` until `turn/completed`

Verified:

- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- local Companion smoke for `GET /threads?limit=2`, `POST /threads/{thread_id}/resume`, and `POST /threads/{thread_id}/turns`
- marker response returned `CRAFTINGTABLE_COMPANION_RECHECK_OK` with status `completed`

## Slice 6 Outcome

CraftingTable Codex Remote can now submit a text turn through Companion.

Implemented:

- selectable thread rows in `CodexRemoteScreen`
- turn composer bound to the selected Codex thread
- `CodexRemoteClient.submitTurn` for `POST /threads/{thread_id}/turns`
- synchronous completed-turn result display with status, event count, and assistant text
- Companion API error decoding in the iPad client
- numeric app-server timestamps rendered as local dates in thread rows

Verified:

- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`

## Open Technical Questions

- First pairing UX for LAN use.
- Minimum app-server event set for a useful mobile projection.
- Amount of approval and user-input resolution in the first CraftingTable UI.
- CLI PTY fallback ownership between this task and task 0011.
