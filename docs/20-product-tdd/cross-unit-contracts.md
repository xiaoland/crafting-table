# Cross-unit contracts

- producer: Shell
  consumer: Goal Forest, Remote Control, Codex Remote, Work Session
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

- producer: Codex Remote
  consumer: Work Session, Goal Forest, Remote Control
  contract schema: Codex Remote keeps its host/thread runtime and server contract in a separate Codex-specific boundary.
  compatibility policy: future linkage with Work Session, Goal Forest, or Remote Control requires an explicit PRD/TDD update.
  constraining limit or tradeoff: Codex-specific thread continuation is protected over broad remote-control scope.

- producer: CTCore Codex Remote Server
  consumer: Codex Remote
  contract schema: CTCore exposes host health, project-grouped threads, thread detail, thread creation, model list, turn submission, and active-turn stream events through CraftingTable-owned routes.
  compatibility policy: codex-app server protocol churn stays behind CTCore Codex Remote Server.
  constraining limit or tradeoff: stable iPad behavior outranks direct app-server exposure.

- producer: Shell
  consumer: Local LLM
  contract schema: Shell may route into Local LLM as a standalone surface without requiring Goal Forest, Work Session, Capture, or Remote Control linkage.
  compatibility policy: future integration with work sessions or captures requires an explicit PRD/TDD update.
  constraining limit or tradeoff: model serving stays useful without blurring the core crafting loop.

- producer: Local LLM
  consumer: trusted LAN clients
  contract schema: Local LLM exposes a foreground, bearer-protected HTTP surface with `GET /health`, `GET /v1/models`, and synchronous `POST /v1/responses`; `POST /v1/chat/completions`, streaming, and durable conversation state remain outside the current contract.
  compatibility policy: `/v1/models` lists only locally ready inference models; `/v1/responses` may use an explicit model id or fall back to the active model.
  constraining limit or tradeoff: OpenAI compatibility is intentionally minimal and stateless until a stateful conversation store is admitted.
