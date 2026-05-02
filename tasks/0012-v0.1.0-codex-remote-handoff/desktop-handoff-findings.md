# Desktop Handoff Findings

## Purpose

This note records the first Companion-owned Desktop Scout route for Codex Remote hot handoff. It keeps desktop reconciliation evidence separate from semantic app-server findings.

## Companion Route

CraftingTable calls:

- `GET /desktop/snapshot`

The Companion runs the local platform scout:

- macOS: `CODEX_MACOS_SCOUT_BIN` when set, otherwise `Companion/scouts/macos/.build/debug/codex-macos-scout`, otherwise `swift run --package-path Companion/scouts/macos codex-macos-scout`
- Windows: `CODEX_WINDOWS_SCOUT_BIN` when set, otherwise `Companion/scouts/windows/bin/Debug/net8.0-windows/CodexWindowsScout.exe`

The route returns HTTP `503` with a small `{ "error": "..." }` payload when the platform scout fails or times out.

## Normalized Snapshot Contract

The route returns a normalized response for CraftingTable:

```json
{
  "platform": "macos",
  "source": "macos-swift-scout",
  "target_app_name": "Codex",
  "confidence": "medium",
  "window_count": 3,
  "active_window_title": "Codex",
  "errors": [],
  "raw": {}
}
```

The `raw` field preserves the scout-native JSON for diagnostics. CraftingTable currently reads the normalized fields only.

## Smoke Evidence

Commands run from `/Users/lanzhijiang/Development/workbench`:

- `cargo run --manifest-path Companion/Cargo.toml`
- `curl -fsS http://127.0.0.1:3765/desktop/snapshot`
- `curl -fsS http://127.0.0.1:3765/health`

Observed desktop snapshot:

```json
{
  "platform": "macos",
  "source": "macos-swift-scout",
  "target_app_name": "Codex",
  "confidence": "medium",
  "window_count": 3,
  "active_window_title": "Codex",
  "errors": []
}
```

Observed health still reports scout configuration as platform availability, with live scout execution owned by `/desktop/snapshot`.

## CraftingTable Surface

`CodexRemoteScreen` now includes compact Desktop Handoff status in the sidebar and selected thread header showing:

- scout confidence
- detected window count
- platform
- scout source
- target app
- active window title
- scout errors

Desktop snapshot loading is separate from health and thread loading. A desktop scout failure is shown inside the Desktop Handoff panel while the rest of Codex Remote can still load semantic state.

## Current Interpretation

The first hot-handoff UI is a confidence surface. It gives CraftingTable enough host-visible desktop evidence to avoid silently claiming semantic continuity. The next useful step is to combine this evidence with app-server thread metadata and guide manual selection or semantic resume.
