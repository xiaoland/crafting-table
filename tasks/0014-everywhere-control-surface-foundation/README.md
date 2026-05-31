# Task 0014 - Everywhere control surface foundation

## Status
Executing

## Date
2026-05-27

## Last Revised
2026-05-30

## MVT Core

- Objective & Hypothesis: reshape Crafting Table from an iPad-first foundation toward a personal everywhere productivity busybox / control surface using current repo evidence and the user's concrete multi-client direction; the expected result is a grounded backend/client boundary and incremental implementation, not a generic multi-platform architecture.
- Guardrails Touched: keep the new positioning volatile until durable PRD language is explicit; do not design Crafting Table-owned sync for Goal Forest or Capture because those are expected to move toward InKCre; preserve Codex Remote's host/control split; keep Local LLM local-first and platform-lifecycle honest; do not move code or rename units before the target boundaries are confirmed.
- Verification: produce evidence-backed notes that map current state authority, InKCre integration pressure, Codex Remote server/client roles, desktop resident runtime needs, iPad Local LLM background limits, config-file portability, and repo structure options.

## Classification

- Input Type: Intent + Constraint + Artifact
- Active Mode: Execute
- Governing Anchors: `AGENTS.md`, `docs/00-meta/input-intent.md`, `docs/00-meta/input-constraint.md`, `docs/00-meta/input-artifact.md`, `docs/00-meta/mode-a-explore.md`, `tasks/README.md`, `docs/10-prd/index.md`, `docs/10-prd/glossary.md`, `docs/20-product-tdd/system-state-and-authority.md`, `docs/20-product-tdd/cross-unit-contracts.md`, `/Users/lanzhijiang/Development/InKCre/core-py/README.md`, `/Users/lanzhijiang/Development/InKCre/core-py/docs/30-unit-tdd/business-pipeline-and-authority.md`

## Purpose

This packet captures the exploration and implementation record for reshaping Crafting Table for multiple clients.

The first packet draft was too generic. It treated multi-client work as a broad sync and architecture problem before checking the actual repo and the user's plan. This revision narrows the packet around current evidence:

- Crafting Table currently stores Goal Forest, captures, sessions, host profiles, and remote continuity in a local `WorkspaceDocument`.
- InKCre core-py is a FastAPI / SQLModel / PostgreSQL info-base backend whose durable graph state is blocks and relations.
- Codex Remote uses CTCore Codex Remote Server as the host-side adapter behind a CraftingTable-owned HTTP/WebSocket contract.
- Local LLM is a local model manifest, cache, foreground HTTP server, bearer token, and runtime boundary.

This packet should remain a staging area for boundary clarification and phase evidence. It is not a PRD replacement.

Phase 7 update:

- `WorkspaceDocument` / `WorkspaceStore` are no longer runtime concepts in the iPad client.
- `CTCore` is now the feature-gated backend library boundary.
- The iPad target can call CTCore through generated UniFFI Swift bindings.
- The first completed client binding slice is `HostConfigStore` -> CTCore `portable-config`.
- Goal Forest, Capture, Session, and Remote Continuity remain split domain stores and should move to CTCore/InKCre domain APIs incrementally.

## User Direction Captured

- Goal Forest and Capture do not need Crafting Table-owned multi-device sync because they are expected to move toward InKCre.
- Other configuration such as Remote SSH and Codex can use a file that the user syncs through Nextcloud, iCloud, or an equivalent filesystem sync tool.
- Local LLM does not need cross-device data sync.
- Client capabilities are not required to be equivalent across platforms.
- For Codex Remote, Windows and macOS are controlled endpoints that run the CTCore Codex Remote Server / Host Runtime.
- For Codex Remote, iPadOS and Android are control endpoints that run Codex Remote client UI and networking adapters.
- The old host-side service crate should be deleted after migration; CTCore owns the server implementation, while platform clients own lifecycle and embedding.
- Embedded Codex Host Runtime should move into the shared backend library as an in-process library surface, not a bundled sidecar process.
- Desktop clients should support login launch and background residency to serve Codex Remote.
- The iPad client should pursue the closest practical equivalent for Local LLM Service reliability under iPadOS lifecycle constraints.
- The most important implementation direction may be a cross-platform backend library that owns business capabilities and is compiled with only the needed feature set, while platform clients provide adapters for OS-specific capabilities such as storage, camera, credentials, background lifecycle, and platform UI.
- Backend library features are not all equivalent. For example, Codex Remote Control Server and Codex Remote Control Client should be separate compile-time features because they have different capabilities, authorities, and platform requirements.
- Current non-iPad platform scope is intentionally narrow: macOS, Windows, and Android should focus on Codex Remote first, not Goal Forest, Capture, Local LLM, or full CT feature parity in the first client slices.
- CTCore is expected to contain cross-platform implementations for Goal Forest, Capture, Session, Codex Remote client/server, and Local LLM core where those capabilities are genuinely platform-independent. Platform clients still own OS adapters.
- Preferred client stack decisions: macOS uses SwiftUI after the Apple project migration, Android uses Kotlin, and Windows uses Rust + Tauri.
- Codex Host Runtime API should be shaped around an async event stream.
- First new platform implementation target should be macOS Host Runtime.

## Current Evidence

### Crafting Table Workspace State

Historical local workspace state was a versioned Codable JSON document under app support scope.

Evidence:

- Pre-Phase-6, `clients/apple/iPad/Features/Shared/WorkspaceModels.swift` defined `WorkspaceDocument` with `goalNodes`, `goalEdges`, `sessions`, `captures`, `hosts`, and `remoteContinuityRecords`.
- Pre-Phase-6, `clients/apple/iPad/Features/Shared/WorkspaceStore.swift` persisted that document to `workspace-v0.json`.
- Phase 6 replaced the aggregate with split stores in `clients/apple/iPad/Features/Shared/BackendStores.swift`.

Implication:

- The old local JSON document was an early `0.1.0` persistence boundary, not an appropriate long-term multi-client sync authority for Goal Forest or Capture if those move to InKCre.

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

Pre-migration Codex Remote used a standalone Rust host-side service. The durable boundary is now CTCore Codex Remote Server plus platform client lifecycle adapters.

Evidence:

- `CTCore/src/codex_remote_control/server/` owns the axum server, codex-app server adaptation, thread routes, model routes, turn submission, and turn event WebSocket routes.
- `clients/apple/iPad/Features/CodexRemote/CodexRemoteClient.swift` talks to a Codex Remote Server endpoint instead of codex-app server directly.
- `docs/20-product-tdd/cross-unit-contracts.md` keeps codex-app server protocol churn behind CTCore Codex Remote Server.

Implication:

- macOS and Windows CT clients should eventually include a Codex Remote Control Server / Host Runtime Unit that owns codex-app server adaptation, host-local process details, and the cross-device wire contract.
- iPadOS and Android should remain control clients for this path.
- Embedding Codex Remote Server into desktop clients should remove the separately managed daemon experience without erasing the server-owned wire contract.

### Local LLM Direction

Current Local LLM state is device-local by design.

Evidence:

- `docs/20-product-tdd/system-state-and-authority.md` assigns local model manifest/cache, active model, HTTP server listener state, bearer token, and local chat transcript to Local LLM local owners.
- `clients/apple/iPad/Features/LocalLLM/LocalLLMStore.swift` persists a local manifest and cache path.
- `clients/apple/iPad/Features/LocalLLM/LocalLLMHTTPServer.swift` exposes a bearer-protected local HTTP surface.

Implication:

- Local LLM should not be pulled into cross-device data sync.
- Multi-client planning should instead track which platforms can host, call, or configure local model services.
- iPadOS service reliability needs platform-lifecycle design rather than sync design.

## Platform Role Hypotheses

- macOS: Codex Remote desktop client plus in-process Codex Host Runtime; supports login launch, background residency, codex-app server adaptation, local configuration, and control UI where useful.
- Windows: Codex Remote desktop client plus in-process Codex Host Runtime; supports login launch, background residency, codex-app server adaptation, local configuration, and control UI where useful.
- iPadOS: current full CT client plus Codex Remote control client; Local LLM host where foreground or continued-background execution is practical.
- Android: Codex Remote control client; not expected to host Codex Host Runtime in the first direction.

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
- How should CTCore's in-process Codex Host Runtime API be exposed through each platform client while preserving the server-owned wire contract?
- What belongs in the cross-platform backend library versus the platform client adapter layer?
- Should portable capabilities such as networking and filesystem access live inside the backend library, or be injected by clients for stricter platform control?
- Which backend library features should be compiled into each platform client?
- What platform stack should desktop CT use for Codex Remote Server embedding?
- How much of `clients/apple/iPad/Features/CodexRemote/` can be reused by iPadOS and Android, and how much is only contract vocabulary?
- What exact iPadOS background behavior can Local LLM rely on for active generation, active HTTP serving, and idle listening?

## Guardrails

- Do not treat `personal everywhere productivity busybox / control surface` as final naming.
- Do not design Crafting Table-owned sync for Goal Forest / Capture while InKCre is the expected authority path.
- Do not assume feature parity across platforms.
- Do not erase the Codex Remote Server wire contract just because the old standalone host-side process has been deleted.
- Do not describe iPad Local LLM as an always-on background daemon.
- Do not move code solely to make the tree look multi-platform.
- Do not rewrite existing feature packets unless this exploration proves a direct conflict.

## First Exploration Slices

1. Current coupling inventory
   - Inventory `WorkspaceDocument`, `WorkspaceStore`, Goal Forest, Capture, Remote Control, Codex Remote, CTCore Codex Remote Server, and Local LLM.
   - Mark which state is temporary local app state, portable config, InKCre-bound durable graph state, host-owned runtime state, or local-only runtime/cache state.

2. InKCre mapping sketch
   - Map Goal Forest and Capture concepts to InKCre blocks, resolvers, relations, and API routes.
   - Identify missing InKCre concepts without inventing them inside Crafting Table.

3. Codex Host Runtime boundary
   - Separate Codex Remote Server as a code unit, runtime unit, process shape, and wire contract.
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
- `codex-host-runtime-boundary.md`: Codex Remote Server unit, wire contract, desktop residency, and control-client implications.
- `portable-config-boundary.md`: Remote SSH / Codex config-file shape, filesystem-sync assumptions, and secret handling.
- `local-llm-lifecycle-boundary.md`: iPadOS foreground/background service states, limits, and verification plan.
- `repo-structure-options.md`: minimal repo organization options with tradeoffs and migration risk.
- `implementation-plan.md`: phased implementation sequence and execution evidence.
- `ipad-ctcore-integration-plan.md`: Rust-to-Swift binding direction, first iPad CTCore slice, and key build/authority decisions.
- `platform-client-architecture.md`: target client stacks, repo structure, and build workflow hypotheses for macOS, Windows, and Android.

Create child notes only when they materially help the task.

## Promotion Candidates

- Stable product positioning and platform role language -> `docs/10-prd/`
- InKCre-backed Goal Forest / Capture authority and cross-unit contract -> `docs/20-product-tdd/`
- Codex Host Runtime topology, in-process library boundary, and Codex Remote Server contract changes -> `docs/20-product-tdd/`
- Portable config file schema and secret boundary -> `docs/20-product-tdd/` or local code-adjacent docs after implementation pressure is real
- iPadOS Local LLM lifecycle guarantees and limits -> `docs/20-product-tdd/` after executable verification
- iPad CTCore binding and artifact workflow -> `docs/20-product-tdd/` after the first Swift smoke path is executable
- Mechanically enforced contracts -> code, tests, build settings, smoke checks
- Volatile alternatives, discarded options, and unresolved questions -> keep in this packet

## Open Questions

- Is `personal everywhere productivity busybox / control surface` an internal positioning phrase, product category, or eventual product language?
- Should the first non-iPad CT client be macOS, Windows, or a desktop host runtime without full UI?
- Should Crafting Table integrate with InKCre as a direct REST client, an InKCre extension, or a small dedicated bridge?
- Should CTCore Swift bindings use UniFFI as planned, or does iOS artifact complexity force a narrower C ABI for the first slice?
- Should generated Swift binding files be checked in permanently, or only during the early integration phase?
- Should Codex Host Runtime keep the current HTTP/WebSocket contract unchanged for Android/iPad clients?
- What is the smallest in-process Codex Host Runtime API that macOS and Windows can embed without taking ownership of codex-app server details?
- On iPadOS, what Local LLM service state is product-worthy if background continuation is interruptible?
