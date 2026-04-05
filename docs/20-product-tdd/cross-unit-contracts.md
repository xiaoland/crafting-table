# Cross-unit contracts

- producer: Shell
  consumer: Goal Forest, Remote Control, Work Session
  contract schema: Shell exposes only the admitted top-level surfaces and routes into active content states without inventing a standalone Home unit.
  compatibility policy: adding a new top-level surface requires PRD scope change first.
  constraining limit or tradeoff: shell convenience must not outrank product coherence.

- producer: Goal Forest
  consumer: Work Session
  contract schema: Goal Forest may launch or link sessions, but it does not own session execution state.
  compatibility policy: node/session relationships may evolve, but session execution ownership stays with Work Session.
  constraining limit or tradeoff: context should support execution without swallowing it.

- producer: Capture
  consumer: Goal Forest, Work Session
  contract schema: Capture can attach immediately or later; capture creation cannot require full classification first.
  compatibility policy: later attachment flows may expand, but append-first capture remains stable.
  constraining limit or tradeoff: intake speed is protected over early structure.

- producer: Remote Control
  consumer: Work Session
  contract schema: Remote Control may begin unattached, but session linkage and continuity must remain explicit and recoverable.
  compatibility policy: richer continuity may be added later, but `0.1.0` only requires a small continuity bundle.
  constraining limit or tradeoff: quick access is allowed, invisible orphaned remote work is not.

- producer: Host Profiles
  consumer: Remote Control, Work Session
  contract schema: sessions reference workspace-scoped host profiles instead of copying connection definitions.
  compatibility policy: profile schema may evolve, but workspace ownership remains stable.
  constraining limit or tradeoff: reuse beats per-session duplication.
