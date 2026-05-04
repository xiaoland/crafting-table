# Live Event Rendering Diagnosis

## Date

2026-05-04

## Reported Reality

During active Codex Remote streaming, tool-call-like items such as `webSearch` and `commandExecution` did not appear as transcript rows. The latest assistant bubble header badge changed as events arrived, but the richer tool rows appeared only after a manual Thread refresh.

## Diagnosis

The refresh path and live stream path carried different payloads.

Thread refresh uses Companion `GET /threads/{thread_id}` and normalizes app-server turn items through `summarize_thread_item`, producing stable `ThreadMessage` rows for command execution, web search, MCP tool calls, file changes, image generation, and generic events.

The live WebSocket path published `item_updated` with only `kind`. CraftingTable therefore had enough information to update the streaming status badge, but lacked the item id, text, and status needed to render the same transcript row shape during streaming.

## Fix Shape

- Companion `item_updated` stream events now include `item_id`, `text`, and `status` when app-server notification payloads contain an item.
- Companion reuses the existing refresh-path item summarizer for live item text, keeping live and refresh rendering aligned.
- CraftingTable decodes `item_id` from stream events.
- CraftingTable stores host-scoped `streamingMessages` for active tool, event, and assistant rows.
- Thread Page renders streaming tool/event rows before the active assistant draft and deduplicates them against refreshed thread messages by id.
- User item updates stay out of the streaming row list. Assistant item boundaries are covered by `live-agent-message-boundaries.md`.

## Verification

- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- Local Companion smoke on `127.0.0.1:3774` submitted an async turn asking Codex to run `printf CRAFTINGTABLE_LIVE_TOOL_ROW_OK`.
- Swift WebSocket smoke observed live `commandExecution` events with stable `item_id`, `inProgress` and `completed` statuses, and non-empty text before `turn_completed`.

## Remaining Risk

The smoke proved the shared Companion/WebSocket contract and iPad build. Visual confirmation on the physical iPad should focus on row placement and scroll behavior while tool rows and assistant rows arrive interleaved.
