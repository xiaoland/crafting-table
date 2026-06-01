# Task 0018 - Windows native client CTCore integration

## Objective & Hypothesis

Replace the current Windows Client direction, which is based on Tauri, with a native Windows client direction while preserving the Codex Remote Host Runtime product boundary.

Hypothesis: Windows can move to a Rust native GUI client, with GPUI as the first candidate, without weakening CTCore ownership if the app depends on CTCore directly as a Rust crate for the in-process Codex Remote Server. This keeps the first Windows slice small, avoids a DLL/PInvoke binding layer, and lets CTCore continue to own Codex Remote server contract normalization and host-local Codex process adaptation.

## Input Type

Constraint.

The product behavior stays the same for this slice: Windows remains a Codex Remote desktop host/client surface with in-process Host Runtime. The technical constraint changes: the Windows app should be native instead of Tauri-based, with the core question being how to connect to CTCore.

## Active Mode

Explore -> Solidify.

This packet is not permission to implement. It frames the decision and implementation sequence. Actual source migration starts only after explicit user approval.

## Governing Anchors

- `docs/00-meta/input-constraint.md`
- `docs/00-meta/mode-a-explore.md`
- `docs/00-meta/mode-b-solidify.md`
- `docs/20-product-tdd/unit-topology.md` - Codex Remote Server ownership remains in CTCore.
- `docs/20-product-tdd/cross-unit-contracts.md` - CTCore exposes the CraftingTable-owned Codex Remote server contract.
- `docs/20-product-tdd/platform-build-boundaries.md` - Apple CTCore artifact boundary exists; Windows artifact boundary is not yet durable.
- `tasks/0014-everywhere-control-surface-foundation/platform-client-architecture.md` - Previous Windows stack selection was Rust + Tauri and must be superseded explicitly.
- `clients/windows/README.md` - Current Windows Client says Rust + Tauri.
- `clients/windows/src-tauri/src/main.rs` - Current Tauri backend embeds CTCore through Rust crate dependency.
- `CTCore/src/codex_remote_control/server/runtime.rs` - Existing server runtime surface used by the current Tauri backend.
- `CTCore/src/codex_remote_control/server/ffi.rs` - Existing C ABI remains useful reference material, but Path C should not need it for the first slice.
- `tasks/0018-windows-native-client-ctcore/build-debug-assessment.md` - Build and debugging comparison across Path A, Path B, and Path C.

## Guardrails Touched

- Do not change the Codex Remote product promise just to justify a platform rewrite.
- Keep CTCore as the owner of Codex Remote server protocol normalization and codex-app server churn insulation.
- Keep Windows-specific lifecycle, UI, permissions, credentials, autostart, tray/background behavior, filesystem locations, packaging, and installer/update choices in the Windows client.
- Do not introduce UniFFI C#, P/Invoke, or a broad generated binding layer for the first Path C slice.
- Do not keep Tauri as a hidden runtime dependency after the migration is declared complete.
- Do not remove the current Tauri client until native build, CTCore start/stop, and smoke checks are proven.
- Keep the first native Windows slice equivalent to the existing Host Runtime control surface before expanding into richer Codex Remote control UI.

## Current Evidence

- Current Windows Client documentation names `Rust + Tauri` as the target stack.
- Current Windows Client uses Vite TypeScript for UI and Tauri commands for `runtime_status`, `runtime_set_bind_mode`, `runtime_start`, and `runtime_stop`.
- Current Tauri backend links `ct-core` as a Rust crate with the `codex-remote-control-server` feature and starts CTCore in-process with `serve_listener_with_shutdown`.
- CTCore direct Rust integration is already proven by the current Tauri backend, even though the UI shell is being rejected.
- CTCore also exposes a minimal C ABI, but Path C avoids that extra boundary unless future non-Rust Windows components require it.
- Existing durable platform build boundary only documents Apple CTCore artifact packaging. Windows needs a comparable source/build boundary for the native Rust app before the Tauri direction is retired.
- GPUI can plausibly cover the first requested UI scope: a utility window with a few controls and bounded logs. Its framework maturity and Windows behavior still need a spike before deeper migration.

## Temporary Assumptions

- "Native Windows" now means native binary without WebView/Tauri for this task; GPUI is accepted as the first Rust native GUI candidate even though it is not WinUI-native controls.
- The first native Windows slice should be functionally equivalent to the current Tauri Host Runtime surface: bind mode, endpoint hints, Codex home, start/stop, status, and recent runtime events.
- CTCore should be linked as an in-process native library, not launched as a sidecar product server. A standalone CTCore server binary can remain a smoke-test and diagnostic tool.
- CTCore should be used as a direct Rust crate dependency with `codex-remote-control-server`.
- The app can initially target x64 Windows with MSVC Rust toolchain; arm64 can be added after the x64 path is proven.
- The Tauri client can remain in-tree during migration as a reference and fallback until native parity is verified.

## Working Direction

Recommended stack:

- Windows UI/runtime: Rust native GUI with GPUI as the first candidate.
- CTCore integration: direct `ct-core` path dependency with `codex-remote-control-server`.
- Windows app facade: a Rust `HostRuntimeService` that owns the listener task, shutdown sender, runtime state, and bounded event history.
- App state: GPUI-visible state mirrors the current runtime state machine and events, not raw CTCore internals.
- Build/debug sequencing: prove GPUI window/control/log viability first, then wire direct CTCore runtime start/stop.

Rejected or deferred:

- Tauri as product direction: too much web shell for a client that should feel native and own Windows lifecycle surfaces directly.
- WinUI 3 + C# as the first rewrite: still viable, but no longer selected because the first UI scope is small and direct Rust CTCore integration is simpler.
- C++/WinRT as the first native rewrite: native but higher implementation cost than this Host Runtime shell deserves.
- UniFFI C# or P/Invoke as the first binding path: not needed for Path C.
- Sidecar server as product embedding: useful for smoke tests, weaker for lifecycle ownership than in-process CTCore.

## Promotion Candidates

Promote only after review or implementation proof:

- `docs/20-product-tdd/platform-build-boundaries.md`: add a Windows Rust-native client boundary once the native direction is accepted.
- `clients/README.md`: change Windows from Rust + Tauri to Rust native GUI with direct CTCore integration.
- `tasks/0014-everywhere-control-surface-foundation/platform-client-architecture.md`: mark the earlier Windows Tauri choice as superseded by Task 0018 or update the task note if it remains active reference material.
- `clients/windows/README.md`: update only when implementation starts or the native project is admitted.

## Verification

Planning verification:

- Task packet states objective, hypothesis, guardrails, current evidence, assumptions, and verification.
- Implementation plan is split into reversible phases with a clear start gate before source edits.
- CTCore connection strategy is explicit and does not require Tauri.

Implementation verification, after approval:

- `cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-server`
- GPUI native Windows app compiles and opens a utility window.
- Start/stop Host Runtime works through direct Rust CTCore integration.
- `GET /health` succeeds against the selected bind address while runtime is running.
- Stop shuts down the server task and frees the port.
- Tauri client is not removed until native parity has a repeatable check.
