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

## Slice 11 Outcome

CraftingTable now supports multiple Codex Remote hosts and groups the active host's thread list by project.

Implemented:

- Companion `GET /threads` extends each thread summary with `cwd`, `project_key`, and `project_name`.
- Companion derives project metadata from app-server `cwd`, including Windows-style path support.
- `session_index.jsonl` fallback emits `Unknown Project` for stable backward behavior when no cwd exists.
- CraftingTable persists Codex Remote host profiles locally with endpoint, label, last health status, and last-used time.
- The active host owns its own health, desktop snapshot, model list, thread list, selected thread, selected model, composer input, and submit state.
- The Codex Remote sidebar now has a host picker, editable host name, add/delete host controls, editable endpoint, and project-grouped thread sections.

Verified:

- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- local Companion smoke on `127.0.0.1:3769` showed `/threads?limit=3` returning `workbench` and `Beluna` project metadata
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`

## Slice 12 Outcome

CraftingTable now receives live active-turn events from Companion while Codex is working.

Implemented:

- Companion active-turn broker keyed by host-local `thread_id` and `turn_id`.
- WebSocket route `GET /threads/{thread_id}/turns/{turn_id}/events`.
- Replay and broadcast for `turn_started`, `assistant_delta`, `item_updated`, `turn_completed`, and `error`.
- app-server notification publishing from background turn waits.
- CraftingTable `URLSessionWebSocketTask` client for active turn streams.
- host-scoped stream task lifecycle and cancellation on host, thread, delete, and endpoint changes.
- temporary streaming assistant row in the Thread Page, reconciled from `GET /threads/{thread_id}` after completion.
- existing polling refresh retained as fallback and final source-of-truth reconciliation.

Verified:

- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- local Companion smoke on `127.0.0.1:3770`
- async submit returned `status: started` for turn `019df235-5a08-75c0-98c5-b9f189dee4ec`
- Swift WebSocket smoke received `turn_started`, `item_updated`, multiple `assistant_delta` frames composing `CRAFTINGTABLE_STREAM_SMOKE_OK`, then `turn_completed`

## Slice 12.1 Outcome

Codex Remote streaming now handles long active turns and manual refresh more gracefully.

Implemented:

- async active-turn streaming no longer shares the 120 second synchronous completion timeout.
- synchronous `wait_for_completion: true` submit keeps its bounded completion wait.
- Thread Page refresh preserves an in-progress streaming assistant draft when thread detail only contains partial assistant items.
- streaming draft cleanup requires terminal completion evidence from either the WebSocket stream or thread detail status.
- stream errors keep the current draft visible and allow polling refresh to reconcile.

Verified:

- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- short live Companion stream smoke on `127.0.0.1:3771` returned `CRAFTINGTABLE_STREAM_TIMEOUT_FIX_OK` through assistant delta frames, then `turn_completed`
- `git diff --check`

## Slice 12.2 Outcome

Codex Remote active-turn streaming now keeps idle LAN WebSockets alive during long Codex work.

Implemented:

- Companion sends a non-terminal `heartbeat` stream event every 15 seconds while a turn event WebSocket is open.
- Companion emits debug logs for stream subscription, unavailable streams, client closes, and send failures.
- CraftingTable retries GET-style Companion requests once for transient URL/POSIX connection errors.
- Thread refresh preserves the existing transcript when a refresh fails during or after stream fallback.

Verified:

- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- installed and launched CraftingTable on the paired iPad through `devicectl`
- debug Companion on `0.0.0.0:3765`
- local long-turn WebSocket smoke received `heartbeat` while Codex was running `sleep 35`
- post-completion `GET /threads/{thread_id}` returned `CRAFTINGTABLE_HEARTBEAT_SMOKE_OK`

## Slice 12.3 Outcome

Codex Remote active-turn streaming now renders live tool and event items as transcript rows.

Implemented:

- Companion `item_updated` events carry `item_id`, `text`, and `status` when the app-server notification includes an item payload.
- Companion reuses the same item summarizer used by `GET /threads/{thread_id}` for live item text.
- CraftingTable decodes stream `item_id` and keeps host-scoped `streamingMessages`.
- Thread Page renders streaming tool/event rows before the active assistant draft.
- Refreshed thread messages deduplicate streaming event rows by message id.

Verified:

- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- local Companion smoke on `127.0.0.1:3774`
- Swift WebSocket smoke saw live `commandExecution` `item_updated` events with stable item id, status changes from `inProgress` to `completed`, and non-empty text before `turn_completed`

## Slice 13 Outcome

Codex Remote composer controls now support model, reasoning effort, and Fast service tier selection.

Implemented:

- Companion `GET /models` returns `default_reasoning_effort`, `supported_reasoning_efforts`, and `additional_speed_tiers`.
- Companion `POST /threads/{thread_id}/turns` accepts optional `reasoning_effort` and `service_tier`.
- Companion maps public `reasoning_effort` to app-server `effort`.
- Companion maps public `service_tier` to app-server `serviceTier`.
- CraftingTable keeps reasoning and Fast selections in the active host runtime, alongside the selected model.
- Thread Page composer shows model, reasoning effort, and Fast controls from selected-model capabilities.
- Fast appears only when the selected model advertises the `fast` speed tier.
- Assistant and streaming assistant messages render with native Markdown attributed text.
- Tool and event rows use clearer labels and monospaced command output.

Verified:

- app-server `model/list` probe showed six visible models with reasoning effort metadata.
- embedded app-server `TurnStartParams` schema exposes `model`, `effort`, and `serviceTier`.
- local Companion smoke on `127.0.0.1:3773` returned `gpt-5.5` with default effort `medium`, four supported efforts, and `priority` plus `fast` speed tiers.
- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`

## Slice 13.1 Outcome

Codex Remote composer controls now support per-turn permission mode selection.

Implemented:

- Companion `POST /threads/{thread_id}/turns` accepts optional `permission_mode`.
- Companion maps CraftingTable modes to app-server `sandboxPolicy`, `approvalPolicy`, and `approvalsReviewer`.
- CraftingTable keeps `selectedPermissionMode` in the active host runtime.
- Thread Page composer shows a compact permission picker with `Sandbox`, `Auto-review`, and `Full access`.
- New submissions send `permission_mode`, defaulting to `sandbox`.

Verified:

- generated app-server TypeScript schema for `TurnStartParams`
- local smoke showed profile-selection `permissions` payload requires configured `[permissions]` profiles
- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- local async Companion smoke on `127.0.0.1:3775` started and reconciled `sandbox`, `auto_review`, `full_access`, then a final `sandbox` reset turn

## Slice 13.2 Outcome

Codex Remote active-turn streaming now preserves live assistant message item boundaries.

Implemented:

- Companion forwards app-server `item/agentMessage/delta` `itemId` as stream `item_id`.
- Companion marks assistant delta stream events as `kind: agentMessage`.
- CraftingTable appends assistant deltas to host-scoped `streamingMessages` by `item_id`.
- CraftingTable still uses `streamingAssistantText` as a fallback for deltas without item ids.
- Live `agentMessage` `item_updated` rows upsert the same assistant message shape used by thread refresh.
- Thread Page renders live assistant rows through the normal message row renderer.
- Thread Page scrolls on streaming row content changes, not only row count changes.

Verified:

- generated app-server schema for `AgentMessageDeltaNotification`
- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- local Companion smoke on `127.0.0.1:3776` replayed `assistant_delta` frames with a stable `item_id`, accumulated `CRAFTINGTABLE_AGENT_ITEM_ID_OK` by item id, then received `turn_completed`

## Slice 13.3 Outcome

Codex Remote composer controls now keep their labels on one line under sidebar width changes.

Diagnosis:

- iPad Pro 13-inch simulator reproduced `GPT-5.5` and `Medium` wrapping with the app sidebar visible.
- The same wrapping persisted after hiding the app sidebar, pointing to the composer controls row's own compression behavior.
- Accessibility labels remained complete, confirming a visual layout compression issue.

Implemented:

- Replaced the `ViewThatFits` controls layout with a trailing Send button plus a horizontal options strip.
- The options strip scrolls horizontally when space is tight.
- Model, reasoning, Fast, and permission labels use a shared non-wrapping label view.
- Picker and toggle controls are fixed-size horizontally before the options strip scrolls.

Verified:

- `xcodebuildmcp` simulator build and run on `iPad Pro 13-inch (M5)`
- simulator visual check with the app sidebar visible
- simulator visual check with the app sidebar hidden
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`

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
