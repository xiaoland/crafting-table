# Thread Page Findings

## Purpose

This note records the first iPad-side Thread Page slice for standalone Codex Remote. It keeps UI and client findings separate from Companion protocol and Desktop Scout findings.

## Product Shape

The Codex Remote screen now uses a thread-first structure:

- left sidebar: Companion endpoint, host health, desktop handoff status, and Codex thread list
- right page: selected thread header, message history, and bottom composer
- model picker: populated from Companion `GET /models`
- message submission: `POST /threads/{thread_id}/turns` with optional `model`

The screen remains standalone. It has no Goal Forest, Work Session, or Remote Control dependency.

## Client Contract Usage

CraftingTable now calls:

- `GET /health`
- `GET /threads?limit=20`
- `GET /threads/{thread_id}`
- `GET /models`
- `GET /desktop/snapshot`
- `POST /threads/{thread_id}/turns`

Model list loading is a non-critical companion call in the iPad client. If `GET /models` fails, the page keeps host health and thread listing available, then shows an unavailable model picker state.

## UI Decisions

- Use local `@State` and `@Binding` in the screen rather than introducing a feature store.
- Keep root state/sidebar in `CodexRemoteScreen.swift` and selected-thread page subviews in `CodexRemoteThreadPage.swift`.
- Use `LazyVStack` for long transcript rendering.
- Use Companion-provided message ids as stable SwiftUI identity.
- Keep Desktop Scout output as compact confidence evidence inside the thread page instead of a separate large panel.
- Keep tool and event messages collapsed by default through `DisclosureGroup`.

## Verification

Commands run from `/Users/lanzhijiang/Development/workbench`:

- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `git diff --check`

Both completed successfully for this slice.
