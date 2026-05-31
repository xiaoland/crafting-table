# Windows Client

Target stack: Rust + Tauri.

First scope: Codex Remote desktop client with in-process CTCore Host Runtime.

The Tauri frontend should stay thin. Rust owns CTCore integration, Host Runtime state, Codex app-server adaptation, and Windows-specific runtime adapters.

## Development

```sh
pnpm install
pnpm tauri:dev
```

The first Windows surface only starts and stops the CTCore Codex Remote Server.

Repo-level check:

```sh
scripts/run-windows-client.sh --check
```

On Windows PowerShell:

```powershell
.\scripts\run-windows-client.ps1 check
```
