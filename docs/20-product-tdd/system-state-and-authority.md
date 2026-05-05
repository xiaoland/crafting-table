# System state and authority

- state object: active top-level surface
  authority owner: Shell
  write path: shell navigation changes only

- state object: active or recent work session state
  authority owner: Work Session
  write path: session lifecycle actions from shell, Goal Forest, or Remote Control attach flows

- state object: longer-lived Goal Forest nodes, node relationships, linked sessions, and linked captures
  authority owner: Goal Forest
  write path: Goal Forest editing flows and explicit attach/relink actions

- state object: raw captured content before final placement
  authority owner: Capture
  write path: global capture flow, followed by explicit attach or classification actions

- state object: live remote connection and transfer state
  authority owner: Remote Control
  write path: Remote Control connection actions only

- state object: saved host profiles
  authority owner: Host Profiles
  write path: host-profile create/edit flows, not ad hoc per-session mutation

- state object: remote continuity recorded against a session
  authority owner: Work Session
  write path: Remote Control may propose or submit updates through session-owned attach or note flows

- state object: Codex Remote host entries, selected host, selected project/thread, composer controls, and live stream projection
  authority owner: Codex Remote
  write path: Codex Remote host, sidebar, Thread Page, and composer actions

- state object: Codex thread execution and host-local app-server lifecycle
  authority owner: Codex Remote Companion
  write path: Companion routes adapt CraftingTable requests to Codex app-server, Desktop Scout, and host-local process state

## 0.1.0 local persistence boundary

- state object: durable workspace document
  authority owner: WorkspaceStore
  write path: feature-level actions submit product mutations to `WorkspaceStore`; `WorkspaceStore` handles local JSON load and save

- state object: Goal Forest nodes, DAG edges, capture placement, host profile metadata, sessions, and session remote continuity records
  authority owner: same product units listed above
  write path: product actions keep their existing authority owner, with `WorkspaceStore` acting as the shared persistence boundary

- state object: shell route, active sheet, split-view visibility, live remote connection state, and Codex Remote live stream state
  authority owner: Shell, Remote Control runtime, and Codex Remote runtime
  write path: in-memory SwiftUI state inside the active app run

- state object: host credential secret
  authority owner: platform credential store
  write path: app data stores only a credential reference identifier; secret material belongs outside the workspace JSON document

## 0.1.0 Local LLM boundary

- state object: local model manifest and model cache records
  authority owner: Local LLM Model Manager
  write path: model discovery, add, download, verification, activation, switching, and deletion flows update the local manifest and app support cache

- state object: active local model
  authority owner: Local LLM Model Manager
  write path: explicit activation of a downloaded and verified model; HTTP generation may use a requested model id or fall back to this active model

- state object: HTTP server listener state
  authority owner: Local LLM foreground runtime
  write path: user start/stop controls only; runtime generation may temporarily mark the server as generating

- state object: HTTP bearer token
  authority owner: platform credential store
  write path: Local LLM generates, reveals, copies, and rotates an opaque token; HTTP clients must send `Authorization: Bearer <token>`

- state object: local chat transcript
  authority owner: Local LLM UI runtime
  write path: in-memory chat UI state inside the active app run until durable conversation state is explicitly admitted
