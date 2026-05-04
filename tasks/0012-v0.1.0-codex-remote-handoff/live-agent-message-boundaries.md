# Live Agent Message Boundaries

## Date

2026-05-04

## Reported Reality

During active Codex Remote streaming, one Codex turn can emit multiple `agentMessage` items. CraftingTable collapsed all live assistant deltas into a single temporary assistant bubble, so the streaming transcript could differ from the refreshed Thread Page transcript.

## Diagnosis

Codex app-server `item/agentMessage/delta` notifications carry an `itemId`. That id is the stable boundary between assistant messages inside the same turn.

Companion previously forwarded only the delta text. CraftingTable therefore had only one host-scoped `streamingAssistantText` buffer, which forced all live assistant text for the active turn into one bubble. Thread refresh later used `GET /threads/{thread_id}` item rows and restored the correct multi-message shape.

## Fix Shape

- Companion publishes `assistant_delta` stream events with `kind: agentMessage` and `item_id`.
- `TurnEventBroker` replay preserves assistant delta item ids.
- CraftingTable keeps host-scoped `streamingMessages` for live assistant, tool, and event rows.
- `assistant_delta` appends text to the live assistant row matching `item_id`.
- Missing assistant item ids fall back to the legacy `streamingAssistantText` buffer.
- `agentMessage` `item_updated` events with text upsert the same assistant row, aligning live stream and refresh output.
- Thread Page renders visible streaming rows through `CodexRemoteMessageRow`, then shows the fallback waiting row only before any visible streaming row exists.
- Thread Page scrolls on a visible streaming row content fingerprint, so text growth inside an existing assistant row still follows the stream.

## Verification

- generated app-server schema for `AgentMessageDeltaNotification` exposes `itemId`
- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- local Companion smoke on `127.0.0.1:3776` submitted an async marker turn and replayed its WebSocket stream
- Swift WebSocket smoke observed `assistant_delta` frames with stable `item_id`, accumulated `CRAFTINGTABLE_AGENT_ITEM_ID_OK` by item id, then received `turn_completed`

## Remaining Risk

The smoke observed one live assistant item. It proves the protocol boundary and grouping data needed by CraftingTable. A naturally occurring turn with multiple live `agentMessage` ids remains the highest-value visual confirmation case on iPad.
