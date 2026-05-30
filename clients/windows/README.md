# Windows Client

Target stack: Rust + Tauri.

First scope: Codex Remote desktop client with in-process CTCore Host Runtime.

The Tauri frontend should stay thin. Rust owns CTCore integration, Host Runtime state, Codex app-server adaptation, and Windows-specific runtime adapters.
