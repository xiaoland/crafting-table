# (xiaoland's) Crafting Table

Crafting Table is an early-stage, iPad-first personal productivity tool: a small BusyBox-style control surface for the recurring pieces of personal technical work. It is built around a lightweight "crafting table" loop: regain context, continue a work session, capture loose material, and use nearby tools such as remote access, Codex handoff, and local model serving without turning the app into a generic dashboard or project-management system.

Short form: `Crafting Table`
Abbreviation: `CT`
Current app version: `0.1.0`

This repository is personal/internal software. It is useful as a working app foundation and technical playground for a tech user who wants their own productivity surface, but it is not packaged as a consumer product yet.

## What It Does

- `Goal Forest`: top-level orientation surface for goals, sessions, and captures.
- `Work Session`: create, resume, pause, and finish active work while keeping nearby context visible.
- `Quick Capture`: save material without forcing full classification at capture time.
- `Remote Control`: host profiles and terminal/file-transfer-shaped workflow placeholders connected to sessions.
- `Codex Remote`: continue Codex threads through a reachable host-side Host Runtime.
- `Local LLM`: manage GGUF models, run a foreground LAN HTTP server, and use a small local chat surface.
- `About`: app identity, version, and generated logo preview.

The current scope intentionally excludes GUI remote desktop, broad third-party integrations, autonomous workflow restructuring, background local model serving, and rich planner behavior.

## Repository Layout

```text
clients/apple/iPad/         SwiftUI iPad app source
clients/apple/macOS/        SwiftUI macOS Host Runtime client source
clients/apple/CraftingTable.xcodeproj/
                            Apple Xcode project
clients/android/            Future Kotlin/Compose Codex Remote control client
clients/windows/            Future Rust + Tauri Codex Remote desktop client
CTCore/                     Feature-gated Rust backend library for portable CT capabilities
Companion/                  Legacy Codex Host Runtime source and development harness
Companion/scouts/macos/     macOS Desktop Scout helper
Companion/scouts/windows/   Windows Scout prototype
ThirdParty/                 Local Swift package wrappers, including llama.cpp binary package
scripts/                    Local launch, smoke, and logo-generation helpers
docs/                       Sparse product and technical truth
tasks/                      Volatile task packets and implementation notes
```

## Requirements

- macOS with Xcode installed.
- iOS Simulator or a connected iPad.
- Swift toolchain available through Xcode.
- Rust toolchain for CTCore and the interim Host Runtime development harness.
- Network access for first-time package and logo asset downloads.
- Optional: Codex Desktop/CLI on the host when using `Codex Remote`.

The iOS app target is `iOS 17.0+`. Recent local builds have been run with Xcode 26.x.

## Build The App

Build for a generic iOS Simulator destination:

```sh
xcodebuild \
  -project clients/apple/CraftingTable.xcodeproj \
  -scheme CraftingTable \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData \
  build
```

Launch on an available iPad simulator:

```sh
./scripts/launch-ipad-simulator.sh
```

By default this prefers `iPad Pro 11-inch (M4)`. Override the simulator name with:

```sh
SIMULATOR_NAME='iPad Pro 13-inch (M5)' ./scripts/launch-ipad-simulator.sh
```

Build, install, and launch on a connected iPad:

```sh
./scripts/launch-ipad-device.sh
```

If Xcode cannot infer your team, pass it explicitly:

```sh
DEVELOPMENT_TEAM='<team-id>' ./scripts/launch-ipad-device.sh
```

Build and launch the macOS Host Runtime client:

```sh
./scripts/run-macos-client.sh
```

## App Icon And Logo

The app can generate its icon/logo at build time from:

- the vanilla Minecraft `crafting_table_top.png` texture, fetched from Mojang's official version metadata/client jar;
- optionally, the front of a Minecraft skin head resolved from a Minecraft username.

Local logo configuration is intentionally untracked. To enable the Minecraft skin variant:

```sh
cp logo.local.json.example logo.local.json
```

Then edit `logo.local.json`:

```json
{
  "mode": "minecraftSkin",
  "minecraftUsername": "your_username",
  "minecraftVersion": "latestRelease"
}
```

If `logo.local.json` is missing, or if `mode` is not `minecraftSkin`, the build still succeeds and generates a logo without a skin head. Generated PNGs and cached Minecraft assets live under ignored paths.

You can run the generator directly:

```sh
xcrun --sdk macosx swift scripts/generate-logo-assets.swift
```

Useful output paths:

```text
clients/apple/iPad/Assets.xcassets/AppLogo.imageset/AppLogo.png
clients/apple/iPad/Assets.xcassets/AppIcon.appiconset/AppIcon.png
.build/logo-assets/previews/app-icon-mask-preview.png
```

## Codex Host Runtime

`Codex Remote` talks to a host-side Host Runtime. The product direction is in-process embedding inside desktop clients; the standalone script remains a development harness while the runtime code moves into CTCore.

Build and launch the first macOS client:

```sh
./scripts/run-macos-client.sh
```

Default endpoint:

```text
http://127.0.0.1:3765
```

Run the development Host Runtime harness in the background:

```sh
./scripts/codex-host-runtime.sh start
./scripts/codex-host-runtime.sh status
./scripts/codex-host-runtime.sh stop
```

For iPad LAN testing:

```sh
CODEX_HOST_RUNTIME_BIND=0.0.0.0:3765 ./scripts/codex-host-runtime.sh start
```

Use a LAN URL such as:

```text
http://<mac-lan-ip>:3765
```

Use that endpoint in the app's `Codex Remote` screen.

Smoke a running development Host Runtime:

```sh
./scripts/codex-host-runtime.sh smoke
```

Run one macOS Desktop Scout snapshot:

```sh
./scripts/codex-remote-companion.sh scout
```

The legacy runtime source also has its own README at `Companion/README.md`.

## Local LLM

The `Local LLM` surface is a foreground-only LAN server for local inference. It supports:

- GGUF model records from Hugging Face or custom sources;
- download, SHA-256 verification, and activation state;
- a bearer-token protected HTTP server on port `8787` by default;
- a small local chat panel;
- an OpenAI Responses-shaped endpoint at `POST /v1/responses`.

The server is meant for trusted LAN use while the app is open. It is not a background daemon and does not aim for full OpenAI API compatibility.

## Useful Development Commands

Build the iOS app:

```sh
xcodebuild -project clients/apple/CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DerivedData build
```

Run the interim Host Runtime service directly:

```sh
cargo run --manifest-path Companion/Cargo.toml
```

Test Companion:

```sh
cargo test --manifest-path Companion/Cargo.toml
```

Test CTCore portable config:

```sh
cargo test --manifest-path CTCore/Cargo.toml --features portable-config
```

Format Companion:

```sh
cargo fmt --manifest-path Companion/Cargo.toml
```

Codex App local environment actions are declared in:

```text
.codex/environments/environment.toml
```

## Current Boundaries

Crafting Table is still a foundation repo. The durable product truth lives in `docs/10-prd/`; cross-unit technical truth lives in `docs/20-product-tdd/`; task-local exploration and implementation notes live in `tasks/`.

When contributing, keep changes small, reversible, and honest. Prefer native SwiftUI patterns, avoid speculative architecture, and keep unfinished surfaces visibly unfinished.

## License

No license has been declared yet.
