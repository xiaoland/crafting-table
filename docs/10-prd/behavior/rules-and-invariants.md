# Rules and invariants

- rule or invariant: `work session` remains the primary execution object for `0.1.0`.
  rationale: execution should not be demoted beneath orientation or tool surfaces.
  violation impact: the product becomes broad but operationally blurry.
  linked claim(s): Claim 1, Claim 2.

- rule or invariant: admitted top-level shell surfaces must be explicit product scope; there is no standalone `Home`.
  rationale: a fake home screen would duplicate weaker shortcuts and dilute the core loop.
  violation impact: the shell becomes cluttered and less honest.
  linked claim(s): Claim 1, Claim 3, Claim 5, Claim 6.

- rule or invariant: capture remains global and append-first.
  rationale: cheap intake is one of the clearest durable product pressures.
  violation impact: users pay classification tax before saving important state.
  linked claim(s): Claim 1, Claim 4.

- rule or invariant: Remote Control may begin outside a session, but unattached remote work must remain visible and one-step linkable to a session.
  rationale: this keeps quick action cheap without turning Remote Control into a disconnected utility.
  violation impact: remote work becomes orphaned and the product loop breaks.
  linked claim(s): Claim 2, Claim 5.

- rule or invariant: saved host profiles belong to workspace scope, not to individual work sessions.
  rationale: connection setup must be reusable across many sessions.
  violation impact: host configuration is duplicated and continuity becomes harder to manage.
  linked claim(s): Claim 5.

- rule or invariant: Codex Remote has its own product boundary from Remote Control, Goal Forest, and Work Session.
  rationale: the MVP centers on semantic Codex thread continuation through Codex Remote Server; general remote machine operation and session continuity belong to separate product boundaries.
  violation impact: the Codex Remote slice inherits unrelated workflow obligations and becomes harder to stabilize.
  linked claim(s): Claim 1, Claim 7.

- rule or invariant: Local LLM serving is explicitly user-started and foreground-scoped.
  rationale: iPad lifecycle and LAN exposure should stay visible to the user.
  violation impact: the app implies daemon-like reliability or network reach beyond what the first slice can honestly support.
  linked claim(s): Claim 6.
