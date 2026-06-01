# Implementation plan

## Start Gate

Do not start source migration until the user explicitly approves implementation.

Path C is selected:

- Windows app stack: Rust native GUI, with GPUI as the preferred first candidate.
- CTCore integration: direct Rust crate dependency, not `ct_core.dll`, P/Invoke, UniFFI C#, or sidecar process.
- First architecture target: Windows x64 with Rust MSVC toolchain.
- Migration policy: keep current Tauri client in-tree until GPUI Host Runtime parity is verified.
- First slice: Host Runtime start/stop/status/logs only; no broader Codex Remote control UI yet.

## Phase 0 - Solidify Selected Boundary

Goal: make the Path C decision explicit before source edits.

Edits:

- Update `docs/20-product-tdd/platform-build-boundaries.md` with a Windows Rust-native client boundary instead of a Windows DLL artifact boundary.
- Update `clients/README.md` to describe Windows as a Rust native client with direct CTCore integration.
- Update or annotate `tasks/0014-everywhere-control-surface-foundation/platform-client-architecture.md` so the old Tauri choice is not read as current direction.
- Update `clients/windows/README.md` only when the GPUI project skeleton is admitted.

Verification:

- Durable docs no longer imply Tauri or WinUI as the selected Windows direction.
- Product scope stays unchanged: Windows still hosts Codex Remote Host Runtime.

## Phase 1 - GPUI Feasibility Spike

Goal: prove GPUI is acceptable for the current simple Host Runtime surface before migrating product code.

Edits:

- Add a temporary or clearly marked native Rust app skeleton under `clients/windows/`.
- Add GPUI as the UI dependency.
- Render one window with:
  - status label,
  - bind mode control,
  - Start button,
  - Stop button,
  - Refresh button,
  - bounded log list.
- Do not wire CTCore yet unless the empty UI builds and runs on Windows.

Verification:

- `cargo check` succeeds for the GPUI app on Windows.
- App opens a window on Windows.
- Button click handlers can update visible state.
- Log list can append and scroll enough rows for the expected runtime event history.
- Basic resizing and DPI behavior are acceptable for a utility window.

Exit rule:

- If GPUI fails this spike in a way that is framework-level rather than our usage error, pause and reassess Path A before writing more Windows client code.

## Phase 2 - Direct CTCore Runtime Service

Goal: move the current Tauri Rust backend behavior into a reusable Rust service owned by the native client.

Edits:

- Add a `HostRuntimeService` or equivalent Rust module in the native Windows app.
- Depend on `ct-core` by path with `codex-remote-control-server`.
- Port the existing runtime states:
  - `stopped`,
  - `starting`,
  - `running`,
  - `stopping`,
  - `failed`.
- Port bind modes:
  - local-only `127.0.0.1:3765`,
  - local-network `0.0.0.0:3765`.
- Port Codex home resolution:
  - `CODEX_HOME`,
  - `USERPROFILE\\.codex`,
  - `HOME/.codex`,
  - fallback `.codex`.
- Start CTCore with `serve_listener_with_shutdown`, matching the current Tauri backend behavior.
- Keep runtime event history bounded.

Verification:

- `cargo test --manifest-path CTCore/Cargo.toml --features codex-remote-control-server`
- Native app `cargo check` succeeds.
- Starting runtime binds the expected address.
- `GET /health` succeeds while running.
- Stopping runtime frees the port.
- Starting while already running is idempotent or visibly rejected.
- Bind mode cannot change while running.

## Phase 3 - GPUI State Wiring

Goal: connect GPUI controls to the Rust runtime service without leaking CTCore internals into view code.

Edits:

- Introduce a small app state model:
  - runtime state,
  - bind mode,
  - bind address,
  - endpoint hint,
  - Codex home,
  - pending action flag,
  - recent events.
- Wire Start, Stop, Refresh, and bind mode controls.
- Ensure long-running start/stop work does not block the UI event loop.
- Convert runtime service updates into GPUI-visible state updates.

Verification:

- Start button disables while starting and while running.
- Stop button enables only while running.
- Bind mode controls disable while running.
- Refresh updates visible state without mutating runtime lifecycle.
- Failed start shows an error event without corrupting service state.

## Phase 4 - Native Utility UI Parity

Goal: reach visual and behavioral parity with the current Tauri Host Runtime control surface.

Edits:

- Build a compact GPUI utility layout:
  - top status area,
  - bind/endpoint/Codex home details,
  - control row,
  - event log list.
- Keep it dense and operational, not a landing page.
- Use stable dimensions for buttons/status fields so dynamic text does not shift the layout.
- Keep copy and labels close to the existing Host Runtime language unless a clearer native term is needed.

Verification:

- Text does not overflow at common Windows desktop sizes.
- Logs remain readable with at least 80 events.
- Running, stopped, starting, stopping, and failed states are visually distinct enough.
- Keyboard focus behavior is acceptable for Start/Stop/Refresh.

## Phase 5 - Build Scripts And Smoke Flow

Goal: make the GPUI client repeatable from command line before retiring Tauri.

Edits:

- Update or add Windows script flow:
  - `scripts/run-windows-client.ps1 check`
  - `scripts/run-windows-client.ps1 dev`
  - `scripts/run-windows-client.ps1 service-smoke`
- Keep the existing Tauri commands available until native parity is accepted.
- Add a smoke check that launches or calls the runtime path enough to prove:
  - start,
  - `/health`,
  - stop,
  - port released.

Verification:

- `check` runs formatting and `cargo check` for the native client.
- `smoke` proves CTCore Host Runtime lifecycle without manual clicking where practical.
- Generated binaries and build outputs stay ignored.

## Phase 6 - Retirement Decision

Goal: remove Tauri only after the GPUI client owns all first-slice behavior.

Retirement criteria:

- GPUI app builds and runs on Windows.
- GPUI app starts and stops CTCore in-process.
- Health route works while running.
- Stop releases port.
- Bind modes work.
- Runtime events are visible.
- Current Tauri path has no unique product behavior left.

Only then:

- Remove Tauri/Vite files.
- Replace `scripts/run-windows-client.*` default behavior with native Rust client checks.
- Remove Tauri dependencies and lockfile.
- Update `clients/windows/README.md` to make GPUI/native Rust the only current Windows direction.

## Phase 7 - Follow-Up Expansion

Out of first implementation slice unless separately approved:

- Tray/background residency.
- Launch at login.
- Windows Credential Manager.
- Installer/update channel.
- Pairing/auth.
- Full Codex Remote control UI.
- Local Windows notifications.
- arm64 Windows build.
- Accessibility audit beyond basic keyboard/focus behavior.
