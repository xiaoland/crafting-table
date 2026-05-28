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

It should be closer to an app-embedded service/helper than a user-managed standalone daemon.

Current `Companion` has two useful separations:

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

Goal: make Codex Remote Control embeddable into desktop and mobile clients while preserving the host wire contract.

Scope:

- choose first desktop target: macOS or Windows
- keep existing Rust Companion code as the runtime core initially
- package it as an app-supervised helper or embedded service for the desktop CT client
- support login launch / background resident mode
- expose user-visible status, stop/start, logs, and diagnostics
- keep iPad/Android control clients talking to the same or versioned server-owned wire contract

Clarification:

- Login launch, background residency, app window lifecycle, and OS service registration are responsibilities of each platform client adapter.
- Codex Host Runtime should expose embeddable runtime APIs and status contracts. It should not own client lifecycle policy.

Likely first implementation:

- app-supervised sidecar/helper is the most reversible first step.
- deeper in-process embedding can wait until the desktop app stack is proven.

Verification:

- desktop app can start host runtime without terminal
- host runtime starts on login when enabled
- iPad client can connect to the packaged runtime
- runtime survives window close when background residency is enabled
- user can stop it intentionally

Implementation evidence:

- Current `CraftingTable.xcodeproj` still has only an iPad target: `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"` and `TARGETED_DEVICE_FAMILY = 2`.
- Because there is no desktop CT app target yet, this phase starts with an app-supervised host runtime boundary rather than pretending the runtime is already embedded in a macOS UI.
- `CTCore` now includes server-owned host runtime status contract types: `HostRuntimeState`, `HostRuntimeLaunchContext`, and `HostRuntimeStatusResponse`.
- `Companion` depends on `CTCore` with `codex-remote-control-server` enabled for the new host runtime status route.
- `GET /host/runtime` reports process state, PID, bind address, Codex home, and launch context.
- `Companion` is now both a library crate and a thin binary. The library exposes `Config`, `build_router`, `serve`, `serve_with_shutdown`, and `shutdown_signal`.
- `Companion/tests/runtime_embedding.rs` proves a client can build the Codex Remote router in-process without launching the binary.
- `scripts/codex-host-runtime.sh` provides development-only foreground `run`, background `start`/`stop`/`restart`, `status`, and `logs` commands.
- The development sidecar `start` command builds and launches the actual runtime binary instead of backgrounding `cargo run`, so the recorded PID belongs to the served process.
- `.codex/environments/environment.toml` has Codex app actions for starting, stopping, and checking the Codex Host Runtime.

Current limit:

- This now supports an embedded runtime shape and a development sidecar shape. Pairing/auth, packaged helper distribution, in-app macOS controls, Windows service packaging, and mobile client adapter integration are not implemented yet.

Verified:

- `xcodebuild -list -project CraftingTable.xcodeproj` confirmed the current Xcode project has only the `CraftingTable` app target.
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

## Phase 6 - WorkspaceDocument Decomposition

Goal: shrink `WorkspaceDocument` to remaining local-only or compatibility state.

Scope:

- migrate or bridge Goal Forest / Capture / Session durable state to InKCre-backed access
- move host config to portable config file
- keep only runtime-local or migration compatibility state in local app storage

Verification:

- existing local workspace data can be imported or safely ignored according to explicit migration rules
- app can launch with InKCre-backed graph data and portable config
- local-only runtime state resets without losing durable user memory

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
