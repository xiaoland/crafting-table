# Codex Host Runtime boundary

## Current repo fact

Crafting Table does not currently have a desktop app target.

`clients/apple/CraftingTable.xcodeproj` has one app target, `CraftingTable`, configured for `iphoneos iphonesimulator` with `TARGETED_DEVICE_FAMILY = 2`.

That means Phase 3 cannot honestly implement an in-app macOS host runtime UI yet. The first reversible slice is to turn the existing Companion into a host runtime unit that can be supervised by a future desktop app or by macOS launchd during development.

## Unit boundary

Codex Host Runtime is the controlled-endpoint unit for Codex Remote Control.

It owns:

- the HTTP/WebSocket server process
- Codex app-server adaptation
- Desktop Scout invocation
- host-local Codex configuration
- runtime status reporting
- the server-owned wire contract exposed to control clients

It does not own:

- iPad/Android control UI
- portable host config file storage location
- credential secrets
- macOS app window lifecycle
- login launch and background residency policy
- packaged helper registration
- final pairing and authorization UX

## First process shape

The current process shape can be either an embedded library runtime or an app-supervised sidecar.

The library API exposes:

- `Config`
- `build_router(config)`
- `serve(config)`
- `serve_with_shutdown(config, shutdown)`

Desktop clients can use the library directly for an in-process runtime or wrap the binary as a supervised sidecar. Mobile clients should consume the server-owned contract through their own networking adapters.

During development, `scripts/codex-host-runtime.sh` is a convenience sidecar boundary:

- `run`: foreground runtime process
- `start`: background runtime for local development
- `stop`: intentional stop of the dev sidecar
- `status`: process and `/host/runtime` status

This gives future desktop clients a concrete command boundary to replace or wrap while preserving the same runtime contract. It also removes the need for a user-managed terminal in development.

Login launch, window-close residency, OS service registration, and equivalent lifecycle controls are client adapter responsibilities, not Host Runtime business responsibilities.

## Status route

`GET /host/runtime` is the runtime status contract for the host unit.

It currently reports:

- `state`
- `pid`
- `bind`
- `codex_home`
- `launch_context`

The route uses `CTCore` contract types under `codex-remote-control-server`, so the server-owned wire contract starts moving out of ad hoc Companion-only models.

## Known limits

- No desktop CT app target exists yet.
- No packaged helper binary is produced yet.
- Windows service/task registration is not implemented.
- Pairing and authorization are still placeholders at the architecture level.
- LAN binding remains an explicit configuration choice; the default remains loopback.
