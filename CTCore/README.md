# CTCore

Feature-gated cross-platform backend library for Crafting Table.

This crate starts small. It should own portable business contracts and validation, while platform clients own UI, filesystem locations, credentials, lifecycle, and permissions.

## Features

- `portable-config`: non-secret host configuration schemas, JSON round-trip, and validation diagnostics.
- `codex-remote-control-server`: Codex Remote Control wire contract models, host-runtime status models, and the in-process Host Runtime event API owned by the server authority boundary.
- `codex-remote-control-client`: control-client state projection over the server-owned wire contract.
- `inkcre-graph`: Goal Forest, Capture, Work Session, and Remote Continuity mapping to InKCre block/relation graph forms.
- `local-llm-core`: Local LLM manifest schema, readiness rules, service states, and minimal OpenAI-compatible request/response contracts.
- `swift-bindings`: UniFFI binding facade for iPad Swift clients, currently exposing portable config decode/encode/validation.

No feature is enabled by default.

## InKCre Graph API

With `inkcre-graph`, CTCore owns Crafting Table graph storage semantics while clients provide the transport:

- `InKCreGraphStore`: adapter trait for `PUT /graph`, recent blocks, relations by block, and block updates.
- `CraftingTableInKCreApi`: client-facing API for saving/updating Goal Nodes, Work Sessions, Captures, Goal Forest edges, and loading Goal Forest / Capture projections.

This keeps HTTP/auth/base URL decisions in platform clients without making SwiftUI/Kotlin/UI code own graph semantics.

## Codex Host Runtime API

With `codex-remote-control-server`, CTCore exposes an in-process Host Runtime API shape:

- `HostRuntimeHandle`: readable status/state access and event subscription.
- `HostRuntimeEventBus`: broadcast event delivery for platform adapters.
- `HostRuntimeEventReceiver`: async receiver for runtime status, server bind, control-client connection, log, and error events.

Desktop clients own launch-at-login, background residency, windows/tray/menu bar, credentials, and filesystem paths. CTCore owns the runtime contract vocabulary and event stream shape.

## Test

```sh
cargo test --manifest-path CTCore/Cargo.toml --features portable-config
cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-server
cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-client
cargo test --manifest-path CTCore/Cargo.toml --features inkcre-graph
cargo test --manifest-path CTCore/Cargo.toml --features local-llm-core
cargo test --manifest-path CTCore/Cargo.toml --features swift-bindings
```

## iOS Binding

```sh
scripts/build-ctcore-ios.sh
scripts/smoke-ctcore-swift-binding.sh
```

The script regenerates UniFFI Swift bindings and builds the local `CTCore.xcframework` used by the iPad target.
The smoke script compiles the generated Swift binding against CTCore and verifies portable config validation plus JSON round-trip behavior.
