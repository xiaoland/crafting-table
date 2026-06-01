# Clients

Platform client roots for CT.

- `apple/`: Xcode project, current iPad app, and macOS Host Runtime client target.
- `android/`: Kotlin/Compose Codex Remote control client.
- `windows/`: Rust native Codex Remote desktop Host Runtime client, currently migrating from a legacy Tauri shell.

Keep platform-specific lifecycle, UI, permissions, credentials, packaging, and OS integration here. Keep portable business behavior in `CTCore`.
