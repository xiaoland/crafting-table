# Task 0017 - Android Codex Remote parity

## Objective & Hypothesis

Bring the Android Client Codex Remote surface up to the current iPad Client baseline without expanding the product boundary beyond standalone Codex thread continuation.

Hypothesis: Android can reach useful parity by reusing the CTCore Codex Remote client contract and porting the iPad runtime shape into idiomatic Kotlin/Compose slices: saved host profiles, per-host runtime state, project-grouped ThreadList, ThreadDetail, thread creation, model/reasoning/Fast/permission composer controls, active-turn streaming, and resilient refresh behavior.

## Input Type

Intent.

The requested product behavior changes Android Client capability and should stay aligned with Claim 7, Workflow 7, and the Codex Remote boundary rules before implementation starts.

## Active Mode

Execute.

The high-level slice plan was confirmed, implementation started after explicit user approval, and this packet now records the execution state and verification evidence.

## Governing Anchors

- `docs/00-meta/input-intent.md`
- `docs/00-meta/mode-a-explore.md`
- `docs/10-prd/behavior/claims.md` - Claim 7, `Codex Remote` is a standalone Codex thread surface.
- `docs/10-prd/behavior/workflows.md` - Workflow 7, continue Codex from iPad.
- `docs/10-prd/behavior/rules-and-invariants.md` - Codex Remote remains separate from Remote Control, Goal Forest, and Work Session.
- `docs/20-product-tdd/cross-unit-contracts.md` - CTCore Codex Remote Server exposes health, project-grouped threads, thread detail, thread creation, model list, turn submission, and active-turn stream events.
- `clients/android/README.md`
- `clients/apple/iPad/Features/CodexRemote/`
- `clients/android/app/src/main/java/com/xiaoland/craftingtable/android/`

## Guardrails Touched

- Keep Android scope to Codex Remote control client; do not add Android Host Runtime, Goal Forest, Capture, Work Session, Local LLM, pairing/auth, or LAN discovery in this parity task.
- Treat iPad as the current product baseline, but do not copy SwiftUI architecture mechanically where Android has a clearer Compose shape.
- Keep CTCore as the owner of Codex Remote protocol normalization; Android UI should not learn raw codex-app server JSON.
- Keep host profiles workspace-scoped/reusable. Android storage can be platform-local for now, but the product meaning must match iPad saved hosts.
- Preserve security language and defaults: permission mode defaults to `sandbox`; `auto_review` and `full_access` are explicit per-turn choices.
- Keep generated UniFFI source policy honest; if Android bindings are stale, regenerate or update the integration rather than hand-rolling missing protocol pieces.

## Current Evidence

- Android current scope from `clients/android/README.md`: manual host URL, `/health`, thread list, thread detail transcript, synchronous turn submission with `wait_for_completion=true`, CTCore-backed response decoding, and checked-in UniFFI bindings.
- Android current code is concentrated in `MainActivity.kt` and `CodexRemoteApi.kt`; it keeps UI state inside one composable and manually calls HTTP routes with OkHttp.
- Android checked-in UniFFI source currently exposes decode helpers and older flat transcript rows, but does not expose the newer `FfiCodexRemoteClient`, snapshot/model list/create thread/follow turn, or typed transcript entry models that iPad uses.
- iPad current Codex Remote state is per-host: saved profiles, selected host, per-host runtime, selected thread, selected model/reasoning/Fast/permission, thread detail, turn result, and active stream state.
- iPad currently loads a CTCore snapshot containing health, thread list, and model list; groups threads by project; can create a thread under a project cwd; submits turns without waiting for completion; then follows active-turn events with stream/poll recovery.

## Exploration Notes - 2026-05-31

### iPad Baseline

- Multi-host support is product-visible, not just an implementation detail: host profiles include label, endpoint, last health status, and last used time, persisted through `@AppStorage`.
- Per-host runtime state is isolated in memory. Health, thread list, model list, selected thread, composer controls, thread detail, and streaming state do not leak across hosts.
- Refresh uses CTCore `FfiCodexRemoteClient.loadSnapshot`, which loads health, thread list, and model list behind the shared Codex Remote client contract.
- Thread list is grouped by effective project key/name and sorted by recency; skipped records are visible.
- Thread creation is project-scoped and requires a project cwd. The request carries optional model and `serviceTier = "fast"`.
- Composer controls are model-driven: selected model, supported reasoning efforts, Fast availability, and permission mode.
- Permission mode has stable user-facing values: `sandbox`, `auto_review`, `full_access`; default is `sandbox`.
- Turn submission does not wait for completion. The UI starts active-turn streaming, merges streaming rows with persisted transcript rows, and reconciles state after thread detail catches up.
- Streaming recovery is shared through CTCore reconnect/poll fallback, with iPad-side active-turn discovery when a loaded detail reports `activeTurn.status == "inProgress"`.
- Transcript rendering uses typed entries: conversation messages, tool-call messages, and generic events. iPad adds rich Markdown/code/Mermaid rendering and tool-call detail affordances.

### Android Baseline

- Android currently has a single-screen, single-endpoint client with `rememberSaveable` host URL and one shared UI state.
- `CodexRemoteApi.kt` manually calls `/health`, `/threads`, `/threads/{id}`, and `POST /threads/{id}/turns`.
- Turn submission is synchronous and fixed to `wait_for_completion = true`.
- Android maps thread detail to flat rows with `id`, `role`, `text`, and `status`.
- There is no saved host profile list, no per-host runtime state, no model list, no thread creation, no composer control parity, no active-turn streaming, and no typed transcript rendering.
- The highest-risk gap is binding drift: CTCore source exposes `FfiCodexRemoteClient`, but the checked-in Android UniFFI Kotlin file does not. Android parity work that assumes those generated symbols exist will fail to compile.

### Working Direction

- First solve binding/contract readiness, then build Android state and UI on the shared CTCore client contract.
- Do not fill missing Android features by extending the current hand-written OkHttp facade unless the binding path is proven blocked.
- Keep module structure shallow: no new Gradle module is needed yet; split by package/files inside `:app` when implementation starts.
- Favor a thin app-side CTCore facade so generated UniFFI types do not leak through the Compose UI.
- Include Markdown/code/Mermaid rich rendering in this parity task. It can be sequenced after typed transcript support, but it is not out of scope.
- Do not use CTCore portable config for Android host profile persistence in this task.

## Temporary Assumptions

- "Same effect as iPad Client" means product-behavior parity for Codex Remote, not visual pixel parity and not all iPad-only rendering polish in the first Android slice.
- Android should prefer a small ViewModel/state-holder split before UI expansion; keeping all parity state inside `MainActivity.kt` would become hard to maintain.
- Android persistence should use simple platform-local storage for this task; adding a database or portable config is premature.
- Rich transcript rendering should be included, but sequenced after the typed transcript model is available.

## Implementation Plan

### Phase 0 - Binding Gate

Goal: make Android compile against the same CTCore Codex Remote client contract that iPad uses.

- Regenerate or repair Android UniFFI bindings so checked-in Kotlin exposes `FfiCodexRemoteClient`, snapshot/model list/thread create/turn submit/follow turn/recover active turn, typed transcript entries, tool-call payloads, and stream status/event types.
- Verify generated Kotlin source and native library expectations without committing ignored `.so` artifacts.
- Add a thin app-side facade around UniFFI so Compose code does not depend directly on generated types.
- Keep the old hand-written `CodexRemoteApi` only as a temporary migration reference, then remove or retire it once the CTCore facade owns all calls.

Verification:

- `cargo test --manifest-path CTCore/Cargo.toml --features kotlin-bindings`
- `scripts/build-ctcore-android.sh`
- `scripts/run-android-client.sh --check`

### Phase 1 - Android State Shape

Goal: create a maintainable Android runtime shape before expanding UI behavior.

- Split current `MainActivity.kt` into small feature files under the existing app module/package.
- Introduce host profile models: `id`, `label`, `endpoint`, `lastHealthStatus`, `lastUsedAt`.
- Persist host profiles and selected host in Android-local storage, not portable config.
- Introduce per-host runtime state mirroring product meaning from iPad: health, thread list, model list, selected thread, selected model, selected reasoning effort, Fast toggle, selected permission mode, thread detail, composer input, turn result, and streaming state.
- Preserve selected host/thread/model where valid after refresh.

Verification:

- App launches with a default `Local Mac` profile.
- Add/select/delete host works.
- Relaunch preserves host profiles and selected host.
- Switching hosts does not mix thread/model/composer/stream state.

### Phase 2 - Snapshot And ThreadList

Goal: replace manual health/thread loading with CTCore snapshot and show iPad-equivalent host/thread orientation.

- Load host snapshot through CTCore: health, thread list, model list.
- Display host status, platform, Codex availability, Codex home, skipped records, and refresh error state.
- Group ThreadList by effective project key/name and sort by recency.
- Show project headers with cwd when available and thread rows with title, status/active turn, updated time, and selected-thread affordance.
- Select first valid thread after refresh when no current selection survives.

Verification:

- Refresh loads health + models + grouped threads from a reachable server.
- Unreachable host keeps visible error state and does not corrupt previous valid host state.

### Phase 3 - ThreadDetail And Typed Transcript

Goal: make Android consume the same transcript semantics as iPad before adding rich rendering.

- Load thread detail through CTCore facade.
- Map typed transcript entries into Android UI models: user message, assistant message, tool-call message, generic event.
- Render conversation rows, grouped tool-call rows, and generic event rows.
- Keep persisted transcript as final truth; streaming rows remain transient overlay state.
- Move thread metadata out of the message flow where possible, matching iPad's current space priority.

Verification:

- Existing threads display user/assistant/tool/event entries without flattening everything into plain text.
- Tool-call groups are readable and details are accessible/copyable.

### Phase 4 - Rich Rendering

Goal: include Android equivalents for iPad Markdown/code/Mermaid readability.

- Add Markdown rendering for message text with selectable/copyable text where Compose reasonably supports it.
- Add fenced code block detection and rendering with language label and copy affordance.
- Add Mermaid rendering for Mermaid code fences, likely through an Android WebView-backed renderer using a bundled `mermaid.min.js` asset or a shared local asset copied from the iPad resource after license/check suitability is verified.
- Keep graceful fallback: if Markdown/code/Mermaid parsing or rendering fails, show readable source text/code rather than blank content.
- Avoid overbuilding syntax highlighting unless a lightweight Android-native option is already available or very cheap to add.

Verification:

- Manual transcript samples cover plain Markdown, fenced code, Mermaid success, and Mermaid fallback.
- Long code blocks and diagrams do not break mobile layout.

### Phase 5 - Composer Controls

Goal: bring turn submission controls to iPad product parity.

- Model picker is driven by CTCore model list, not hardcoded.
- Reasoning effort picker appears only when the selected model supports efforts.
- Fast toggle appears only when selected model supports `fast`; request maps to `serviceTier = "fast"`.
- Permission picker exposes `sandbox`, `auto_review`, `full_access`, defaulting to `sandbox`.
- Changing model reconciles reasoning and Fast state.
- Submit validates selected thread and non-empty input.

Verification:

- Submissions carry selected model/reasoning/Fast/permission parameters through CTCore.
- Unsupported reasoning/Fast selections are cleared when model changes.

### Phase 6 - Thread Creation

Goal: support project-scoped new thread creation like iPad.

- Add create-thread action on project groups with available cwd.
- Request includes cwd and optional model/service tier.
- Insert locally created thread into the list immediately enough to preserve user orientation, then refresh snapshot/detail.
- Select the created thread and prepare composer/detail state.

Verification:

- Creating a thread under a project selects it and keeps it visible after refresh.
- Groups without cwd disable creation with clear UI state.

### Phase 7 - Active Turn Streaming And Recovery

Goal: replace synchronous turn wait with live Codex progress.

- Submit turns with `waitForCompletion = false`.
- Start `followTurn` through CTCore after submission.
- Handle stream status and events: `turn_started`, `assistant_delta`, `item_updated`, `turn_completed`, `error`.
- Use sequence numbers to avoid duplicate event application.
- Render streaming assistant/tool/event rows before final persisted thread detail catches up.
- Apply polled thread detail from CTCore fallback and reconcile transient stream state when persisted transcript covers it.
- On loading a thread detail with in-progress active turn, recover/follow the active turn.
- Preserve existing thread detail on transient refresh failure instead of blanking the page.

Verification:

- Live assistant/tool progress appears before final completion.
- Stream interruption recovers through CTCore fallback or leaves a visible stream error without losing transcript state.
- Completed turns settle into persisted transcript rows.

### Phase 8 - Final Parity Pass

Goal: close behavior gaps and produce a repeatable smoke path.

- Review Android UI density and ergonomics for phone/tablet without chasing iPad pixel parity.
- Remove obsolete hand-written API paths after CTCore facade owns behavior.
- Update Android README if build/run or scope changes materially.
- Add focused tests where feasible for pure Kotlin mapping/grouping/persistence logic.
- Run build and available device smoke.

Verification:

- `scripts/run-android-client.sh --check`
- `scripts/run-android-client.sh --build`
- `scripts/run-android-client.sh --debug` if a device/emulator is available.
- Manual parity smoke:
  - add/select two hosts and relaunch;
  - refresh host snapshot;
  - inspect project-grouped ThreadList;
  - open ThreadDetail with typed transcript and rich Markdown/code/Mermaid content;
  - create thread under project;
  - submit with model/reasoning/Fast/permission controls;
  - observe active streaming and final reconciliation.

## Candidate Slices

1. Binding and contract readiness: regenerate/verify Android UniFFI bindings expose CTCore `FfiCodexRemoteClient`, snapshot/model list/thread create/follow turn/recover active turn, and typed transcript entries.
2. State and persistence foundation: introduce Android host profile storage, selected host persistence, and per-host runtime state outside the root composable.
3. Snapshot and ThreadList parity: load health + model list + project-grouped threads through CTCore, preserve selected thread/model, show host status and project groups.
4. ThreadDetail and typed transcript parity: render typed transcript entries with conversation/tool/event separation.
5. Markdown/code/Mermaid rich rendering parity.
6. Composer controls parity: model picker, reasoning picker, Fast toggle, permission mode picker, and request payload mapping through CTCore.
7. Thread creation: create a thread under a project cwd and merge/preserve locally created threads during refresh.
8. Active-turn streaming and recovery: submit without `wait_for_completion`, follow turn events, show live assistant/tool rows, recover via polling/follow on active turns, and avoid blanking detail on transient refresh errors.
9. Verification and polish: Android build/smoke checks, state restoration checks, unreachable-host checks, and a short manual parity script.

## Open Questions

- Is the current machine expected to have Android NDK and either an emulator or authorized USB device, or should verification target Gradle/build-only until device access is confirmed?
- If regenerated Android bindings produce broad checked-in churn, should that be accepted inside this parity task or split into a separate binding-sync commit?

## Verification

- `scripts/build-ctcore-android.sh`
- `cd clients/android && ./gradlew :app:assembleDebug`
- `scripts/run-android-client.sh --debug` when an authorized Android device is available.
- Manual smoke against a reachable Codex Remote Server:
  - add/select two hosts and relaunch to confirm persistence;
  - refresh host snapshot and verify model list plus project-grouped threads;
  - open a thread with Markdown, code, and Mermaid content and verify rich rendering or graceful fallback;
  - create a thread under a project group;
  - submit turns with default `sandbox`, then `auto_review` or `full_access`;
  - confirm active stream rows appear before final refresh;
  - switch hosts and return without losing per-host selected thread/runtime state.

## Promotion Candidates

- If Android host profile storage proves reusable, promote the durable local-storage/profile boundary to Product TDD without admitting portable config in this task.
- If Android parity changes the product definition of Codex Remote beyond iPad behavior, update PRD Claim 7 / Workflow 7 before implementation.

## Implementation Notes - 2026-05-31

- Android UniFFI binding was regenerated and now exposes CTCore `FfiCodexRemoteClient`, snapshot/model list/thread create/turn submit/follow turn/recover active turn, typed transcript entries, tool-call payloads, and stream events.
- `scripts/build-ctcore-android.sh` now exports target-specific `CC_*`, `CXX_*`, and `AR_*` variables so native Rust dependencies such as `ring` use the Android NDK toolchain instead of looking for legacy target-prefixed tools.
- Android app code now uses a CTCore-backed facade instead of the old hand-written OkHttp route client. The old `CodexRemoteApi.kt` was removed.
- Host profiles are persisted through Android-local `SharedPreferences` JSON, not portable config.
- Runtime state is per host: snapshot, thread list, model list, selected thread/model/reasoning/Fast/permission, thread detail, composer input, turn result, and streaming state.
- ThreadList is project-grouped and supports project-scoped thread creation.
- ThreadDetail uses typed transcript entries with conversation rows, generic event rows, grouped tool-call rows, and copyable tool details.
- Rich rendering is included: fenced Markdown text blocks, code blocks with copy affordance, and Mermaid blocks rendered through a local Android WebView asset with source fallback.
- Turn submission now uses `waitForCompletion = false` and follows active turns through CTCore streaming/recovery callbacks.
- Follow-up review fix: async refresh/detail/create/submit continuations now use host-bound `hostId` and `endpoint` instead of re-reading the currently selected host, preserving per-host runtime isolation when the user switches hosts during in-flight requests.
- Follow-up review fix: Markdown rendering now handles common block/inline Markdown shapes directly in Compose, including headings, lists, block quotes, bold, italic, inline code, and link styling. Code fences and Mermaid fences remain separate rich blocks.
- Follow-up IA change: Android Codex Remote now uses two explicit pages. The Host + ThreadList page owns host configuration, snapshot status, project groups, and thread selection; selecting a thread opens the Thread Detail page, which owns transcript, composer controls, turn submission, and streaming state.
- Follow-up ThreadDetail behavior: the transcript list now keeps a stable lazy-list state and automatically scrolls to the newest/bottom item after thread detail loads, when transcript rows change, and while active streaming text advances.
- Follow-up composer density change: Model, Reasoning, and Fast controls are now aggregated behind one picker. The picker keeps Reasoning choices on the first level while Model and Fast On/Off use internal picker pages. The send action is now icon-only.
- Follow-up navigation correction: the previous two-page IA was an in-composition state switch, not an Android route. Android now depends on Navigation Compose and uses a `NavHost` with `host_threads` and `thread_detail` destinations, so ThreadDetail participates in the normal navigation back stack.
- Follow-up transcript density change: tool-call transcript rows are now compact surface-container cards without accent coloring. Tool-call details no longer expand in place; tapping the card opens a modal bottom sheet with summary and copyable detail text.
- Follow-up composer label change: the aggregated Model/Reasoning/Fast picker label now shows only Model and Reasoning by default. Fast is shown only when enabled, using a lightning icon instead of text.
- Follow-up stream reconciliation fix: turn-completed reconciliation no longer requires streaming item ids to match persisted transcript ids before clearing the streaming overlay. This avoids duplicate final messages when the server rewrites item ids during persistence. The UI merge remains mechanical and only filters streaming rows by exact persisted ids; it does not guess semantic equivalence.
- Follow-up thread ownership fix: Android has a UI runtime state holder, but not a persisted transcript store. Thread detail writes are now strictly thread-bound: stale detail loads are ignored when selection changes, mismatched `ThreadDetailResponse.thread.id` values are rejected, stream-polled details must match the active selected thread, and streamed transcript entries must belong to the active turn before entering `streamingMessages`.

Verification run:

- Passed: `./scripts/build-ctcore-android.sh`
- Passed: `./scripts/run-android-client.sh --build`
- Passed: `./scripts/run-android-client.sh --check`
- Passed after removing the old API path: `./scripts/run-android-client.sh --build`
- Passed after review fixes: `./scripts/run-android-client.sh --build`
- Passed after review fixes: `./scripts/run-android-client.sh --check`
- Passed after two-page IA change: `./scripts/run-android-client.sh --build`
- Passed after two-page IA change: `./scripts/run-android-client.sh --check`
- Passed after ThreadDetail auto-scroll change: `./scripts/run-android-client.sh --build`
- Passed after ThreadDetail auto-scroll change: `./scripts/run-android-client.sh --check`
- Passed after composer density change: `./scripts/run-android-client.sh --build`
- Passed after composer density change: `./scripts/run-android-client.sh --check`
- Passed after Navigation Compose route change: `./scripts/run-android-client.sh --build`
- Passed after Navigation Compose route change: `./scripts/run-android-client.sh --check`
- Passed after Navigation Compose route change: `./scripts/run-android-client.sh --debug` on connected device `b45097d7`; install succeeded, `MainActivity` launched, app process existed, and the activity was resumed/focused.
- Passed after tool-call compact-card change: `./scripts/run-android-client.sh --build`
- Passed after tool-call compact-card change: `./scripts/run-android-client.sh --check`
- Passed after tool-call compact-card change: `./scripts/run-android-client.sh --debug` on connected device `b45097d7`; install succeeded, `MainActivity` launched, app process existed, and the activity was resumed/focused.
- Passed after composer label change: `./scripts/run-android-client.sh --build`
- Passed after composer label change: `./scripts/run-android-client.sh --check`
- Passed after composer label change: `./scripts/run-android-client.sh --debug` on connected device `b45097d7`; install succeeded, `MainActivity` launched, app process existed, and the activity was resumed/focused.
- Passed after stream reconciliation fix: `./scripts/run-android-client.sh --build`
- Passed after stream reconciliation fix: `./scripts/run-android-client.sh --check`
- Passed after stream reconciliation fix: `./scripts/run-android-client.sh --debug` on connected device `b45097d7`; install succeeded, `MainActivity` launched, app process existed, and the activity was resumed/focused.
- Passed after removing UI semantic dedupe: `./scripts/run-android-client.sh --build`
- Passed after removing UI semantic dedupe: `./scripts/run-android-client.sh --check`
- Passed after thread ownership fix: `./scripts/run-android-client.sh --build`
- Passed after thread ownership fix: `./scripts/run-android-client.sh --check`
- Passed after thread ownership fix: `./scripts/run-android-client.sh --debug` on connected device `b45097d7`; install succeeded, `MainActivity` launched, app process existed, and the activity was resumed/focused.
