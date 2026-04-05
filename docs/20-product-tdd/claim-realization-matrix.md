# Claim realization matrix

- product claim: One shared surface supports orientation and action.
  realizing unit(s): Shell, Goal Forest, Work Session, Capture, Remote Control
  key tests: journey-level UI flows for orient -> resume -> capture -> act
  observability signal: the user can move across the main loop without falling into disconnected tools

- product claim: `work session` is the primary execution object.
  realizing unit(s): Work Session, Shell, Goal Forest
  key tests: session resume and active-session priority flows
  observability signal: the app can return to doing-now state without a fake dashboard

- product claim: `Goal Forest` is operable orientation, not decorative branding.
  realizing unit(s): Goal Forest, Work Session
  key tests: create/edit/connect/inspect/link flows
  observability signal: Goal Forest supports placement and nearby context in real use

- product claim: Capture stays cheap and defers classification.
  realizing unit(s): Capture, Work Session, Goal Forest
  key tests: global capture save and later attach flows
  observability signal: capture can be saved before final placement is known

- product claim: `Remote Control` is a core, session-aware action surface.
  realizing unit(s): Remote Control, Host Profiles, Work Session
  key tests: session-linked remote flow and remote-first-then-attach flow
  observability signal: remote work is useful immediately and still preserves session continuity
