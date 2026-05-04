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

## Slice 7 Outcome

Companion now exposes Desktop Scout hot-handoff clues through a CraftingTable-owned route, and CraftingTable surfaces those clues inside Codex Remote.

Implemented:

- `GET /desktop/snapshot` in Companion
- platform scout launcher for macOS Swift Scout and Windows UIA Scout binaries
- normalized desktop snapshot response with platform, source, target app, confidence, window count, active window title, errors, and raw scout JSON
- Codex Remote client support for desktop snapshots
- `Desktop Handoff` panel in `CodexRemoteScreen`

Verified:

- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- local Companion smoke for `GET /desktop/snapshot`, returning `platform: macos`, `source: macos-swift-scout`, `confidence: medium`, `window_count: 3`, and no scout errors

## Open Technical Questions

- First pairing UX for LAN use.
- Minimum app-server event set for a useful mobile projection.
- Amount of approval and user-input resolution in the first CraftingTable UI.
- CLI PTY fallback ownership between this task and task 0011.

## Slice 8 Outcome

Companion can now serve the data needed by a Codex-like Thread Page.

Implemented:

- `GET /threads/{thread_id}` backed by app-server `thread/read` with `includeTurns: true`
- normalized thread detail with cwd, status, source, model provider, and turn count
- normalized message history flattened from app-server turn items
- `GET /models` backed by app-server `model/list`
- optional `model` field on `POST /threads/{thread_id}/turns`, forwarded to app-server `turn/start`

Verified:

- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- live Companion smoke on `127.0.0.1:3769`
- `GET /threads/019ddd34-e1aa-7600-a7c8-179a67b56908` returned 16 turns and 660 normalized messages
- `GET /models` returned 6 visible models with `gpt-5.5` marked as default

## Slice 9 Outcome

CraftingTable now has an iPad-first Codex Remote Thread Page.

Implemented:

- split layout with Companion/Host/Desktop/Threads sidebar and a selected-thread page
- selected thread header with status, turn count, cwd, updated time, and desktop handoff confidence
- transcript rendering for normalized user, assistant, and tool/event messages
- bottom composer with model picker backed by Companion `GET /models`
- `CodexRemoteClient` support for thread detail, model list, optional model override, and graceful model-list fallback
- `CodexRemoteThreadPage.swift` split from the root screen to keep state ownership and transcript UI easier to scan

Verified:

- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `git diff --check`

## Slice 10 Outcome

CraftingTable can now submit Codex Remote turns from iPad without holding the request open for full model completion.

Implemented:

- optional `wait_for_completion` field on Companion `POST /threads/{thread_id}/turns`
- background Companion completion wait for nonblocking turn submissions
- CraftingTable `submitTurn` payload support for `wait_for_completion`
- iPad Thread Page submission path that reloads selected thread detail immediately, then schedules short follow-up refreshes
- task packet diagnosis for the physical-iPad send failure report

Verified:

- LAN Companion `GET /health`, `GET /threads?limit=1`, and `GET /models` against `http://192.168.4.16:3765`
- direct LAN synchronous `POST /threads/019ddd34-e1aa-7600-a7c8-179a67b56908/turns` returned `CRAFTINGTABLE_IPAD_SEND_DIAG_OK`
- local async Companion smoke with `wait_for_completion: false` returned `status: started` quickly, then thread detail showed `CRAFTINGTABLE_ASYNC_SEND_OK`
- updated LAN Companion on `http://192.168.4.16:3765` returned `status: started` in about 2.2 seconds, then thread detail showed `CRAFTINGTABLE_LAN_ASYNC_SEND_OK`
- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`

## Next Experience Slices

### Slice 11 Planned: Remote Profiles and Project Threads

Combine multi-host support and project-based thread navigation in one slice.

Objective:

- CraftingTable can manage more than one trusted Companion endpoint.
- Thread navigation is grouped by Codex project instead of one flat recency list.

Implementation shape:

- iPad owns remote host profiles for the MVP, persisted locally with endpoint, label, last health, and last-used time.
- The active host owns its own health, desktop snapshot, model list, thread list, selected thread, selected model, and transient submit state.
- Companion remains a single-host service; it reports richer thread metadata for the host it is running on.
- `GET /threads` extends each summary with `cwd`, `project_key`, and `project_name`.
- CraftingTable groups thread summaries by `project_key`, sorts projects by newest contained thread, then sorts threads by updated time inside each project.
- Threads without a usable cwd are grouped under `Unknown Project`.

Verification:

- unit coverage for project summary derivation in Companion
- iPad preview/build coverage for multiple saved hosts and grouped project sections
- smoke with at least two endpoints, such as LAN Companion plus loopback Companion, when both are available
- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`

### Slice 12 Planned: Streaming Turns

Add a CraftingTable-owned live event projection so the Thread Page can update while Codex is still working.

Objective:

- submit returns quickly
- assistant deltas and tool/status events appear without polling the full thread detail
- final thread detail remains the reconciliation source after completion

Implementation shape:

- Companion introduces an active-turn event broker keyed by host-local `thread_id` and `turn_id`.
- Background app-server notification reads publish normalized events to the broker.
- CraftingTable subscribes over a WebSocket route for active turn events.
- The event stream includes `turn_started`, `assistant_delta`, `item_updated`, `turn_completed`, and `error` for the MVP.
- The iPad keeps polling fallback behavior for hosts that do not expose the streaming route.

Verification:

- Companion smoke proves deltas arrive before `turn_completed`.
- iPad build proves the stream client compiles and lifecycle cancellation is explicit when switching thread or host.
- Existing nonblocking submit smoke remains valid.

### Slice 13 Planned: Composer Controls and Codex-like Rendering

Expand composer controls and improve transcript rendering after streaming foundations exist.

Objective:

- choose model, reasoning effort, and Fast speed tier from the composer
- render Thread Page messages closer to Codex App's transcript shape

Implementation shape:

- `GET /models` includes `default_reasoning_level`, `supported_reasoning_levels`, and `additional_speed_tiers` from Codex model metadata where available.
- `POST /threads/{thread_id}/turns` accepts model, reasoning effort, and speed tier once app-server `turn/start` parameter names are verified.
- Composer presents model as a menu, reasoning effort as a compact segmented/menu control, and Fast as a toggle when supported by the selected model.
- Transcript rows move toward Codex-style blocks: user prompt, assistant markdown, tool call disclosure, command output, file changes, web search, and status/progress rows.
- Raw app-server item kinds stay behind Companion's normalized message/event contract.

Verification:

- app-server smoke verifies the accepted `turn/start` parameter names for reasoning effort and speed tier before the UI sends them.
- model-list smoke verifies the selected model's supported efforts and speed tiers.
- iPad build and visual pass cover long text, tool output, and streaming assistant deltas.

## Launch Entrypoints

Codex Remote Companion now has shared local launch entrypoints:

- `scripts/codex-remote-companion.sh companion`: local-only Companion startup on `127.0.0.1:3765` by default.
- `scripts/codex-remote-companion.sh companion-lan`: LAN Companion startup on `0.0.0.0:3765` by default for iPad testing.
- `scripts/codex-remote-companion.sh scout`: one macOS Desktop Scout snapshot.
- `scripts/codex-remote-companion.sh smoke`: health, desktop snapshot, and thread-list smoke against `CODEX_REMOTE_ENDPOINT` or `http://127.0.0.1:3765`.

Codex App exposes the same commands as Local Environment actions in `.codex/environments/environment.toml`.

VS Code exposes the same commands as tasks under `Codex Remote:*`.

Official Codex docs describe Local Environment actions as project actions that appear in the Codex App top bar and run inside the app's integrated terminal. This fits Companion and macOS Scout startup because the commands depend on the developer's interactive Mac session and Accessibility permission.

Verified:

- `bash -n scripts/codex-remote-companion.sh`
- `python3 -c 'import tomllib; tomllib.load(open(".codex/environments/environment.toml", "rb"))'`
- `jq empty .vscode/tasks.json`
- `./scripts/codex-remote-companion.sh scout`
- `./scripts/codex-remote-companion.sh companion`
- `./scripts/codex-remote-companion.sh smoke`

Latest smoke against an already-running Companion confirmed `/health`, `/desktop/snapshot`, and `/threads?limit=5` all returned. The existing Companion process lacked macOS Accessibility trust in that launch context, so the desktop snapshot reported `confidence: low` with an AX window-read error. Launching the same script from an Accessibility-trusted terminal context restores window-level Scout data.
