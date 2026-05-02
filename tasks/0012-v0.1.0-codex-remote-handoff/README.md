# Task 0012 - v0.1.0 Codex Remote handoff

## Status
Proposed

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

## Current Decision

Codex Remote handoff should use a hybrid model:

- app-server semantic mode for durable thread and turn control
- desktop reconciliation mode for hot handoff from an already-open Codex Desktop window
- mirror mode for low-confidence cases where CraftingTable can surface visible state and limited controls while avoiding false continuity claims

The companion is the stability boundary. CraftingTable should speak a small CraftingTable-owned protocol. The companion may use Codex app-server, local Codex stores, CLI fallback, macOS Accessibility, or Windows UI Automation behind that boundary.

Goal Forest, Work Session, and Remote Control integration sit outside this MVP. This task owns Codex Remote as a standalone slice.

## Next Execution Target

Build the first MVP around `Companion/`:

1. Create Rust Companion Core with `health`, app-server reachability, and a minimal thread listing path.
2. Add macOS Desktop Scout first for local active Codex window snapshot.
3. Add Windows Desktop Scout using the smoke path proven on `ws.yyh`.
4. Wire a minimal `Codex Remote` app surface in CraftingTable after the companion can produce stable snapshots.
5. Keep Codex Remote runtime state self-contained for this MVP.

## Promotion Candidates

- Proven companion contract -> `docs/20-product-tdd/cross-unit-contracts.md`
- Proven companion host fields -> app models, then `docs/20-product-tdd/system-state-and-authority.md` if the feature becomes durable
- Product-visible Codex Remote behavior -> `docs/10-prd/behavior/` if the standalone feature becomes durable
- Durable security boundary -> `docs/20-product-tdd/` after pairing and credential handling are proven
