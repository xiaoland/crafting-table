# Clients

Platform client roots for CT.

- `apple/`: Xcode project, current iPad app, and future macOS app target.
- `android/`: future Kotlin/Compose Codex Remote control client.
- `windows/`: future Rust + Tauri Codex Remote desktop client.

Keep platform-specific lifecycle, UI, permissions, credentials, packaging, and OS integration here. Keep portable business behavior in `CTCore`.
