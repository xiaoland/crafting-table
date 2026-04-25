# System state and authority

- state object: active top-level surface
  authority owner: Shell
  write path: shell navigation changes only

- state object: active or recent work session state
  authority owner: Work Session
  write path: session lifecycle actions from shell, Goal Forest, or Remote Control attach flows

- state object: longer-lived placement of nodes, linked sessions, and linked captures
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

## 0.1.0 local persistence boundary

- state object: durable workspace document
  authority owner: WorkspaceStore
  write path: feature-level actions submit product mutations to `WorkspaceStore`; `WorkspaceStore` handles local JSON load and save

- state object: Goal Forest nodes, DAG edges, capture placement, host profile metadata, sessions, and session remote continuity records
  authority owner: same product units listed above
  write path: product actions keep their existing authority owner, with `WorkspaceStore` acting as the shared persistence boundary

- state object: shell route, active sheet, split-view visibility, and live remote connection state
  authority owner: Shell and Remote Control runtime
  write path: in-memory SwiftUI state inside the active app run

- state object: host credential secret
  authority owner: platform credential store
  write path: app data stores only a credential reference identifier; secret material belongs outside the workspace JSON document
