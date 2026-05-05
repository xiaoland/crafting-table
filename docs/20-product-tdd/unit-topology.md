# Unit topology

- units: Shell
  boundaries: top-level surface selection, sidebar/content composition, transitions into active work
  ownership: navigation state and entry routing

- units: Goal Forest
  boundaries: node graph-like structure, context browsing, links to sessions and captures
  ownership: longer-lived orientation structure

- units: Work Session
  boundaries: active execution context, continuity notes, session lifecycle, links to tools and artifacts
  ownership: doing-now state

- units: Capture
  boundaries: append-first intake and later attachment flows
  ownership: raw captured state before final placement

- units: Remote Control
  boundaries: remote connection state, terminal/file-transfer actions, session attachment workflow
  ownership: active remote operation state

- units: Codex Remote
  boundaries: host selection, project-grouped Codex thread list, Thread Page, composer controls, active turn streaming, and permission-mode selection
  ownership: host-scoped Codex thread interaction state inside the app

- units: Codex Remote Companion
  boundaries: CraftingTable-owned HTTP/WebSocket contract, Codex app-server adaptation, Desktop Scout snapshots, and host-local Codex process details
  ownership: host-side Codex interaction adapter state

- units: Host Profiles
  boundaries: reusable saved connection definitions
  ownership: workspace-scoped remote configuration reused by sessions and Remote Control

- units: Local LLM
  boundaries: local model manifest, GGUF source/download/verification/cache lifecycle, active model selection, foreground HTTP server state, local chat prompt/response surface
  ownership: user-controlled local model serving for the iPad and trusted LAN clients
