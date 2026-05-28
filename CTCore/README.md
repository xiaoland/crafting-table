# CTCore

Feature-gated cross-platform backend library for Crafting Table.

This crate starts small. It should own portable business contracts and validation, while platform clients own UI, filesystem locations, credentials, lifecycle, and permissions.

## Features

- `portable-config`: non-secret host configuration schemas, JSON round-trip, and validation diagnostics.
- `codex-remote-control-server`: Codex Remote Control wire contract models and host-runtime status models owned by the server authority boundary.
- `codex-remote-control-client`: control-client state projection over the server-owned wire contract.
- `inkcre-graph`: Goal Forest, Capture, Work Session, and Remote Continuity mapping to InKCre block/relation graph forms.
- `local-llm-core`: reserved for Local LLM manifest and request/response contracts.

No feature is enabled by default.

## InKCre Graph API

With `inkcre-graph`, CTCore owns Crafting Table graph storage semantics while clients provide the transport:

- `InKCreGraphStore`: adapter trait for `PUT /graph`, recent blocks, relations by block, and block updates.
- `CraftingTableInKCreApi`: client-facing API for saving/updating Goal Nodes, Work Sessions, Captures, Goal Forest edges, and loading Goal Forest / Capture projections.

This keeps HTTP/auth/base URL decisions in platform clients without making SwiftUI/Kotlin/UI code own graph semantics.

## Test

```sh
cargo test --manifest-path CTCore/Cargo.toml --features portable-config
cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-server
cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-client
cargo test --manifest-path CTCore/Cargo.toml --features inkcre-graph
```
