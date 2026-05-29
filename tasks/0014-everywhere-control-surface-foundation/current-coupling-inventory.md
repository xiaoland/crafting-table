# Current coupling inventory

## Purpose

Inventory the current repo shape before implementation starts.

This note is intentionally descriptive. It records where product state, platform APIs, runtime behavior, and early `0.1.0` shortcuts are coupled today so later boundary work can be deliberate.

Phase 6 update: the iPad client no longer has a `WorkspaceDocument` / `WorkspaceStore` runtime model. Goal Forest, Session, Capture, Host Config, and Remote Continuity now have separate client stores. Older observations below remain useful as historical coupling evidence, but the code references to `WorkspaceDocument`, `WorkspaceStore`, and `workspace-v0.json` describe the pre-Phase-6 shape.

## Current architecture pressure

The user's current direction changes the main architecture question.

The key candidate is not a cloud backend owned by Crafting Table. It is a cross-platform backend library used by platform clients. That library should own business capabilities and stable contracts. Platform clients should own OS-specific capabilities such as UI, camera, storage locations, credential stores, background lifecycle, launch-at-login, and platform permissions.

The backend library should be feature-gated at compile time. Platform clients should package only the feature set they need. Codex Remote Control Server and Codex Remote Control Client are separate backend-lib features because they have different authorities and runtime requirements.

Open point: portable infrastructure such as networking and filesystem access may either live inside the backend library through cross-platform dependencies, or be injected through client adapters. That decision should follow concrete implementation pressure, not aesthetics.

## Top-level app coupling

### App root

Evidence:

- `CraftingTable/App/CraftingTableApp.swift` creates separate `GoalForestStore`, `SessionStore`, `CaptureStore`, `HostConfigStore`, `RemoteContinuityStore`, `LocalLLMStore`, and `LocalLLMServerController` as SwiftUI `StateObject`s.
- `CraftingTable/App/RootView.swift` owns routing, sheet presentation, selected Goal Forest node, selected host, linked remote session, and live Remote Control connection state.

Current coupling:

- Business state, persistence state, and UI route state are coordinated directly in SwiftUI root code.
- `RootView` passes product records and mutation callbacks into feature screens.
- This is acceptable for the current shallow iPad foundation, but it is not a reusable backend boundary.

Backend-lib implication:

- A future backend library should not know about SwiftUI routing, sheets, `NavigationSplitView`, or UIKit canvas mechanics.
- The first extraction candidate is not UI. It is state mutation semantics and service contracts.

## Former workspace document coupling

Evidence:

- Pre-Phase-6, `CraftingTable/Features/Shared/WorkspaceModels.swift` defined `WorkspaceDocument` with `goalNodes`, `goalEdges`, `sessions`, `captures`, `hosts`, and `remoteContinuityRecords`.
- Pre-Phase-6, `CraftingTable/Features/Shared/WorkspaceStore.swift` persisted the whole document to `workspace-v0.json`.
- Phase 6 replaced those files with `BackendModels.swift` and `BackendStores.swift`.
- Current client-local persistence is split into `goal-forest-v1.json`, `sessions-v1.json`, `captures-v1.json`, `host-config-v1.json`, and `remote-continuity-v1.json`.

Current coupling:

- Goal Forest, Capture, Work Session, Remote Control host metadata, and remote continuity share one Codable JSON document.
- The document is both a persistence format and a cross-feature coordination object.
- IDs are Crafting Table-local strings such as `node-*`, `capture-*`, `session-*`, and `remote-*`.

Classification:

- `goalNodes`, `goalEdges`: should move toward InKCre-backed graph state.
- `captures`: should move toward InKCre-backed blocks, with resolver choice depending on content.
- `sessions`: likely need to become blocks if they are durable graph-linked concepts.
- `hosts`: candidate for portable config file, not InKCre graph authority.
- `remoteContinuityRecords`: likely split; host/session links may become relations if sessions become blocks, while transient connection/runtime state can remain local when it is not useful as durable memory.

Backend-lib implication:

- `WorkspaceDocument` should not remain a backend-lib or client runtime concept.
- Each domain store should become independently replaceable by CTCore/InKCre/portable-config adapters.

## Goal Forest coupling

Evidence:

- `GoalForestScreen` receives `[GoalNode]`, `[GoalEdge]`, `[WorkSession]`, and `[CaptureItem]`.
- `GoalGraphCanvas` and `GoalGridLayout` derive a visual DAG layout from nodes and edges.
- `GoalForestStore.createGoalEdge` rejects self edges, duplicate directed edges, and cycle-producing edges.

Current coupling:

- Goal Forest is currently both a product graph and an iPad canvas interaction.
- `GoalForestStore` currently rejects self edges, duplicate directed edges, and cycle-producing edges.
- Visual layout is derived from document order and DAG topology inside SwiftUI/UIKit view code.

Clarification:

- The previous packet used the word `placement`. That was imprecise. Current code has capture attachment fields, not a separate placement model.
- The user clarified Goal Forest is a DAG. There is no separate placement or ordering model identified here.

InKCre implication:

- Goal node should be a block.
- Goal edges should be relations.
- The DAG shape does not need special hard enforcement in the first backend boundary. It can remain a Crafting Table usage convention over InKCre relations unless real data drift proves enforcement is needed.
- Canvas layout remains client/UI behavior unless a durable layout concept is admitted later.

Backend-lib implication:

- Candidate shared business capability: create goal node, edit goal node, connect goal nodes, query nearby nodes, and optionally surface diagnostics if graph shape becomes surprising.
- Platform adapter responsibility: render graph/canvas, handle gestures, camera/zoom if any, and platform-specific interaction.

## Capture coupling

Evidence:

- `CaptureSheet` currently captures text only.
- `CaptureStore.createCapture` splits the first line into title and the rest into detail, then stores optional `linkedSessionID` and `linkedNodeID`.

Current coupling:

- Capture is currently text-only, SwiftUI-sheet-driven, and written through `CaptureStore`.
- Attach-to-current-session and attach-to-primary-node are UI toggles, not a durable graph abstraction.

InKCre implication:

- Capture does not need one stable resolver type.
- It may create a Crafting Table-specific capture resolver when the captured item is still raw or unclassified.
- It may also store directly as native InKCre-supported types such as text or image when the content clearly fits.
- Attachments to goal nodes or sessions should become relations once those concepts are blocks.

Backend-lib implication:

- Candidate shared business capability: capture intake normalization, resolver selection, attachment relation creation.
- Platform adapter responsibility: text input UI, camera/photo/file capture, microphone if admitted, permissions, temporary file handling.

## Work Session coupling

Evidence:

- `WorkSession` currently stores `title`, `status`, `objective`, `continuity`, and `activity`.
- `WorkSessionScreen` shows nearby Goal Forest context, captures, linked sessions, and remote continuity.
- `SessionStore.updateSessionStatus` enforces at most one active session locally.

Current coupling:

- Work Session is durable local app state and also the routing target for active execution.
- Session state is connected to Goal Forest and Capture through local IDs.
- Remote continuity is shown inside session continuity UI.

InKCre implication:

- If session links are relations, session likely needs to become a block.
- Session lifecycle state, including active status, can live inside the session block content because InKCre resolver plus arbitrary content payload leaves room for status fields.
- Whether "one active session" is a global product rule or a soft client convention remains open.

Backend-lib implication:

- Work Session should be included in the InKCre mapping discussion instead of left as purely local app state.

## Remote Control and host config coupling

Evidence:

- `HostProfile` lives in `HostConfigStore` with `name`, `address`, `note`, and `credentialReferenceID`.
- `HostProfileSheet` edits host metadata and displays credential reference.
- `RemoteControlScreen` is currently a placeholder-level terminal/file-transfer surface with session linkage.

Current coupling:

- Host profiles are stored with product workspace data.
- Secret material is already represented as an external credential reference.
- Remote Control runtime state is mostly in `RootView` and screen state, not in a real SSH subsystem yet.

User direction:

- Remote SSH configuration can be stored in a file and synced by Nextcloud, iCloud, or another filesystem sync tool.

Backend-lib implication:

- Candidate shared business capability: parse, validate, and expose host config records; manage non-secret config schema; produce diagnostics.
- Platform adapter responsibility: credential lookup, SSH implementation if platform-native, filesystem sync location selection, file conflict UX.

Open point:

- Whether Remote SSH and Codex endpoint config share one file or live in a config directory is unresolved.

## Codex Remote coupling

Evidence:

- `CodexRemoteScreen` stores feature-local host profiles in `@AppStorage`.
- `CodexRemoteClient` talks to a Companion endpoint through HTTP and WebSocket.
- `Companion/src/main.rs` currently starts an independent Rust axum server.
- `Companion/src/routes.rs` exposes health, thread, model, desktop snapshot, turn submission, and turn event routes.

Current coupling:

- iPad UI is a control client for a host-side service.
- Companion is currently a standalone process, but its contract is the important boundary.
- Host profile state is duplicated conceptually: Remote Control has `HostProfile` in `HostConfigStore`; Codex Remote has private `CodexRemoteHostProfile` in `@AppStorage`.

User direction:

- macOS and Windows should be controlled endpoints running Codex Companion Server / Host Runtime.
- iPadOS and Android should be control endpoints.
- Codex Host Runtime should be closer to an app-embedded service/helper than a user-managed standalone daemon.

Backend-lib implication:

- Candidate shared business capability: Codex Remote Control Server owns the cross-device protocol schema, request/response normalization, turn stream interpretation, host profile/config schema, and pairing state.
- Codex Remote Control Client consumes that protocol and projects it into control-client state. It should not own the protocol authority.
- Host desktop adapter responsibility: login launch, background residency, desktop scout permissions, Codex app-server process adaptation, local HTTP/WebSocket listener or equivalent wire transport.
- Control client adapter responsibility: UI, network reachability, local notifications, platform-specific storage for non-secret config.

Open point:

- Whether the Rust Companion becomes an app-supervised sidecar, a helper service, or a library boundary remains unresolved.

## Local LLM coupling

Evidence:

- `LocalLLMStore` persists `local-llm-manifest-v0.json` and a `LocalLLMModels` cache directory under app support.
- `LocalLLMServerController` owns bearer token generation/storage, server state, port, active model lookup, and generation state transitions.
- `LocalLLMRuntime` is already a narrow generation boundary.
- `LocalLLMHTTPServer` owns a bearer-protected local HTTP route surface.

Current coupling:

- Local model lifecycle, local cache, HTTP serving, and runtime execution are all inside the iPad app.
- The runtime boundary is better isolated than the broader workspace model.
- Server reliability is tied to iPadOS app lifecycle.

User direction:

- Local LLM does not need cross-device sync.
- iPad should pursue the closest practical equivalent to a reliable service.

Backend-lib implication:

- Candidate shared business capability: model manifest schema, model readiness rules, OpenAI-compatible request/response contract, runtime-agnostic generation request/result models.
- Platform adapter responsibility: model file storage, credential store, local network listener, background task handling, GPU/Metal availability, lifecycle interruptions.

Open point:

- iPadOS background continuation can improve active service reliability, but it is not equivalent to desktop daemon residency.

## InKCre integration coupling

Evidence:

- InKCre `BlockModel` carries `resolver` and `content`.
- InKCre `RelationModel` carries `from_`, `to_`, and `content`.
- InKCre extension docs show custom resolvers and graph forms as the extension pattern.
- `InfoBaseManager` recursively inserts subgraphs and relations; producers propose graph data while info-base owns persistence.

Current coupling risk:

- Crafting Table currently uses local object types that do not map 1:1 onto InKCre's block/relation graph.
- InKCre currently has no Crafting Table-specific Goal Forest, Capture, or Work Session resolver.

Backend-lib implication:

- The shared backend library may need a dedicated InKCre client/bridge module.
- Goal node and session should likely be represented as blocks.
- Capture resolver selection is content-dependent.
- Goal Forest's DAG shape can initially be a Crafting Table convention over relations rather than a separately enforced persistence invariant.

## State classification table

| Current object | Current owner | Likely future authority | Notes |
|---|---|---|---|
| GoalNode | `GoalForestStore` | InKCre block | Needs resolver/content schema. |
| GoalEdge | `GoalForestStore` | InKCre relation | Treat DAG shape as usage semantics first; add enforcement only if needed. |
| CaptureItem | `CaptureStore` | InKCre block | Resolver may vary by content. |
| WorkSession | `SessionStore` | InKCre block candidate | Active status can live in block content. |
| HostProfile | `HostConfigStore` | portable config file | Secret stays in platform credential store. |
| RemoteContinuityRecord | `RemoteContinuityStore` | split | Durable session link may be relation; runtime recency may be local/config. |
| CodexRemoteHostProfile | `@AppStorage` | portable config file | Should converge with host config story. |
| Codex live stream state | SwiftUI runtime state | host/control runtime | Not portable config. |
| Companion app-server adapter | standalone Rust process | desktop app-embedded service/helper | Wire contract authority belongs to Codex Remote Control Server. |
| Local LLM manifest | app support JSON | device-local backend state | No cross-device sync required. |
| Local LLM model cache | app support files | device-local cache | Potentially large; should not sync. |
| Local LLM bearer token | Keychain | platform credential store | Device-local secret. |

## Near-term discussion points before implementation

- What language/runtime can realistically host the cross-platform backend library across iPadOS, macOS, Windows, and Android?
- Which capabilities must be pure business logic versus injected platform adapters?
- What is the first backend-lib slice small enough to prove the boundary: config parsing, Codex Remote Control Server/Client contract models, InKCre client mapping, or Local LLM manifest logic?
- Should Work Session be promoted into InKCre graph semantics now, or remain local until Goal Forest / Capture mapping is proven?
- Should the Codex Host Runtime keep the current Rust codebase and become an app-supervised helper first, before any deeper embedding?

## Current conclusion

The repo is not ready for a broad folder reshuffle.

The first useful move is to define ownership boundaries around:

- InKCre-backed graph state for Goal Forest, Capture, and likely durable sessions.
- Portable user-synced config for Remote SSH and Codex endpoints.
- Desktop app-embedded Codex Host Runtime for macOS and Windows.
- Device-local Local LLM state with explicit iPadOS lifecycle limits.
- A feature-gated cross-platform backend library that owns business capabilities while clients provide platform adapters.
