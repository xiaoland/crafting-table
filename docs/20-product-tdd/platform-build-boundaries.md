# Platform build boundaries

## CTCore Apple artifact

- producer: CTCore
  consumer: iPad and macOS client targets
  artifact contract: `scripts/build-ctcore-apple.sh` regenerates UniFFI Swift bindings, builds CTCore for iOS device, iOS simulator, and macOS, and packages those static libraries into `clients/apple/iPad/Generated/CTCore/CTCore.xcframework`.
  source boundary: generated Swift binding source is checked in under `clients/apple/iPad/Generated/CTCore/`; generated binary artifacts are local build outputs and stay ignored by git.
  feature boundary: iPad slices are built with `swift-bindings`; the macOS slice is built with `swift-bindings,codex-remote-control-server` so the macOS client can start CTCore Codex Remote Server in-process.

- build-system rule: Apple Xcode targets link `CTCore.xcframework` through their Frameworks phases.
  required ordering: targets keep a `Build CTCore Apple Artifact` run script phase before Swift compilation so a fresh checkout can build without a preexisting XCFramework.
  dependency constraint: do not declare the generated `CTCore.xcframework` as a same-target run script output while the same target also links it in Frameworks. Xcode treats `ProcessXCFramework` as consuming that directory and creates a target dependency cycle.
  current tradeoff: the CTCore artifact script is marked to run every iPad build. If CTCore packaging later moves to a separate build target, Swift package, or CI-produced artifact, explicit output dependencies can be restored there instead.

## Windows native client CTCore boundary

- producer: CTCore
  consumer: Windows native Rust client
  source contract: the Windows native client depends on `CTCore` as a Rust path dependency with the `codex-remote-control-server` feature. It starts the in-process Codex Remote Server through the Rust server runtime API instead of a Tauri command bridge, C ABI DLL, UniFFI C# binding, or sidecar process.
  artifact contract: the first Path C slice builds the Windows app and CTCore in one Cargo dependency graph. No generated CTCore binary artifact is checked in for Windows.
  feature boundary: Windows uses `codex-remote-control-server` for Host Runtime start/stop/status/logs. Broader Codex Remote control UI, tray/background residency, launch-at-login, credentials, installer/update flow, and arm64 builds remain outside the first native slice.

- build-system rule: `clients/windows/native/` is the admitted Rust native client root during migration.
  migration constraint: keep the existing Tauri client available until the GPUI/native Rust client proves Host Runtime parity with repeatable checks.
  framework constraint: GPUI is the first Rust native GUI candidate. Because GPUI is pre-1.0 and Windows maturity must be proven by the app, migration starts with a small feasibility spike before retiring Tauri.
