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
