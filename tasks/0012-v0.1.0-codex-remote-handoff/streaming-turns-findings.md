# Streaming Turns Findings

## Purpose

This note records Slice 12 for active Codex Remote turns. It keeps the streaming contract and smoke evidence separate from Thread Page UI notes and earlier semantic handoff findings.

## Companion Contract

Companion now exposes a process-local active-turn stream:

- `POST /threads/{thread_id}/turns` with `wait_for_completion: false` creates an active stream for the returned `turn_id`.
- `GET /threads/{thread_id}/turns/{turn_id}/events` upgrades to WebSocket.
- Events are JSON text frames with a monotonic `sequence`.
- Replay is available for late subscribers while the Companion process keeps the active turn in memory.
- Terminal events close the WebSocket after delivery.

MVP event types:

- `turn_started`
- `assistant_delta`
- `item_updated`
- `turn_completed`
- `error`

The final reconciliation source remains `GET /threads/{thread_id}` after completion.

## Companion Implementation Notes

- `turn_events.rs` owns the replay buffer and broadcast channels.
- The broker key is host-local `(thread_id, turn_id)`.
- The replay buffer currently stores the latest 200 events per active turn.
- `app_server.rs` publishes assistant deltas from `item/agentMessage/delta`.
- Item updates are emitted for matched app-server `item/*` notifications.
- Background turn failures publish an `error` event.
- Axum WebSocket support is enabled through the `ws` feature.

## iPad Implementation Notes

- `CodexRemoteClient` adds `URLSessionWebSocketTask` support for turn streams.
- `CodexRemoteScreen` starts a stream after async submit returns `status: started`.
- Each host runtime owns its current stream task, streaming turn id, draft assistant text, stream status, event count, and stream error.
- Switching host, switching thread, deleting a host, or editing an endpoint cancels the current stream task for that host.
- The Thread Page appends streaming assistant deltas into a temporary assistant row.
- When thread detail later contains the completed assistant message for the same turn, the temporary streaming row is cleared.
- The existing short polling refresh remains as the fallback and reconciliation path.

## Smoke Evidence

Commands run from `/Users/lanzhijiang/Development/workbench`:

- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- temporary Companion on `127.0.0.1:3770`
- `GET /health`
- `GET /threads?limit=1`
- async `POST /threads/019ddd34-e1aa-7600-a7c8-179a67b56908/turns`
- Swift WebSocket client against `ws://127.0.0.1:3770/threads/019ddd34-e1aa-7600-a7c8-179a67b56908/turns/019df235-5a08-75c0-98c5-b9f189dee4ec/events`

Observed stream:

- `turn_started`
- `item_updated`
- multiple `assistant_delta` frames composing `CRAFTINGTABLE_STREAM_SMOKE_OK`
- `turn_completed` with `status: completed` and `event_count: 30`

This proves that deltas arrive through the Companion WebSocket before final thread-detail reconciliation.

## Remaining Risks

- Active streams are process-local memory. Companion restart loses live replay.
- Replay retention has a fixed MVP limit.
- Tool/status rendering is still generic through `item_updated`.
- Approval and user-input request states need a later normalized event shape.
- Reasoning effort and Fast controls still depend on app-server parameter verification.
