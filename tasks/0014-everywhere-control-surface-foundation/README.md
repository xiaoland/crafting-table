# Task 0014 - Everywhere control surface foundation

## Status
Exploring

## Date
2026-05-27

## Last Revised
2026-05-28

## MVT Core

- Objective & Hypothesis: re-evaluate Crafting Table's move from an iPad-first foundation toward a personal everywhere productivity busybox / control surface using current repo evidence and the user's concrete multi-client direction; the expected result is a grounded boundary plan, not a generic multi-platform architecture.
- Guardrails Touched: keep the new positioning volatile until durable PRD language is explicit; do not design Crafting Table-owned sync for Goal Forest or Capture because those are expected to move toward InKCre; preserve Codex Remote's host/control split; keep Local LLM local-first and platform-lifecycle honest; do not move code or rename units before the target boundaries are confirmed.
- Verification: produce evidence-backed notes that map current state authority, InKCre integration pressure, Codex Remote server/client roles, desktop resident runtime needs, iPad Local LLM background limits, config-file portability, and repo structure options.

## Classification

- Input Type: Intent + Constraint + Artifact
- Active Mode: Explore
- Governing Anchors: `AGENTS.md`, `docs/00-meta/input-intent.md`, `docs/00-meta/input-constraint.md`, `docs/00-meta/input-artifact.md`, `docs/00-meta/mode-a-explore.md`, `tasks/README.md`, `docs/10-prd/index.md`, `docs/10-prd/glossary.md`, `docs/20-product-tdd/system-state-and-authority.md`, `docs/20-product-tdd/cross-unit-contracts.md`, `/Users/lanzhijiang/Development/InKCre/core-py/README.md`, `/Users/lanzhijiang/Development/InKCre/core-py/docs/30-unit-tdd/business-pipeline-and-authority.md`

## Purpose

This packet captures the exploration needed before Crafting Table can be reshaped for multiple clients.

The first packet draft was too generic. It treated multi-client work as a broad sync and architecture problem before checking the actual repo and the user's plan. This revision narrows the packet around current evidence:

- Crafting Table currently stores Goal Forest, captures, sessions, host profiles, and remote continuity in a local `WorkspaceDocument`.
- InKCre core-py is a FastAPI / SQLModel / PostgreSQL info-base backend whose durable graph state is blocks and relations.
- Codex Remote currently uses an independent Rust Companion process as the host-side adapter behind a CraftingTable-owned HTTP/WebSocket contract.
- Local LLM is a local model manifest, cache, foreground HTTP server, bearer token, and runtime boundary.

This packet should remain a staging area for boundary clarification. It is not a PRD replacement and should not become a large migration plan before the boundaries are reviewed.

## User Direction Captured

- Goal Forest and Capture do not need Crafting Table-owned multi-device sync because they are expected to move toward InKCre.
- Other configuration such as Remote SSH and Codex can use a file that the user syncs through Nextcloud, iCloud, or an equivalent filesystem sync tool.
- Local LLM does not need cross-device data sync.
- Client capabilities are not required to be equivalent across platforms.
- For Codex Remote, Windows and macOS are controlled endpoints that run the Codex Companion Server / Host Runtime.
- For Codex Remote, iPadOS and Android are control endpoints that run the Companion Client and UI.
- Codex Companion should be merged into the Crafting Table / CT client experience rather than remain a separately managed process, while code may remain separated as maintainable units.
- Desktop clients should support login launch and background residency to serve Codex Remote.
- The iPad client should pursue the closest practical equivalent for Local LLM Service reliability under iPadOS lifecycle constraints.
- The most important implementation direction may be a cross-platform backend library that owns business capabilities and is compiled with only the needed feature set, while platform clients provide adapters for OS-specific capabilities such as storage, camera, credentials, background lifecycle, and platform UI.
- Backend library features are not all equivalent. For example, Codex Remote Control Server and Codex Remote Control Client should be separate compile-time features because they have different capabilities, authorities, and platform requirements.

## Current Evidence

### Crafting Table Workspace State

Current local workspace state is a versioned Codable JSON document under app support scope.

Evidence:

- `CraftingTable/Features/Shared/WorkspaceModels.swift` defines `WorkspaceDocument` with `goalNodes`, `goalEdges`, `sessions`, `captures`, `hosts`, and `remoteContinuityRecords`.
- `CraftingTable/Features/Shared/WorkspaceStore.swift` persists that document to `workspace-v0.json`.

Implication:

- This local JSON document is an early `0.1.0` persistence boundary, not an appropriate long-term multi-client sync authority for Goal Forest or Capture if those move to InKCre.

### InKCre Direction

InKCre core-py is not a Crafting Table sync helper. It is a backend whose product center is an info-base graph.

Evidence:

- `/Users/lanzhijiang/Development/InKCre/core-py/README.md` describes FastAPI, SQLModel, APScheduler, and PostgreSQL.
- `/Users/lanzhijiang/Development/InKCre/core-py/app/schemas/info_base/block.py` defines `BlockModel`.
- `/Users/lanzhijiang/Development/InKCre/core-py/app/schemas/info_base/relation.py` defines `RelationModel`.
- `/Users/lanzhijiang/Development/InKCre/core-py/docs/30-unit-tdd/business-pipeline-and-authority.md` says info-base owns graph persistence while sources and extensions propose graph data.

Implication:

- Goal Forest / Capture exploration should become a mapping problem: Crafting Table concept -> InKCre block resolver -> relation content -> API path -> unresolved semantics.
- Do not plan CRDT, local-first merge, or Crafting Table-owned cloud sync for those objects until InKCre's role is rejected or materially changed.

### Codex Remote Direction

Current Companion is a standalone Rust host-side service, but the durable boundary is more important than the current process shape.

Evidence:

- `Companion/src/main.rs` starts an axum server.
- `Companion/src/routes.rs` exposes `GET /health`, thread routes, model routes, desktop snapshot, turn submission, and turn event WebSocket routes.
- `CraftingTable/Features/CodexRemote/CodexRemoteClient.swift` talks to a Companion endpoint instead of Codex app-server directly.
- `docs/20-product-tdd/cross-unit-contracts.md` keeps Codex app-server protocol churn behind Companion.

Implication:

- macOS and Windows CT clients should eventually include a Codex Remote Control Server / Host Runtime Unit that owns Codex app-server adaptation, Desktop Scout, host-local process details, and the cross-device wire contract.
- iPadOS and Android should remain control clients for this path.
- Merging Companion into desktop clients should remove the separately managed daemon experience, not erase the Companion contract.

### Local LLM Direction

Current Local LLM state is device-local by design.

Evidence:

- `docs/20-product-tdd/system-state-and-authority.md` assigns local model manifest/cache, active model, HTTP server listener state, bearer token, and local chat transcript to Local LLM local owners.
- `CraftingTable/Features/LocalLLM/LocalLLMStore.swift` persists a local manifest and cache path.
- `CraftingTable/Features/LocalLLM/LocalLLMHTTPServer.swift` exposes a bearer-protected local HTTP surface.

Implication:

- Local LLM should not be pulled into cross-device data sync.
- Multi-client planning should instead track which platforms can host, call, or configure local model services.
- iPadOS service reliability needs platform-lifecycle design rather than sync design.

## Platform Role Hypotheses

- macOS: CT client plus Codex Remote Control Server / Host Runtime; supports login launch, background residency, Desktop Scout, Codex app-server adaptation, local configuration, and control UI where useful.
- Windows: CT client plus Codex Remote Control Server / Host Runtime; supports login launch, background residency, Windows UI Automation scout, Codex app-server adaptation, local configuration, and control UI where useful.
- iPadOS: CT control client for Codex Remote Control; Local LLM host where foreground or continued-background execution is practical; InKCre client/projection surface for Goal Forest and Capture.
- Android: CT control client for Codex Remote Control and lightweight InKCre-facing capture/control surface; not expected to host Codex Companion Server in the first direction.

These are hypotheses for technical planning, not durable product commitments.

## Lifecycle Requirements

### Desktop Residency For Codex Remote

Desktop clients should be able to serve Codex Remote without a manually launched terminal process.

Needs to explore:

- login launch behavior on macOS and Windows
- background resident runtime without requiring the main UI window to stay open
- user-visible status, stop/start, and diagnostics
- pairing and authorization for iPadOS / Android control clients
- update/restart behavior without breaking active Codex Remote work unnecessarily
- preserving the existing HTTP/WebSocket contract or replacing it only with an equivalent cross-device contract

### iPad Local LLM Service Reliability

iPadOS cannot be treated like desktop daemon hosting.

Apple's current BackgroundTasks documentation describes `BGContinuedProcessingTask` as a foreground-started task that may continue for minutes or more if the user backgrounds the app. It can use network and CPU, and GPU use requires a Background GPU Access entitlement. The system can still terminate a continuous task under resource pressure, so this is a reliability tool rather than a permanent service guarantee.

Needs to explore:

- foreground server as the baseline user-visible mode
- `BGContinuedProcessingTask` as a continuation path for active generation or active serving sessions
- Live Activity / progress / cancellation implications if continuous background tasks are used
- behavior when the system terminates or suspends the app
- user-facing language that avoids promising desktop-style always-on serving
- whether App Store entitlement and review constraints make background GPU practical

Sources checked:

- Apple Developer Documentation: `BackgroundTasks`
- Apple Developer Documentation: `BGContinuedProcessingTask`
- Apple Developer Documentation: `Performing long-running tasks on iOS and iPadOS`

## Technical Unknowns

- What exact InKCre resolver and relation vocabulary should represent Goal Forest nodes, capture items, sessions, session status, and graph links?
- Should Crafting Table own a thin InKCre client module, an InKCre extension, or both?
- What local state remains in `WorkspaceDocument` after Goal Forest and Capture move toward InKCre?
- Should Remote SSH and Codex endpoint configuration share one portable config file, or remain separate files with a shared config directory?
- What schema and merge discipline keeps user-synced config files safe under iCloud / Nextcloud conflict behavior?
- What is the smallest secure pairing model for control clients talking to desktop Codex Host Runtime?
- How should the current Rust Companion be embedded into desktop clients: sidecar process supervised by the app, static library boundary, local service helper, or retained standalone binary hidden behind app UX?
- What belongs in the cross-platform backend library versus the platform client adapter layer?
- Should portable capabilities such as networking and filesystem access live inside the backend library, or be injected by clients for stricter platform control?
- Which backend library features should be compiled into each platform client?
- What platform stack should desktop CT use before Companion embedding is planned?
- How much of `CraftingTable/Features/CodexRemote/` can be reused by iPadOS and Android, and how much is only contract vocabulary?
- What exact iPadOS background behavior can Local LLM rely on for active generation, active HTTP serving, and idle listening?

## Guardrails

- Do not treat `personal everywhere productivity busybox / control surface` as final naming.
- Do not design Crafting Table-owned sync for Goal Forest / Capture while InKCre is the expected authority path.
- Do not assume feature parity across platforms.
- Do not erase the Companion contract just because the process should be merged into desktop clients.
- Do not describe iPad Local LLM as an always-on background daemon.
- Do not move code solely to make the tree look multi-platform.
- Do not rewrite existing feature packets unless this exploration proves a direct conflict.

## First Exploration Slices

1. Current coupling inventory
   - Inventory `WorkspaceDocument`, `WorkspaceStore`, Goal Forest, Capture, Remote Control, Codex Remote, Companion, and Local LLM.
   - Mark which state is temporary local app state, portable config, InKCre-bound durable graph state, host-owned runtime state, or local-only runtime/cache state.

2. InKCre mapping sketch
   - Map Goal Forest and Capture concepts to InKCre blocks, resolvers, relations, and API routes.
   - Identify missing InKCre concepts without inventing them inside Crafting Table.

3. Codex Host Runtime boundary
   - Separate Companion as a code unit, runtime unit, process, and wire contract.
   - Compare standalone server, app-supervised sidecar, embedded service helper, and library-style integration.
   - Include desktop login launch and background residency requirements.

4. Portable config boundary
   - Define which Remote SSH / Codex settings belong in user-synced files.
   - Identify secrets that must stay in platform credential stores.
   - Define conflict-safe schema and diagnostics.

5. Local LLM lifecycle boundary
   - Keep local model files and manifest local.
   - Explore foreground, continued background, interruption, restart, and user-visible service states on iPadOS.
   - Avoid promising behavior the OS can revoke.

6. Repo structure pressure test
   - Propose only the smallest structural changes that match proven boundaries.
   - Defer large migrations until the target boundary survives review.

## Expected Packet Artifacts

- `current-coupling-inventory.md`: evidence-based inventory of current repo and architecture assumptions.
- `inkcre-goal-capture-mapping.md`: Crafting Table Goal Forest / Capture mapping hypotheses against InKCre block/relation semantics.
- `codex-host-runtime-boundary.md`: Companion process, unit, wire contract, desktop residency, and control-client implications.
- `portable-config-boundary.md`: Remote SSH / Codex config-file shape, filesystem-sync assumptions, and secret handling.
- `local-llm-lifecycle-boundary.md`: iPadOS foreground/background service states, limits, and verification plan.
- `repo-structure-options.md`: minimal repo organization options with tradeoffs and migration risk.
- `implementation-plan.md`: phased implementation sequence and execution evidence.

Create child notes only when they materially help the task.

## Promotion Candidates

- Stable product positioning and platform role language -> `docs/10-prd/`
- InKCre-backed Goal Forest / Capture authority and cross-unit contract -> `docs/20-product-tdd/`
- Codex Host Runtime topology and Companion contract changes -> `docs/20-product-tdd/`
- Portable config file schema and secret boundary -> `docs/20-product-tdd/` or local code-adjacent docs after implementation pressure is real
- iPadOS Local LLM lifecycle guarantees and limits -> `docs/20-product-tdd/` after executable verification
- Mechanically enforced contracts -> code, tests, build settings, smoke checks
- Volatile alternatives, discarded options, and unresolved questions -> keep in this packet

## Open Questions

- Is `personal everywhere productivity busybox / control surface` an internal positioning phrase, product category, or eventual product language?
- Should the first non-iPad CT client be macOS, Windows, or a desktop host runtime without full UI?
- Should Crafting Table integrate with InKCre as a direct REST client, an InKCre extension, or a small dedicated bridge?
- Which local `WorkspaceDocument` fields should survive after Goal Forest / Capture move toward InKCre?
- Should Codex Host Runtime keep the current HTTP/WebSocket contract unchanged for Android/iPad clients?
- On desktop, is an app-supervised sidecar acceptable, or must the host runtime be in-process?
- On iPadOS, what Local LLM service state is product-worthy if background continuation is interruptible?
