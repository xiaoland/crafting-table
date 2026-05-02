# Semantic Handoff Findings

## Protocol Facts

- Installed CLI path: `/Applications/Codex.app/Contents/Resources/codex`
- Installed CLI version: `codex-cli 0.126.0-alpha.8`
- App-server can run as `codex app-server --listen ws://127.0.0.1:<port>`
- App-server exposes `readyz` and `healthz` HTTP probes beside the WebSocket listener
- WebSocket messages use JSON-RPC-shaped request, response, error, and notification objects
- First request is `initialize`; client then sends `initialized`

## Methods Used

- `thread/list`: list semantic thread metadata
- `thread/read`: load one thread with turns for message history
- `thread/resume`: load a selected thread into the app-server runtime
- `turn/start`: submit one user text input
- `model/list`: load Codex model choices
- `item/agentMessage/delta`: stream assistant text deltas
- `turn/completed`: mark synchronous MVP completion
- `error`: report turn failure

## Companion Contract

The Companion owns app-server lifecycle and protocol churn. CraftingTable speaks these MVP routes:

- `GET /threads?limit=20`
- `GET /threads/{thread_id}`
- `GET /models`
- `POST /threads/{thread_id}/resume`
- `POST /threads/{thread_id}/turns`

`GET /threads` prefers app-server metadata and falls back to `session_index.jsonl` when app-server startup or protocol calls fail.

`GET /threads/{thread_id}` normalizes app-server turn items into a CraftingTable message list. `GET /models` normalizes visible model choices. `POST /threads/{thread_id}/turns` accepts an optional `model` field and forwards it to app-server `turn/start`.

## Smoke Evidence

Commands run from `/Users/lanzhijiang/Development/workbench`:

- `cargo test --manifest-path Companion/Cargo.toml`
- `cargo run --manifest-path Companion/Cargo.toml`
- `curl -fsS 'http://127.0.0.1:3765/threads?limit=2'`
- `curl -fsS -X POST http://127.0.0.1:3765/threads/019de6f3-168c-7a40-b782-aedda72f48f5/resume`
- `curl -fsS -X POST http://127.0.0.1:3765/threads/019de6f3-168c-7a40-b782-aedda72f48f5/turns -H 'Content-Type: application/json' --data '{"input":"Reply with exactly: CRAFTINGTABLE_COMPANION_RECHECK_OK","cwd":"/Users/lanzhijiang/Development/workbench"}'`

Observed turn result:

```json
{
  "thread_id": "019de6f3-168c-7a40-b782-aedda72f48f5",
  "turn_id": "019de6f8-ec62-7a80-82df-4fa88c5f6a43",
  "status": "completed",
  "assistant_text": "CRAFTINGTABLE_COMPANION_RECHECK_OK",
  "event_count": 31
}
```

## Next Cut

Add live event projection for active turns, including status changes, assistant deltas, approval requests, user-input requests, and errors.
