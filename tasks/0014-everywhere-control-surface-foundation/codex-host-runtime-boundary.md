# Codex Host Runtime boundary

## Current repo fact

Crafting Table now has an Apple project with iPad and macOS targets.

The Codex Remote Server implementation has moved into `CTCore/src/codex_remote_control/server/`. The old host-side service crate has been removed rather than retained as a thin development entry point.

## Unit boundary

Codex Host Runtime is the controlled-endpoint unit for Codex Remote Control.

It owns:

- the HTTP/WebSocket server process
- codex-app server adaptation
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

The product process shape is CTCore embedded in-process by a platform client.

The library API exposes:

- `Config`
- `build_router(config)`
- `serve(config)`
- `serve_with_shutdown(config, shutdown)`

Desktop clients should use the CTCore library surface directly for an in-process runtime. Mobile clients should consume the server-owned contract through their own networking adapters.

The old development Host Runtime script has been removed. The macOS client is the first executable embedding path for starting CTCore Codex Remote Server in-process.

Login launch, window-close residency, OS service registration, and equivalent lifecycle controls are client adapter responsibilities, not Host Runtime business responsibilities.

## Status route

`GET /host/runtime` is the runtime status contract for the host unit.

It currently reports:

- `state`
- `pid`
- `bind`
- `codex_home`
- `launch_context`

The route uses `CTCore` contract types under `codex-remote-control-server`.

## Known limits

- No packaged helper binary is produced yet.
- Windows service/task registration is not implemented.
- Pairing and authorization are still placeholders at the architecture level.
- LAN binding remains an explicit configuration choice; the default remains loopback.
