# Thread Creation Findings

## Slice Goal

Allow CraftingTable to create a new Codex thread inside an existing project group from Codex Remote.

## Protocol Findings

- App-server `thread/start` accepts `cwd`, `model`, `serviceTier`, and `ephemeral`.
- A zero-turn thread returned by `thread/start` can be read by `thread/read` only after it is materialized with `thread/name/set`.
- `thread/list` still omits the zero-turn thread after creation, even when `thread/read` can load it by id.
- The stable MVP contract is `POST /threads` returning the created thread id and metadata, followed by direct `GET /threads/{id}` for the Thread Page.

## Implementation Notes

- Companion owns `POST /threads`.
- Companion starts a non-ephemeral thread, sets the initial name to `New thread`, then reads the created thread back before responding.
- CraftingTable adds a project-level plus button in the Codex Remote sidebar.
- CraftingTable keeps a local projection of newly created zero-turn threads and merges it into the sidebar list until app-server list catches up after later activity.

## Verification

Commands run from `/Users/lanzhijiang/Development/workbench`:

- `cargo test --manifest-path Companion/Cargo.toml`
- `CODEX_REMOTE_BIND=127.0.0.1:3778 cargo run --manifest-path Companion/Cargo.toml`
- `curl -sS -X POST http://127.0.0.1:3778/threads -H 'content-type: application/json' -d '{"cwd":"/Users/lanzhijiang/Development/workbench","model":"gpt-5.5"}'`
- `curl -sS http://127.0.0.1:3778/threads/019df340-9ce8-7972-9034-cc4c5d897148`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`

Observed create response:

```json
{
  "thread": {
    "id": "019df340-9ce8-7972-9034-cc4c5d897148",
    "title": "New thread",
    "cwd": "/Users/lanzhijiang/Development/workbench",
    "status": "idle"
  },
  "model": "gpt-5.5",
  "model_provider": "openai",
  "service_tier": null
}
```

Observed direct read response:

```json
{
  "thread": {
    "id": "019df340-9ce8-7972-9034-cc4c5d897148",
    "title": "New thread",
    "cwd": "/Users/lanzhijiang/Development/workbench",
    "status": "notLoaded",
    "turn_count": 0
  },
  "messages": []
}
```
