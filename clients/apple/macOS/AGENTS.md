# Crafting Table macOS Client Guide

Read this file when working in `clients/apple/macOS/`.

## Scope

This target is the macOS Codex Host Runtime client. It is not a full Crafting Table desktop port.

Keep the first slices focused on:

- Host Runtime status
- start/stop controls
- event stream visibility
- desktop lifecycle adapters such as login item, menu bar, and background residency when admitted

## Boundaries

- Keep portable runtime semantics in `CTCore`.
- Keep macOS lifecycle, windows, menus, Keychain, and permissions in this target.
- Do not import iPad-only features, Local LLM UI, Goal Forest, Capture, or Session surfaces into the macOS target unless the product scope explicitly changes.
