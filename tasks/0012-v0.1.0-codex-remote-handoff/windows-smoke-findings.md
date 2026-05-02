# Windows Smoke Findings

## Purpose

This note records the first real Windows host probe against `ws.yyh` for the Codex Desktop Scout plan.

## Host

- SSH alias: `ws.yyh`
- Resolved host: `172.16.249.14`
- SSH user: `yyh`
- Windows identity: `yyh-ws\yyh`
- Hostname: `yyh-ws`
- PowerShell: `5.1.19041.6456`
- Active interactive session: RDP session `8`, user `yyh`

## Connection Findings

- SSH network reachability was confirmed on port `22`.
- Initial host key handling used a temporary known-hosts file at `/tmp/codex-ws-yyh-known-hosts`.
- The repository owner's `~/.ssh/known_hosts` was left untouched during probing.
- `BatchMode` key authentication succeeded after temporary host-key handling.

## Runtime Findings

- `.NET` command in PATH: absent.
- `codex` command in PATH: absent.
- Codex Desktop process is running.
- Codex Desktop app path:
  - `C:\Program Files\WindowsApps\OpenAI.Codex_26.429.2026.0_x64__2p2nqsd0c76g0\app\Codex.exe`
- Bundled Codex CLI path observed in the app package:
  - `C:\Program Files\WindowsApps\OpenAI.Codex_26.429.2026.0_x64__2p2nqsd0c76g0\app\resources\codex.exe`
- VS Code extension Codex CLI was also observed:
  - `c:\Users\yyh\.vscode\extensions\openai.chatgpt-26.422.71525-win32-x64\bin\windows-x86_64\codex.exe`

## Scheduled Task Runner Finding

UI Automation probing should run inside the active desktop session.

SSH is a development and smoke-test harness only. The Windows Scout runtime is a local Windows executable launched by the host companion, and it reads the local Codex Desktop through Windows UI Automation.

Confirmed path:

- SSH stages a probe script into `%TEMP%`.
- SSH creates a one-shot scheduled task with `/IT`.
- The task runs in the active RDP session.
- The probe writes JSON into `%TEMP%`.
- SSH reads the JSON and deletes the task/script.

Probe result:

- `[Environment]::UserInteractive` returned `true`.
- The scheduled task saw Codex Desktop with a non-empty window title.

## UI Automation Findings

Top-level Codex window:

- title: `Codex`
- class: `Chrome_WidgetWin_1`
- control type: `ControlType.Window`
- bounds: `x=541`, `y=94`, `width=1337`, `height=902`
- process path: `C:\Program Files\WindowsApps\OpenAI.Codex_26.429.2026.0_x64__2p2nqsd0c76g0\app\Codex.exe`

Raw View exposed:

- `RootView`
- `NonClientView`
- `WinFrameView`
- `ClientView`
- `WebView`
- `Chrome_RenderWidgetHostHWND`
- window buttons such as Minimize, Maximize, Restore, and Close

Important observation:

- The first UIA probes exposed the Chromium/WebView shell and window controls.
- The sampled UIA tree exposed shell-level Chromium/WebView data.
- This supports using Windows Scout for active-window detection, focus/fallback state, and low-confidence handoff clues.
- Semantic thread data should come from app-server or local Codex stores.

## Smoke Runner Implications

Windows Real Codex Desktop smoke should validate these fields first:

- host reachable by SSH
- interactive session present
- scheduled task `/IT` path works
- Codex process found
- Codex top-level UIA window found
- bounds are finite and visible
- Raw View contains WebView or Chrome render host
- structured low-confidence result is emitted when UIA provides shell-level clues

## MVP Acceptance for Windows Scout

- The scout emits JSON on success and structured JSON on failure.
- The scout can find the active Codex window on `ws.yyh`.
- The scout reports window title, process path, bounds, and WebView presence.
- The scout reports confidence as low when UIA provides shell-level clues.
- The smoke runner can be launched from SSH and complete inside the active RDP session.
