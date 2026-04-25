# Task 0006 — v0.1.0

## Status
Active

## Date
2026-04-05

## MVT Core

- Objective & Hypothesis: converge the current `0.1.0` product-definition packet into a coherent baseline; the expected result is a consistent scope, language, IA, and journey set without over-promoting volatile reasoning.
- Guardrails Touched: keep durable product truth in `docs/10-prd/`; keep detailed reasoning and open questions in `tasks/`.
- Verification: the packet yields a coherent `0.1.0` position, explicit open questions, and only the stable product truths promoted into PRD.

## Classification

- Input Type: Intent
- Active Mode: Explore -> Solidify

## Purpose

Keep the current `0.1.0` product-definition work inside one task folder while still separating distinct reasoning threads into focused notes.

The current notes in this folder cover:

- the earlier exploration, scope, and handoff notes that led into the current shape
- how `Remote Control` should link back to `work session`
- how `work session` and `Goal Forest` should coexist in user-facing language
- the current UI information architecture
- the current user-journey draft
- the minimum screen inventory
- the minimum transition map
- the low-fidelity layout packet for the first SwiftUI shell skeleton

This task stays in `tasks/` because the detailed reasoning is still volatile.

## Why this is a folder

The work had started to sprawl across several single-file task notes.
At the same time, creating a new task folder for every follow-up would fragment the navigation too quickly.

This folder is the current compromise:

- one umbrella task for `0.1.0`
- several focused notes inside that single folder

## Read first

1. `AGENTS.md`
2. `docs/00-meta/input-intent.md`
3. `docs/00-meta/mode-a-explore.md`
4. `docs/10-prd/index.md`
5. `docs/10-prd/glossary.md`
6. `docs/10-prd/behavior/claims.md`
7. `docs/10-prd/behavior/scope.md`
8. `docs/10-prd/behavior/workflows.md`
9. `docs/20-product-tdd/index.md`
10. `docs/20-product-tdd/system-state-and-authority.md`
11. `goal-forest-exploration.md`
12. `scope.md`
13. `session-handoff.md`
14. `remote-control-session-linkage.md`
15. `work-session-and-goal-forest-language.md`
16. `information-architecture.md`
17. `user-journeys.md`
18. `minimum-screen-inventory.md`
19. `transition-map.md`
20. `low-fidelity-layout-packet.md`

## Current outputs

The current recommended `0.1.0` position is:

- remote control may start from the `Remote Control` tab or from a `work session`
- remote control should keep session linkage visible rather than acting as a sealed-off utility
- saved host profiles belong to the broader workspace, not to individual sessions
- there is no standalone `Home`; the shell is `SideBar + Content`
- `Goal Forest` and `Remote Control` are the admitted top-level tabs, with `Goal Forest` first
- `work session` remains the primary execution object for doing now
- `Goal Forest` is the longer-lived map that gives sessions and captures context
- `Goal Forest` may keep its metaphorical name, but operational labels should stay literal
- `Goal Forest` may also shrink into minimap context around active work
- capture starts from a small global floating create button
- the first layout cut uses A2 shell recency, B2 nearby Goal Forest context, and C1 Remote Control session linkage

## Remaining open questions

- Does `0.1.0` need any manual review affordance beyond remote file access?
- Does the low-fidelity SwiftUI shell reveal any missing product or technical decision before persistence and real remote depth begin?

## References

- `tasks/0006-v0.1.0/goal-forest-exploration.md`
- `tasks/0006-v0.1.0/scope.md`
- `tasks/0006-v0.1.0/session-handoff.md`
