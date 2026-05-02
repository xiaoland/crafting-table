---
name: codex-remote-companion
description: Start or smoke-test the Codex Remote Companion and macOS Desktop Scout for CraftingTable. Use when asked to launch Companion, run macOS Scout, expose the Companion to iPad over LAN, or verify Codex Remote host readiness.
---

# Codex Remote Companion

Use this skill for local Codex Remote host operations in `/Users/lanzhijiang/Development/workbench`.

## Commands

Run from the repository root:

```sh
./scripts/codex-remote-companion.sh companion
```

Use this for local-only Companion startup. It binds to `127.0.0.1:3765` unless `CODEX_REMOTE_BIND` is set.

```sh
./scripts/codex-remote-companion.sh companion-lan
```

Use this when CraftingTable on iPad should connect over LAN. It binds to `0.0.0.0:3765` unless `CODEX_REMOTE_BIND` is set.

```sh
./scripts/codex-remote-companion.sh scout
```

Use this for a single macOS Desktop Scout JSON snapshot.

```sh
./scripts/codex-remote-companion.sh smoke
```

Use this after Companion is running. It probes `/health`, `/desktop/snapshot`, and `/threads?limit=5`.

## Operating Notes

- Companion runs in the foreground and owns macOS Scout launch through `GET /desktop/snapshot`.
- macOS Accessibility permission belongs to the terminal or app process that launches the scout.
- For LAN startup, tell the user the Mac IP printed by the script and the endpoint shape `http://<mac-lan-ip>:3765`.
- If Companion is already listening on port `3765`, surface the port conflict and ask whether to stop the existing process or use another `CODEX_REMOTE_BIND`.
