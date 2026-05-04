# Stream Abort Diagnosis

## Date

2026-05-04

## Reported Reality

Codex Remote sometimes receives events for a while, then stops receiving more events while the Codex turn is still visibly running. A later Thread refresh can surface `The operation couldn't be completed. Software caused connection abort.` The Thread Page then shows `polling`.

## Diagnosis

The active-turn WebSocket only sent frames when the Codex app-server emitted a notification. During long model reasoning or local command execution, the stream could become idle for tens of seconds. On a physical iPad over LAN, an idle WebSocket can be aborted by the URLSession/network path before Codex completes.

The iPad fallback state was working as designed in the narrow sense: stream receive failure moves the UI to `polling`. The weak part was that the stream had no keepalive, and a refresh could expose a transient connection abort instead of preserving the current Thread Page state.

## Fix Shape

- Companion sends a non-terminal `heartbeat` event every 15 seconds while a turn event WebSocket is open.
- Companion logs stream subscription, unavailable streams, client closes, and send failures at debug level.
- CraftingTable retries GET-style Companion requests once for transient URL/POSIX connection errors.
- Thread refresh preserves the existing `threadDetailResponse` when refresh fails, so a transient refresh error does not blank the active transcript.

## Verification

- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- Installed and launched CraftingTable on the paired iPad through `devicectl`.
- Ran debug Companion on `0.0.0.0:3765`.
- Local long-turn WebSocket smoke submitted a turn asking Codex to run `sleep 35`; the stream received `heartbeat` during the idle period.
- After the background turn completed, `GET /threads/{thread_id}` returned the final assistant text `CRAFTINGTABLE_HEARTBEAT_SMOKE_OK`.

## Remaining Risk

The physical iPad UI was built and launched, and its selected host endpoint was temporarily pointed at this Mac's current LAN address for debugging. The automated tool path available here does not expose physical iPad UI inspection, so the final interaction proof was the shared Companion/WebSocket path plus device build/install/launch.
