# Windows Client

Target stack: Rust native GUI with GPUI as the first candidate.

First scope: Codex Remote desktop client with in-process CTCore Host Runtime.

The native Rust client depends on `CTCore` directly with `codex-remote-control-server`. Rust owns CTCore integration, Host Runtime state, Codex app-server adaptation, and Windows-specific runtime adapters.

The previous Tauri client remains in-tree during migration as a reference and fallback. Do not remove it until the native client proves Host Runtime parity.

## Development

Native GPUI client:

```sh
scripts/run-windows-client.sh --check
scripts/run-windows-client.sh --service-check
scripts/run-windows-client.sh --service-smoke
scripts/run-windows-client.sh --dev
```

On Windows PowerShell:

```powershell
.\scripts\run-windows-client.ps1 check
.\scripts\run-windows-client.ps1 service-check
.\scripts\run-windows-client.ps1 service-smoke
.\scripts\run-windows-client.ps1 dev
```

Legacy Tauri client:

```sh
scripts/run-windows-client.sh --legacy-dev
```

On Windows PowerShell:

```powershell
.\scripts\run-windows-client.ps1 legacy-dev
```

The first native Windows surface starts and stops the CTCore Codex Remote Server and shows runtime status, endpoint hints, Codex home, and recent events.

## Verification Notes

The GPUI crate may require platform graphics toolchains even for local checks. macOS checks require the Metal toolchain; Windows checks should be treated as the migration gate for GPUI viability.

`service-check` verifies the direct CTCore Host Runtime service without building GPUI. Use it when the local machine cannot build GPUI's platform graphics layer.

`service-smoke` starts the direct CTCore Host Runtime service, verifies `/health`, and stops the service without opening the GPUI window.

Repo-level native check:

```sh
scripts/run-windows-client.sh --check
```

On Windows PowerShell:

```powershell
.\scripts\run-windows-client.ps1 check
```
