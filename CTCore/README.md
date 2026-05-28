# CTCore

Feature-gated cross-platform backend library for Crafting Table.

This crate starts small. It should own portable business contracts and validation, while platform clients own UI, filesystem locations, credentials, lifecycle, and permissions.

## Features

- `portable-config`: non-secret host configuration schemas, JSON round-trip, and validation diagnostics.
- `codex-remote-control-server`: Codex Remote Control wire contract models and host-runtime status models owned by the server authority boundary.
- `codex-remote-control-client`: control-client state projection over the server-owned wire contract.
- `inkcre-graph`: reserved for Goal Forest, Capture, and Work Session mapping to InKCre blocks/relations.
- `local-llm-core`: reserved for Local LLM manifest and request/response contracts.

No feature is enabled by default.

## Test

```sh
cargo test --manifest-path CTCore/Cargo.toml --features portable-config
cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-server
cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-client
```
