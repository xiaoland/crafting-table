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
- `thread/start`: create a project-scoped semantic thread
- `thread/name/set`: materialize a new zero-turn thread with an initial title
- `turn/start`: submit one user text input
- `model/list`: load Codex model choices
- `item/agentMessage/delta`: stream assistant text deltas
- `turn/completed`: mark synchronous MVP completion
- `error`: report turn failure

## Protocol Discovery Needed

Before implementing composer controls, verify app-server `turn/start` parameter names for:

- reasoning effort
- Fast or speed-tier selection

Local Codex metadata already exposes model capabilities through `models_cache.json`, including `default_reasoning_level`, `supported_reasoning_levels`, and `additional_speed_tiers`. Companion should still treat app-server request parameter names as runtime protocol facts and verify them with smoke tests before CraftingTable sends those fields.

## Companion Contract

The Companion owns app-server lifecycle and protocol churn. CraftingTable speaks these MVP routes:

- `GET /threads?limit=20`
- `POST /threads`
- `GET /threads/{thread_id}`
- `GET /models`
- `POST /threads/{thread_id}/resume`
- `POST /threads/{thread_id}/turns`

`GET /threads` prefers app-server metadata and falls back to `session_index.jsonl` when app-server startup or protocol calls fail.

`GET /threads/{thread_id}` normalizes app-server turn items into a CraftingTable message list. `GET /models` normalizes visible model choices. `POST /threads/{thread_id}/turns` accepts optional `model` and `wait_for_completion` fields. Companion forwards `model` to app-server `turn/start`. `wait_for_completion` defaults to `true` for compatibility. When `wait_for_completion` is `false`, Companion returns `status: started` after `turn/start` and keeps waiting for completion in a background task.

Route extensions added in Slice 11:

- `GET /threads` includes `cwd`, `project_key`, and `project_name` on each thread summary so CraftingTable can group by project without reading every thread detail first.

Route extensions added for thread creation:

- `POST /threads` accepts `cwd`, optional `model`, and optional `service_tier`.
- Companion calls app-server `thread/start`, then `thread/name/set` with `New thread`, then `thread/read` to return readable metadata.
- CraftingTable keeps a local projection for newly created zero-turn threads because app-server `thread/list` omits them until later activity.

Planned route extensions:

- `GET /models` includes default reasoning level, supported reasoning levels, and speed tiers when app-server or local metadata exposes them.
- `POST /threads/{thread_id}/turns` accepts reasoning effort and speed tier after their app-server parameter names are verified.
- a WebSocket event route publishes normalized active-turn events keyed by `thread_id` and `turn_id`.

Candidate active-turn events:

- `turn_started`: turn id, thread id, started timestamp, selected model controls
- `assistant_delta`: turn id and text delta
- `item_updated`: normalized tool/event item summary
- `turn_completed`: turn id, status, event count, optional assistant text
- `error`: turn id and message

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

Additional iPad-send diagnosis smoke:

- LAN Companion endpoint: `http://192.168.4.16:3765`
- Direct synchronous POST returned `CRAFTINGTABLE_IPAD_SEND_DIAG_OK` after about 20 seconds.
- Local async POST to `http://127.0.0.1:3769` with `wait_for_completion: false` returned `status: started` in about 2.3 seconds.
- A follow-up `GET /threads/019ddd34-e1aa-7600-a7c8-179a67b56908` showed `CRAFTINGTABLE_ASYNC_SEND_OK` and completed turn `019de7a7-66a5-7b12-a459-df78c2ed0b14`.
- Updated LAN Companion on `http://192.168.4.16:3765` returned `status: started` in about 2.2 seconds for async turn `019de7ac-5e0f-71b1-b7dd-b9219bce3876`.
- Follow-up thread detail on the same LAN endpoint showed `CRAFTINGTABLE_LAN_ASYNC_SEND_OK` and completed status for that turn.
- Slice 11 local Companion smoke on `127.0.0.1:3769` showed `/threads?limit=3` returning project metadata for `workbench` and `Beluna`.

## Next Cut

Add live event projection for active turns, including status changes, assistant deltas, approval requests, user-input requests, and errors.
