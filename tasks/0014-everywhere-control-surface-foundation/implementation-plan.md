# Implementation plan

## Purpose

Plan the implementation sequence after the current architecture exploration.

This is not permission to start implementation. It defines the likely slices to execute once the high-level boundaries are confirmed.

## Architecture direction

The likely target shape is:

```text
Platform clients
  - iPadOS app
  - macOS app
  - Windows app
  - Android app

Platform adapter layer
  - UI and navigation
  - camera / media capture
  - credential store
  - filesystem location
  - launch-at-login / background lifecycle
  - local network listener
  - platform permissions

Cross-platform backend library
  - feature-gated business models and commands
  - feature-gated config schemas and validation
  - InKCre mapping/client boundary
  - Codex Remote Control Server
  - Codex Remote Control Client
  - Local LLM manifest and request/response contracts
  - runtime-independent service state machines where practical

External/local authorities
  - InKCre info-base for Goal Forest, Capture, and likely Work Session blocks/relations
  - user-synced config files for Remote SSH and Codex endpoint metadata
  - platform credential stores for secrets
  - desktop Codex Remote Control Server / Host Runtime
  - device-local Local LLM cache/runtime
```

The backend library should own business capabilities and be compiled with only the needed feature set. Clients should own platform-specific capability adapters. Portable infrastructure such as HTTP and filesystem access can either live in the backend library or be injected by adapters; choose per slice.

Candidate backend-library features:

- `portable-config`: non-secret config schemas, validation, and diagnostics.
- `codex-remote-control-server`: authoritative Codex Remote Control wire contract, host runtime state, Codex app-server adaptation contract, desktop scout projection schema, and turn event normalization.
- `codex-remote-control-client`: control-client state projection and request helpers that consume the server-owned contract.
- `inkcre-graph`: Goal Forest, Capture, and Work Session mapping to InKCre blocks and relations.
- `local-llm-core`: manifest schema, readiness rules, and OpenAI-compatible request/response contracts.

## Codex Remote Control Server boundary

Codex Remote Control Server is the desktop-controlled endpoint for Codex Remote Control.

It should be an app-embedded in-process library surface, not a user-managed standalone daemon or bundled sidecar.

Current `Companion` has two useful separations to preserve while the runtime code moves into CTCore:

- host adapter: Codex app-server / Codex CLI / local Codex store / Desktop Scout integration
- server-owned wire contract: stable routes and event schemas consumed by iPadOS / Android control clients

The "wire contract" means the cross-device contract whose authority belongs to the Codex Remote Control Server feature in the backend library. Today that includes:

- `GET /health`
- thread list/detail/create/resume routes
- model list route
- turn submission route
- desktop snapshot route
- active turn WebSocket event route
- JSON response and event payload schemas owned by the Codex Remote Control Server feature

It is broader than `codex app-server events -> companion events`.

The host runtime adapts Codex app-server JSON-RPC methods and app-server event stream into CT-owned HTTP/WebSocket resources whose schema authority sits in the Codex Remote Control Server feature. Events are one important part of the contract, but the contract also covers health, discovery, thread creation, model metadata, permissions, desktop handoff, errors, and reconnect semantics.

## Phase 0 - Boundary Decisions

Goal: resolve decisions that would be expensive to reverse after code movement.

Outputs:

- choose the first backend-library implementation strategy
- decide whether the first backend library slice is config, InKCre mapping, Codex contract models, or Local LLM contracts
- decide how strongly the backend library owns networking/filesystem versus adapter injection
- decide compile-time feature names and dependency boundaries
- decide whether Work Session is included in the first InKCre mapping
- decide how current Rust Companion should be hosted by macOS/Windows apps in the first desktop slice

Recommended first decision:

- Start backend-library proof with `portable-config` plus Codex Remote Control Server/Client contract models, because it has useful cross-platform pressure and does not require InKCre schema changes.

## Phase 1 - Portable Config Foundation

Goal: extract the least controversial cross-platform backend capability.

Scope:

- define non-secret config schema for Remote SSH hosts and Codex hosts
- converge current `HostProfile` and `CodexRemoteHostProfile` concepts
- define config file location as adapter-provided
- keep secrets as credential references only
- add validation and diagnostics in backend library

Why first:

- It is cross-platform.
- It respects the user's Nextcloud / iCloud sync direction.
- It has limited product risk.
- It gives the backend library a useful first surface without moving Goal Forest yet.

Verification:

- load sample config
- validate missing/duplicate/conflicting host entries
- round-trip save without secrets
- import current local host records into the new shape in a reversible test or fixture

Implementation evidence:

- `CTCore/` now exists as a Rust backend library crate.
- `CTCore/Cargo.toml` has no default features and declares `portable-config`, `codex-remote-control-server`, `codex-remote-control-client`, `inkcre-graph`, and `local-llm-core`.
- `portable-config` defines `PortableConfigDocument`, shared host records, optional SSH endpoint config, optional Codex Remote Control endpoint config, credential references, and validation diagnostics.
- Config file locations are not owned by the backend library; platform clients should provide storage locations.
- Secrets are represented only as `credentialRef` strings.
- Fixtures cover valid round-trip and invalid diagnostic codes.

Verified:

- `cargo fmt --manifest-path CTCore/Cargo.toml`
- `cargo test --manifest-path CTCore/Cargo.toml --features portable-config`
- `cargo test --manifest-path CTCore/Cargo.toml --no-default-features`
- `cargo test --manifest-path CTCore/Cargo.toml --all-features`

## Phase 2 - Codex Remote Control Feature Extraction

Goal: make Codex Remote Control's server/client features portable before changing the desktop process model.

Scope:

- move or duplicate contract models into the backend library under server-owned feature authority
- split compile-time features for Codex Remote Control Server and Codex Remote Control Client
- define host runtime states and control-client states
- define turn stream event normalization independent from SwiftUI
- define pairing/auth placeholders without implementing full security yet
- keep current iPad UI using the same behavior through an adapter

Verification:

- decode current Companion responses through backend-library models
- replay saved or fixture turn events into normalized state
- ensure SwiftUI state remains a projection, not the owner of contract semantics

Implementation evidence:

- `CTCore` now exposes `codex_remote_control::contract` when either `codex-remote-control-server` or `codex-remote-control-client` is enabled.
- The contract module mirrors current Companion JSON response/event shapes for health, threads, models, turn submit, desktop snapshot, API errors, permission modes, and active turn stream events.
- Turn stream events now have a typed `TurnStreamEventType` while preserving the current wire key `"type"` and snake_case payload names.
- `codex-remote-control-client` adds `TurnStreamProjection`, a UI-independent client projection that accumulates assistant deltas and terminal/error state.
- Host runtime state, control-client connection state, and pairing state are represented as portable enums only; no lifecycle implementation or security mechanism has been added yet.
- Existing Companion and SwiftUI code paths have not been rewired in this phase.

Verification policy:

- Feature availability is checked by compiling the crate under the relevant feature sets.
- Runtime tests are limited to JSON boundary behavior and client projection behavior that Rust type checking cannot prove.

## Phase 3 - Desktop Codex Remote Control Server Packaging

Goal: make Codex Remote Control embeddable into desktop clients as an in-process CTCore library surface while preserving the host wire contract.

Scope:

- choose first desktop target: macOS or Windows
- move existing Rust Companion runtime code toward CTCore instead of treating the binary as the product runtime
- expose an in-process Host Runtime API for desktop CT clients
- support login launch / background resident mode
- expose user-visible status, stop/start, logs, and diagnostics
- keep iPad/Android control clients talking to the same or versioned server-owned wire contract

Clarification:

- Login launch, background residency, app window lifecycle, and OS service registration are responsibilities of each platform client adapter.
- Codex Host Runtime should expose embeddable in-process runtime APIs and status contracts. It should not own client lifecycle policy.

Updated implementation direction:

- in-process library mode is the product embedding model.
- standalone binary/sidecar mode may remain as a development harness and diagnostic tool only.

Verification:

- desktop app can start host runtime in-process without terminal
- host runtime starts on login when enabled
- iPad client can connect to the packaged runtime
- runtime survives window close when background residency is enabled
- user can stop it intentionally

Implementation evidence:

- Current `clients/apple/CraftingTable.xcodeproj` still has only an iPad target: `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"` and `TARGETED_DEVICE_FAMILY = 2`.
- Because there is no desktop CT app target yet, this phase first proved router/runtime construction without launching the binary; the product target is still in-process CTCore embedding.
- `CTCore` now includes server-owned host runtime status contract types: `HostRuntimeState`, `HostRuntimeLaunchContext`, and `HostRuntimeStatusResponse`.
- `Companion` depends on `CTCore` with `codex-remote-control-server` enabled for the new host runtime status route.
- `GET /host/runtime` reports process state, PID, bind address, Codex home, and launch context.
- `Companion` is now both a library crate and a thin binary. The library exposes `Config`, `build_router`, `serve`, `serve_with_shutdown`, and `shutdown_signal`.
- `Companion/tests/runtime_embedding.rs` proves a client can build the Codex Remote router in-process without launching the binary.
- `scripts/codex-host-runtime.sh` provides development-only foreground `run`, background `start`/`stop`/`restart`, `status`, and `logs` commands.
- The development sidecar `start` command builds and launches the actual runtime binary instead of backgrounding `cargo run`, so the recorded PID belongs to the served process.
- `.codex/environments/environment.toml` has Codex app actions for starting, stopping, and checking the Codex Host Runtime.

Current limit:

- This now supports an embedded runtime shape and a development sidecar shape. Pairing/auth, in-app macOS controls, Windows background packaging, moving host runtime code fully into CTCore, and mobile client adapter integration are not implemented yet.

## Phase 8 - Platform Client Architecture Decisions

Goal: settle macOS, Windows, and Android high-level implementation strategy before adding new client trees.

Current direction:

- macOS uses SwiftUI with narrow AppKit interop.
- Android uses Kotlin and Jetpack Compose.
- Windows uses Rust + Tauri.
- macOS and Windows only need Codex Remote for now.
- Android only needs Codex Remote control-client functionality for now.
- Embedded Codex Host Runtime belongs in CTCore/shared backend as an in-process library API.
- Codex Host Runtime API should expose async event streams instead of a blocking command-only surface.
- First implementation platform is macOS Host Runtime, after the Apple project migration.

Outputs:

- target repo structure for client folders and binding artifacts
- Apple, Android, and Windows build workflow definitions
- Codex Host Runtime API shape for in-process embedding
- first-platform implementation order

Planning artifact:

- `platform-client-architecture.md`

Implementation evidence:

- Apple project structure has moved to `clients/apple/`.
- Existing iPad source now lives under `clients/apple/iPad/`.
- `CraftingTableMac` now exists as a macOS app target under `clients/apple/macOS/`.
- `.codex/environments/environment.toml` now has a `Run MacOS client` action that calls `scripts/run-macos-client.sh`.
- Direct `Start Codex Remote Companion` environment actions have been removed. Development lifecycle actions now use `scripts/codex-host-runtime.sh` and are explicitly named `Dev Codex Host Runtime`.
- `scripts/codex-remote-companion.sh` no longer launches the runtime process directly; it keeps the macOS Scout helper and a legacy `smoke` alias while pointing lifecycle commands to `scripts/codex-host-runtime.sh`.
- `clients/android/` and `clients/windows/` now exist as target client roots without introducing Gradle or Tauri build files prematurely.
- `scripts/build-ctcore-ios.sh`, `scripts/smoke-ctcore-swift-binding.sh`, and iPad launch scripts use the migrated Apple paths.
- `CTCore` now exposes `codex_remote_control::host_runtime` under `codex-remote-control-server`.
- The first Host Runtime API shape is async-event oriented:
  - `HostRuntimeHandle`
  - `HostRuntimeEventBus`
  - `HostRuntimeEventReceiver`
  - `HostRuntimeEvent`

Verified:

- XcodeBuildMCP `build_sim` for `clients/apple/CraftingTable.xcodeproj` on `iPad Pro 13-inch (M5)` succeeded.
- `xcodebuild -project clients/apple/CraftingTable.xcodeproj -scheme CraftingTableMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build`
- `scripts/run-macos-client.sh --build-only`
- `scripts/run-macos-client.sh --verify`
- `scripts/build-ctcore-ios.sh`
- `scripts/smoke-ctcore-swift-binding.sh`
- `xcodebuild -list -project clients/apple/CraftingTable.xcodeproj` confirmed the current Xcode project has `CraftingTable` and `CraftingTableMac` app targets.
- `cargo fmt --manifest-path CTCore/Cargo.toml -- --check`
- `cargo fmt --manifest-path Companion/Cargo.toml -- --check`
- `bash -n scripts/codex-host-runtime.sh`
- `cargo test --manifest-path CTCore/Cargo.toml --no-default-features`
- `cargo test --manifest-path CTCore/Cargo.toml --features portable-config`
- `cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-server`
- `cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-client`
- `cargo test --manifest-path CTCore/Cargo.toml --all-features`
- `cargo test --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml --test runtime_embedding`
- foreground runtime smoke on `127.0.0.1:3787` returned `/host/runtime` with `state: running` and `launch_context: app_supervised`
- development sidecar smoke on `127.0.0.1:3789` completed `start -> status -> stop`, with `/host/runtime` reachable during status

## Phase 4 - InKCre Goal/Capture/Session Mapping

Goal: move durable personal graph concepts out of `WorkspaceDocument` and toward InKCre.

Scope:

- define Goal Node block content schema
- define Work Session block content schema, including status
- define Capture intake rules:
  - native InKCre text/image/etc. resolver when content clearly fits
  - Crafting Table capture resolver for raw/unclassified items
- define relation content vocabulary for goal edges, session links, capture links, and remote continuity links
- decide whether this is a Crafting Table backend-library InKCre client, an InKCre extension, or both

Clarifications:

- Goal Forest is a DAG, but DAG enforcement does not need to be a first implementation concern.
- "Placement" is not a separate current concept; the current behavior is attachment/linking.
- Ordering is not a known requirement.

Verification:

- create goal node as InKCre block
- create session as InKCre block with status payload
- create text capture as InKCre block
- link capture to goal/session through relations
- read back enough graph context to render the current Goal Forest and nearby session context

Implementation evidence:

- The actual local InKCre core path is `/Users/lanzhijiang/Development/InKCre/core-py`; `~/Development/core-py` does not exist on this machine.
- InKCre `BlockModel.content` is a string, and extension examples store structured content as JSON strings.
- InKCre relation identity is `from_ + to_ + content`, so the current CT relation vocabulary uses stable relation labels rather than mutable payload strings.
- `CTCore` now exposes `inkcre_graph` under the `inkcre-graph` feature.
- `inkcre_graph` defines InKCre block, relation, in/out arc, and subgraph wire-shape structs for `PUT /graph` style payloads.
- `inkcre_graph` defines CT content models for Goal Node, Work Session, Capture, and Remote Continuity.
- Work Session status is represented inside Work Session block content.
- Capture supports both CT-specific capture blocks and native InKCre `text` resolver mapping for clearly text-only capture content.
- `CTCore` now defines `InKCreGraphStore`, a transport-injected storage trait corresponding to InKCre graph insert, recent block listing, relation lookup, and block update.
- `CTCore` now defines `CraftingTableInKCreApi`, a client-facing API for saving/updating Goal Nodes, Work Sessions, Captures, goal edges, and loading Goal Forest / Capture projections.
- CTCore treats graph insertion and content update as separate operations because InKCre `fetchsert()` is resolver-owned and may return existing blocks without updating content.
- The current slice does not create a CT resolver extension in core-py or migrate `WorkspaceDocument`.

Verified:

- `cargo fmt --manifest-path CTCore/Cargo.toml -- --check`
- `cargo test --manifest-path CTCore/Cargo.toml --features inkcre-graph`
- `cargo test --manifest-path CTCore/Cargo.toml --all-features`

## Phase 5 - Local LLM Lifecycle Boundary

Goal: separate Local LLM business contracts from iPad lifecycle mechanics.

Scope:

- move manifest schema, readiness rules, and OpenAI-compatible request/response models toward backend library
- keep model cache, token storage, local listener, Metal/runtime, and background task handling in platform adapters
- explore iPad foreground serving plus `BGContinuedProcessingTask` for active work continuation
- define service states that honestly represent suspend/terminate/restart behavior

Verification:

- manifest logic can be tested without SwiftUI
- iPad service states distinguish foreground listening, continued background work, stopped, failed, and interrupted
- LAN client receives clear errors or reconnect behavior when the app is suspended or stopped

Implementation evidence:

- `CTCore` now exposes `local_llm_core` under the `local-llm-core` feature.
- `local_llm_core` defines portable manifest and model record schemas matching the current Swift manifest JSON keys, including `activeModelID`, `repositoryID`, and `downloadURL`.
- Model readiness is centralized as downloaded + verified + non-empty local path.
- Model selection is centralized: requested model id wins; otherwise active model; missing and unavailable models are explicit errors.
- Service state vocabulary distinguishes stopped, starting, foreground listening, foreground generating, continued background, interrupted, and failed.
- Minimal OpenAI-compatible contracts cover `GET /v1/models` response shape and `POST /v1/responses` request/response conversion.
- CTCore does not own filesystem paths, downloads, Keychain tokens, Network.framework listener, BG task mechanics, Metal/llama runtime, or UI transcript state.

Verified:

- `cargo fmt --manifest-path CTCore/Cargo.toml -- --check`
- `cargo test --manifest-path CTCore/Cargo.toml --features local-llm-core`

## Phase 6 - WorkspaceDocument Deletion

Goal: remove `WorkspaceDocument` as a runtime concept and make clients operate through domain APIs.

Scope:

- remove the single-document `WorkspaceStore.document` model from client code
- expose separate client-facing APIs for Goal Forest, Capture, Session, Host Config, and Remote Continuity
- keep each API independently replaceable by CTCore/InKCre/portable-config adapters
- do not add a backend-library bridge that preserves `workspace-v0.json` as an authority

Verification:

- no app code references `WorkspaceDocument`, `WorkspaceStore`, or `workspace-v0.json`
- app state flows through domain stores instead of one aggregate document
- app still builds after the split
- CTCore feature gates still compile without a `workspace-decomposition` feature

Implementation evidence:

- The rejected `workspace-decomposition` bridge was removed.
- `WorkspaceModels.swift` was replaced by `BackendModels.swift`, which keeps domain model types but has no aggregate workspace document.
- `WorkspaceStore.swift` was replaced by `BackendStores.swift`.
- Runtime state is now split across:
  - `GoalForestStore`
  - `SessionStore`
  - `CaptureStore`
  - `HostConfigStore`
  - `RemoteContinuityStore`
- `RootView` now reads from domain stores directly instead of `workspaceStore.document`.
- `CraftingTableApp` injects each domain store as its own environment object.
- Local persistence is split into separate files: `goal-forest-v1.json`, `sessions-v1.json`, `captures-v1.json`, `host-config-v1.json`, and `remote-continuity-v1.json`.
- These Swift stores are temporary client adapters with backend-API-shaped surfaces; the final authority for Goal Forest/Capture/Session should move behind CTCore/InKCre adapters rather than reintroducing an aggregate client document.

Verified:

- `cargo fmt --manifest-path CTCore/Cargo.toml -- --check`
- `cargo test --manifest-path CTCore/Cargo.toml --all-features`
- `cargo test --manifest-path CTCore/Cargo.toml --no-default-features`
- `xcodebuild -project clients/apple/CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' build`
- `rg -n "WorkspaceDocument|WorkspaceStore|workspace-v0|WorkspaceModels|workspaceStore|document\\." clients/apple/iPad clients/apple/CraftingTable.xcodeproj CTCore -S`

## Phase 7 - iPad Client CTCore Binding

Goal: let the iPad client call CTCore-backed domain APIs directly, starting with a small binding slice.

Scope:

- add a Rust-to-Swift binding path for CTCore
- package CTCore for iOS simulator and device
- keep CTCore feature-gated instead of linking every backend capability into the iPad app
- replace one Swift domain store with a CTCore-backed adapter
- keep UI, file paths, credentials, and platform lifecycle in Swift

Recommended technical direction:

- use UniFFI for Swift bindings, because Android/Kotlin reuse is expected later
- produce an iOS device/simulator XCFramework artifact for the iPad target
- check generated Swift binding files in during the first slice to keep Xcode builds deterministic
- start with `HostConfigStore` -> CTCore `portable-config`

First slice:

1. add UniFFI binding setup around CTCore portable config
2. expose decode, encode, validate, and diagnostic models to Swift
3. build CTCore as an iOS simulator/device artifact
4. link the iPad target against the artifact
5. update `HostConfigStore` so CTCore owns portable config parsing/validation
6. keep app-support file location and ObservableObject state in Swift

Do not start with:

- Goal Forest / Capture, because they require InKCre transport and resolver assumptions
- Local LLM, because lifecycle/runtime/platform responsibilities are much wider
- Codex Remote runtime, because streaming and server/client authority create a larger surface

Verification:

- CTCore portable-config tests pass through Cargo
- iPad app builds through Xcode with the CTCore artifact linked
- Swift smoke path proves host config validation is coming from CTCore
- no `WorkspaceDocument` aggregate reappears

Planning artifact:

- `ipad-ctcore-integration-plan.md`
- durable build boundary: `docs/20-product-tdd/platform-build-boundaries.md`

Implementation evidence:

- `CTCore` now has a `swift-bindings` feature.
- `CTCore/src/swift_bindings.rs` exposes a UniFFI facade for portable config decode, encode, validate, diagnostics, and default document construction.
- Generated Swift binding files live under `clients/apple/iPad/Generated/CTCore/`.
- `scripts/build-ctcore-ios.sh` regenerates UniFFI Swift bindings, builds local iOS device/simulator static libraries, and packages them into `CTCore.xcframework`.
- `scripts/smoke-ctcore-swift-binding.sh` compiles the generated Swift binding against CTCore and verifies validation + JSON round-trip through the Rust facade.
- The Xcode target has a `Build CTCore iOS Artifact` phase before Swift compilation.
- The iPad target links `CTCore.xcframework` from `clients/apple/iPad/Generated/CTCore/`.
- The CTCore build script phase is configured to run every build. Declaring the generated XCFramework as a same-target script output creates an Xcode dependency cycle with the Frameworks phase.
- `HostConfigStore` now loads/saves portable config JSON through CTCore binding functions:
  - `portableConfigDecodeJson`
  - `portableConfigEncodeJson`
  - `portableConfigValidate`
- Swift still owns the app-support file URL and `ObservableObject` state.
- CTCore owns portable config schema validation and diagnostic codes.

Verified:

- `cargo fmt --manifest-path CTCore/Cargo.toml -- --check`
- `cargo test --manifest-path CTCore/Cargo.toml --features swift-bindings`
- `cargo test --manifest-path CTCore/Cargo.toml --all-features`
- `cargo test --manifest-path CTCore/Cargo.toml --no-default-features`
- `scripts/smoke-ctcore-swift-binding.sh`
- XcodeBuildMCP `build_sim` for `CraftingTable` on `iPad Pro 13-inch (M5)` succeeded.

Completion:

- Phase 7 is complete for the first iPad CTCore binding slice.
- The completed slice proves the app can embed CTCore and call a feature-gated backend API from Swift.
- Remaining domain-store migrations belong to later phases; they should be sequenced by domain rather than hidden behind a new workspace aggregate.

## Recommended first implementation slice

Do not begin with repo-wide restructuring.

Start with a backend-library spike around portable config and Codex Remote Control Server/Client contract models:

1. create a small backend library boundary in the repo
2. define host config schema without secrets
3. define Codex host config and endpoint model
4. split Codex Remote Control Server and Client as compile-time features
5. add fixture-based parsing/validation tests
6. adapt the current iPad Codex Remote host profile code only after the library boundary proves useful

This is small, reversible, and exercises the cross-platform shape without forcing InKCre or desktop packaging decisions immediately.

## Open decisions before execution

- Backend library language/runtime.
- Whether backend networking is built in or adapter-injected.
- First desktop target for Host Runtime packaging.
- Whether Work Session joins InKCre mapping in the first graph slice.
- Whether current Rust Companion remains a sidecar/helper for the first desktop app slice.
