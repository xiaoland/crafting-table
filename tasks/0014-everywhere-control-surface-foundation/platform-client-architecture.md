# Platform client architecture

## Intent

Capture the high-level technical plan for macOS, Windows, and Android clients before implementation starts.

Current scope is intentionally narrow:

- macOS: Codex Remote desktop client and in-process Codex Host Runtime.
- Windows: Codex Remote desktop client and in-process Codex Host Runtime.
- Android: Codex Remote control client.

Do not use this slice to introduce Goal Forest, Capture, Session, Local LLM, or full CT feature parity on non-iPad platforms.

## Shared backend direction

CTCore should become the shared backend library for both control and host roles.

CTCore is not a schema-only crate. It is expected to contain cross-platform implementations for shared product capabilities when those implementations are not platform-specific:

- Goal Forest graph semantics and InKCre mapping API
- Capture intake and InKCre mapping API
- Session graph/status semantics
- Codex Remote Control client projection and request helpers
- Codex Remote Control server contract and in-process host runtime
- Local LLM portable core such as manifest, readiness, and protocol contracts

Platform clients still own OS adapters: UI, window lifecycle, login/autostart, background residency, permissions, credential stores, filesystem locations, platform networking permissions, camera/media access, notifications, and packaging.

Relevant feature split:

- `codex-remote-control-server`: server-owned wire contract, host runtime state, codex-app server adaptation, pairing/auth vocabulary, and in-process server runtime API.
- `codex-remote-control-client`: control-client projection, request helpers, reconnect semantics, and stream state normalization.
- `portable-config`: non-secret host and endpoint config shared by all clients that need saved host metadata.

The embedded Codex Host Runtime should be an in-process library mode, not a bundled sidecar. A standalone binary can remain useful for development smoke tests and diagnostics, but it should not be the product embedding model.

## Target topology

```text
macOS SwiftUI app
  - SwiftUI/AppKit UI adapter
  - launch-at-login and background residency adapter
  - Keychain/filesystem/network permissions
  - CTCore Swift binding
    - codex-remote-control-server
    - codex-remote-control-client, if local control UI is needed
    - portable-config

Windows app
  - Tauri UI shell
  - Rust backend loaded in-process
  - Windows startup/tray/background adapter
  - Windows credential/filesystem/network adapters
  - CTCore native Rust surface
    - codex-remote-control-server
    - codex-remote-control-client, if local control UI is needed
    - portable-config

Android Kotlin app
  - Jetpack Compose UI adapter
  - Android Keystore/filesystem/network permissions
  - CTCore Kotlin binding
    - codex-remote-control-client
    - portable-config, if saved host metadata is local
```

## macOS client

Recommended stack: SwiftUI with narrow AppKit interop.

Why:

- The iPad CTCore Swift binding path is already proven through UniFFI and an XCFramework.
- macOS needs native lifecycle surfaces: login item, menu bar or agent-like residency, windows/settings, Keychain, local network prompts, and background status.
- SwiftUI keeps the Apple clients close without forcing iPad and macOS to share UI code prematurely.

First target shape:

- `CraftingTableMac` now exists as the first macOS app target
- reuse CTCore Swift binding packaging, extended for macOS slices
- embed Codex Host Runtime through CTCore in-process API
- make launch-at-login and background residency macOS adapter responsibilities
- make Codex Remote Server bind scope a macOS client setting, with local-only and trusted local-network modes
- keep the initial target limited to Host Runtime status, controls, and event stream visibility

Open decisions:

- whether the first macOS app is menu-bar-first or window-first
- whether local control UI is included in the first macOS build or only host status/settings

## Windows client

Selected stack: Rust native GUI, with GPUI as the first candidate.

This supersedes the earlier Rust + Tauri direction. The product scope is unchanged: Windows remains a Codex Remote desktop client with in-process Codex Host Runtime.

Why:

- CTCore and Codex Host Runtime are Rust-first, so the host runtime can stay native and in-process without a C ABI or P/Invoke layer.
- The first Windows surface only needs a small utility window: host status, bind mode, endpoint hints, Codex home, start/stop/refresh, and logs.
- Avoiding a WebView shell better matches the native-client direction while keeping implementation small.
- The current Tauri backend already proves the direct Rust CTCore integration shape.

Risks:

- GPUI is pre-1.0 and its Windows maturity must be proven by a spike.
- GPUI is a native Rust/GPU UI, not WinUI system controls.
- Windows-specific background behavior, accessibility, packaging, tray, and launch-at-login still need native adapter work after the first slice.

First target shape:

- a GPUI utility shell for Host Runtime status, logs, start/stop, refresh, and bind mode
- a Rust `HostRuntimeService` that owns the in-process CTCore server task
- Windows startup/tray/background behavior deferred until Host Runtime parity is proven

Rejected for now:

- Tauri as the product direction. It remains in-tree only as a migration fallback until GPUI parity is verified.
- PySide as the first Windows direction. It is viable for a thin UI, but packaging Python/Qt/Rust adds more moving pieces than the selected Rust-native path.
- WinUI/.NET as the first direction. It remains the fallback if GPUI fails the Windows feasibility spike.

Open decisions:

- whether GPUI remains acceptable after the Windows feasibility spike
- packaging target and update path
- whether Windows needs any host-local Codex adapter beyond codex-app server process management

## Android client

Recommended stack: Kotlin with Jetpack Compose.

Why:

- Android is a control client in the first direction, not a host runtime.
- UniFFI can generate Kotlin bindings from CTCore, matching the Swift binding strategy better than a JSON shell bridge.
- Compose gives a native Android UI without forcing a shared web UI layer.

First target shape:

- Codex Remote host list and connection setup
- thread list/detail and turn control UI
- pairing/auth flow against desktop hosts after the manual URL slice
- CTCore `codex-remote-control-client` and optional `portable-config` through Kotlin bindings

Open decisions:

- local Gradle module layout for generated UniFFI bindings
- whether Android stores portable config locally or relies on user-provided sync/file import later
- network discovery versus manual host URL entry for the first build

## Repository structure hypothesis

Avoid a large repo rename before the first non-iPad client compiles.

Candidate target structure:

```text
CTCore/
  Cargo.toml
  src/
  bindings/
    apple/
    android/

clients/
  apple/
    CraftingTable.xcodeproj
    iPad/
    macOS/
    SharedSwift/
  android/
    settings.gradle.kts
    app/
    ctcore-bindings/
  windows/
    native/
    src-tauri/

scripts/
  build-ctcore-apple.sh
  build-ctcore-android.sh
  run-windows-client.sh
```

Near-term structure:

- Apple project structure has moved to `clients/apple/`, with the existing iPad source under `clients/apple/iPad/`.
- Android client root now has a Gradle Kotlin DSL project with `app` and `ctcore-bindings` modules.
- Android currently implements manual Codex Remote host URL entry, health check, thread list/detail, and turn submission.
- Android routes Codex Remote response decoding through CTCore UniFFI helpers, keeping the UI off the server-owned wire JSON details.
- Android generated UniFFI Kotlin binding source is checked in; generated Android native libraries are ignored local build artifacts.
- Windows now has a Rust native GPUI skeleton under `clients/windows/native/`, while the earlier Tauri v2 app remains temporarily under `clients/windows/src-tauri/` as migration fallback.
- `CraftingTableMac` now exists under `clients/apple/macOS/`
- macOS now starts the CTCore Codex Remote Server in-process through a narrow C ABI.
- the first Windows native surface is intentionally limited to Codex Remote Server status and controls.
- the old host-side service crate has been removed; Codex Remote Server implementation lives in CTCore
- keep direct server process launchers out of product client flows; development scripts may present CTCore smoke commands as Dev Codex Host Runtime
- add only the client folders needed by the first executable platform slice

## Build workflow hypothesis

Apple:

- Rust builds CTCore for required Apple slices.
- A script packages `CTCore.xcframework`.
- Xcode links the XCFramework.
- Generated Swift binding source stays checked in while the binding pipeline is young.

Android:

- Rust builds Android ABI libraries.
- UniFFI generates Kotlin binding source.
- Gradle packages bindings and native libraries into a local module or AAR.
- Android Studio builds the app normally after the artifact step.
- `scripts/build-ctcore-android.sh` regenerates Kotlin binding source and builds local `libct_core.so` artifacts when an Android NDK is installed.

Icon assets:

- iPad `AppIcon.png` is the visual source for platform client icons.
- macOS has a generated `AppIcon.appiconset` derived from the iPad icon.
- Android launcher `mipmap-*` icons are derived from the iPad icon.
- Windows `icon.ico` is derived from the iPad icon.

Windows:

- Cargo builds the Rust native Windows shell and CTCore in one dependency graph.
- CTCore is consumed as a Rust crate from the native Windows client.
- A service check verifies the Rust Host Runtime service can compile without building GPUI; a full Windows check must prove GPUI window viability before Tauri retirement.

## Android binding generation options

| Option | Pros | Cons | Best fit |
|---|---|---|---|
| Check generated Kotlin into git | Deterministic IDE import; easier review of binding API drift; app can build after Rust artifacts exist without requiring every Gradle sync to run UniFFI generation | Generated churn in reviews; risk of stale generated source if script discipline slips; repo noise grows as API expands | Early integration, small binding surface, unstable build pipeline |
| Generate Kotlin during Gradle build | Single source of truth in Rust; fewer generated files in git; harder to forget regeneration | Gradle build becomes dependent on Rust toolchain and UniFFI setup; Android Studio sync can be slower/flakier; build failures are harder for Android-only iteration | Mature pipeline, CI-controlled environment, stable developer setup |
| Commit generated Kotlin for releases only | Keeps main worktree lighter while preserving release artifacts | Adds branching/release procedure complexity; weakens day-to-day reproducibility | Not recommended for this stage |

Decision: check generated Kotlin in for the first Android slice, matching the current Swift binding approach. Revisit after CI can build Android CTCore artifacts reliably.

## Decisions to make before implementation

1. Apple migration shape before adding macOS target.
2. GPUI viability and packaging path for Windows.
3. Android Gradle module layout for checked-in generated Kotlin bindings.
4. Exact async event stream API shape for Codex Host Runtime.
5. Pairing/auth first slice: manual token entry, QR pairing, local network discovery, or deferred placeholder.
