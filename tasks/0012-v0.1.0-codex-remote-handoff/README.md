# Task 0012 - v0.1.0 Codex Remote handoff

## Status
Executing

## Date
2026-05-02

## MVT Core

- Objective & Hypothesis: establish the smallest stable path for CraftingTable to remotely interact with Codex running on macOS or Windows, with hot handoff as the priority; the expected result is an independent Codex Remote surface that can continue useful Codex work from iPad through a host companion.
- Guardrails Touched: treat `Codex Remote` as its own feature; reserve Goal Forest, Work Session, and Remote Control integration for later product decisions; keep GUI remote desktop and broad app streaming deferred; isolate Codex app-server protocol churn behind a CraftingTable companion contract; use desktop UI automation as a hot-handoff reconciliation layer.
- Verification: pair with a trusted host companion, list reachable Codex threads, resume or create a thread, send input, stream status and output updates, and exercise high-confidence and low-confidence desktop handoff paths.

## Classification

- Input Type: Constraint
- Active Mode: Explore -> Solidify -> Execute
- Governing Anchors: `AGENTS.md`, `docs/00-meta/input-constraint.md`, `docs/00-meta/mode-a-explore.md`, `docs/00-meta/mode-b-solidify.md`, `docs/00-meta/mode-c-execute.md`, `scratch/conv.md`

## Packet Map

- `handoff-architecture.md`: handoff modes, companion boundary, evidence, and risk framing.
- `implementation-plan.md`: implementation locations, technology stack, and MVP execution slices.
- `windows-smoke-findings.md`: `ws.yyh` probing results, Windows UI Automation findings, and smoke-runner implications.
- `semantic-handoff-findings.md`: app-server protocol facts, Companion adapter shape, and semantic smoke results.
- `desktop-handoff-findings.md`: Companion Desktop Scout route, normalized snapshot contract, and hot-handoff smoke result.
- `thread-page-findings.md`: iPad Thread Page UI slice, client contract usage, and verification notes.
- `streaming-turns-findings.md`: active-turn WebSocket contract, iPad stream lifecycle, and live smoke evidence.
- `slice-13-protocol-findings.md`: model metadata, reasoning effort, Fast service tier, and turn-start parameter findings for composer controls.
- `stream-abort-diagnosis.md`: idle WebSocket abort diagnosis, heartbeat fix, transient refresh retry, and smoke evidence.
- `live-event-rendering-diagnosis.md`: live tool/event row rendering diagnosis, payload alignment, and WebSocket smoke evidence.
- `live-agent-message-boundaries.md`: live assistant item boundary diagnosis, `item_id` propagation, and replay smoke evidence.
- `permission-mode-findings.md`: permission mode schema findings, Companion mapping, and smoke evidence.
- `composer-controls-layout-diagnosis.md`: simulator evidence for composer control wrapping and the single-line horizontal options fix.
- `thread-creation-findings.md`: project-scoped thread creation contract, zero-turn app-server behavior, and smoke evidence.

## Current Decision

Codex Remote handoff should use a hybrid model:

- app-server semantic mode for durable thread and turn control
- desktop reconciliation mode for hot handoff from an already-open Codex Desktop window
- mirror mode for low-confidence cases where CraftingTable can surface visible state and limited controls while avoiding false continuity claims

The companion is the stability boundary. CraftingTable should speak a small CraftingTable-owned protocol. The companion may use Codex app-server, local Codex stores, CLI fallback, macOS Accessibility, or Windows UI Automation behind that boundary.

Goal Forest, Work Session, and Remote Control integration sit outside this MVP. This task owns Codex Remote as a standalone slice.

## Next Execution Target

Harden the standalone Codex Remote path behind the existing companion boundary:

1. Surface approval and user-input request states from Companion.
2. Use Desktop Scout confidence to guide manual thread selection or semantic resume.
3. Improve transcript rendering for approval, user-input, and richer progress/status states.
4. Preserve useful stream state across reconnects and host switches where Companion has enough evidence.

## Promotion Candidates

- Proven companion contract -> `docs/20-product-tdd/cross-unit-contracts.md`
- Proven companion host fields -> app models, then `docs/20-product-tdd/system-state-and-authority.md` if the feature becomes durable
- Product-visible Codex Remote behavior -> `docs/10-prd/behavior/` if the standalone feature becomes durable
- Durable security boundary -> `docs/20-product-tdd/` after pairing and credential handling are proven
