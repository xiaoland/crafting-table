# Thread Page Findings

## Purpose

This note records the first iPad-side Thread Page slice for standalone Codex Remote. It keeps UI and client findings separate from Companion protocol and Desktop Scout findings.

## Product Shape

The Codex Remote screen now uses a thread-first structure:

- left sidebar: Companion endpoint, host health, desktop handoff status, and Codex thread list
- right page: selected thread header, message history, and bottom composer
- model picker: populated from Companion `GET /models`
- message submission: `POST /threads/{thread_id}/turns` with optional `model` and nonblocking completion wait

The screen remains standalone. It has no Goal Forest, Work Session, or Remote Control dependency.

## Next UX Direction

The next Thread Page slice combines remote profiles and project-thread navigation.

Remote profiles:

- The sidebar should start with a compact host switcher instead of a single endpoint field.
- Each host profile stores endpoint, label, last health status, and last-used time locally on iPad.
- Selecting a host swaps the active health, desktop snapshot, model list, thread list, selected thread, composer state, and error state together.
- Direct endpoint editing remains available for MVP setup.

Project threads:

- Thread navigation should group by project, using Companion-provided `project_key` and `project_name`.
- Project sections sort by newest contained thread.
- Thread rows keep title, updated time, and id, with project-level counts replacing one global flat count.
- `Unknown Project` is the fallback group for threads whose cwd is missing or unusable.

Thread rendering:

- Move transcript presentation from chat bubbles toward Codex App-style blocks.
- Assistant content should support markdown-like text rendering.
- Tool and event rows should keep compact default state with disclosure for command output, file changes, web search, and other item kinds.
- Streaming deltas should append into the active assistant block, then reconcile from `GET /threads/{thread_id}` after completion.

Composer controls:

- Keep model selection in the bottom composer.
- Add reasoning effort once Companion exposes supported reasoning levels for the selected model.
- Add Fast as a model-dependent toggle when the selected model advertises a fast speed tier.

## Client Contract Usage

CraftingTable now calls:

- `GET /health`
- `GET /threads?limit=20`
- `GET /threads/{thread_id}`
- `GET /models`
- `GET /desktop/snapshot`
- `POST /threads/{thread_id}/turns`

Model list loading is a non-critical companion call in the iPad client. If `GET /models` fails, the page keeps host health and thread listing available, then shows an unavailable model picker state.

Thread submission uses `wait_for_completion: false` from the iPad client. The UI treats the immediate response as a started turn, reloads the selected thread detail, then schedules short follow-up refreshes so completed assistant output appears without holding the composer request open.

## iPad Send Diagnosis

Reported symptom: thread turns and model list loaded from the iPad, but sending a message appeared to fail.

Observed evidence:

- `GET /health`, `GET /threads?limit=1`, and `GET /models` against `http://192.168.4.16:3765` all succeeded.
- Direct LAN `POST /threads/019ddd34-e1aa-7600-a7c8-179a67b56908/turns` with `gpt-5.5` succeeded and returned `CRAFTINGTABLE_IPAD_SEND_DIAG_OK`.
- The direct POST took about 20 seconds because Companion waited for full Codex turn completion before returning.
- Physical iPad build succeeded with device destination `00008132-000245583AD1401C`.
- After the async fix, updated LAN Companion on `http://192.168.4.16:3765` returned `status: started` in about 2.2 seconds, then thread detail showed completed turn `019de7ac-5e0f-71b1-b7dd-b9219bce3876` with `CRAFTINGTABLE_LAN_ASYNC_SEND_OK`.

Conclusion: the iPad transport and Companion turn route were reachable. The fragile point was the synchronous wait inside the submit request, which made a normal Codex response latency look like a failed send path on-device.

Implemented fix:

- Companion accepts optional `wait_for_completion`.
- CraftingTable sends `wait_for_completion: false`.
- Companion returns `status: started` immediately and waits for turn completion in a background task.
- CraftingTable reloads the selected thread detail immediately and again after short delays.

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
