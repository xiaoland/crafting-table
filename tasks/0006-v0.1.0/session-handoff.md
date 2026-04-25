# Task 0005 — Session handoff

## Status
Active

## Date
2026-04-02

## Purpose

Provide a lightweight handoff note so a future session can resume the current product-definition work quickly without rereading the entire conversation.

This file is intentionally volatile and belongs in `tasks/`, not in the durable PRD layer.

## Read first

If you are resuming this work in a new session, read in this order:

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
11. `tasks/0006-v0.1.0/goal-forest-exploration.md`
12. `tasks/0006-v0.1.0/scope.md`
13. `tasks/0006-v0.1.0/README.md`
14. `tasks/0006-v0.1.0/remote-control-session-linkage.md`
15. `tasks/0006-v0.1.0/work-session-and-goal-forest-language.md`
16. `tasks/0006-v0.1.0/information-architecture.md`
17. `tasks/0006-v0.1.0/user-journeys.md`
18. `tasks/0006-v0.1.0/minimum-screen-inventory.md`
19. `tasks/0006-v0.1.0/transition-map.md`
20. `tasks/0006-v0.1.0/low-fidelity-layout-packet.md`
21. this file

## Current durable product position

These points have been promoted into the PRD layer or are being treated as stable enough to constrain discussion:

- `(xiaoland's) Crafting Table` is a personal, iPad-first central control surface for life and work.
- The product optimizes for the repo owner's personal utility, not generic market breadth.
- The product must not collapse into a developer-only or fully agent-centric tool.
- `work session` is the first-class execution object.
- `Goal Forest` is intended as a user-facing term.
- remote control is a core tool surface
- first remote shape is terminal-first with file transfer

## Current `0.1.0` direction

The working `0.1.0` baseline is currently:

- Sidebar + Content shell
- work session basics
- operable `Goal Forest`
- seed pool / quick capture
- remote control baseline

The working `0.1.0` non-goals are currently:

- no agent support in `Goal Forest` or `Remote Control`
- no integrated agent-output review
- Pencil-specific workflows should not shape the first release
- no autonomous `Goal Forest` restructuring
- no GUI remote desktop

## Most important recent decisions

- Remote control must meet a real baseline in `0.1.0`.
- `Goal Forest` must be truly operable in `0.1.0`, not decorative.
- Agent support was removed from `0.1.0` across both `Goal Forest` and `Remote Control`.
- Integrated agent-output review is out of scope for `0.1.0`.
- Pencil was downgraded to a low-confidence idea.
- There is no standalone `Home` concept in the current shell direction.
- `Goal Forest` and `Remote Control` are parallel tabs, with `Goal Forest` first.
- `work session` has content priority, `Goal Forest` may shrink into minimap context, and capture starts from a floating create button.
- The first low-fidelity layout cut uses A2 shell recency, B2 nearby Goal Forest context, and C1 Remote Control session linkage.
- The current minimum `Goal Forest` operation set is being treated as sufficient for now.

## Current tension that is now deferred

A longer-term contradiction still exists, but it no longer blocks `0.1.0`:

- the product must not become agent-centric
- the broader product idea still imagines shared human/agent workspace

For now, the chosen simplification is to keep `0.1.0` fully human-operated across `Goal Forest` and `Remote Control`.

## Recommended next decision

The next useful step is to implement the low-fidelity SwiftUI shell skeleton for `0.1.0`.

The minimal decision that is still missing is:

- whether any manual review affordance exists beyond remote file access
- whether the shell skeleton reveals any missing product or technical decision before persistence and real remote depth begin

Without that implementation pass, the IA may stay coherent in writing but still untested as an iPad-first SwiftUI surface.

## Proposed minimum `Goal Forest` operation set

The current proposed minimum operation set for `0.1.0` is:

1. create a node
2. rename or edit a node
3. connect a node to another node
4. attach a work session or capture to a node
5. move or re-link a session or capture
6. inspect a node with nearby relationships
7. archive or remove a node without breaking continuity

## Files changed so far

At the time of writing, the main ongoing document changes are:

- `docs/00-meta/input-intent.md`
- `docs/00-meta/mode-a-explore.md`
- `docs/10-prd/index.md`
- `docs/10-prd/glossary.md`
- `docs/10-prd/_drivers/*`
- `docs/10-prd/behavior/*`
- `docs/10-prd/domain-structure/*`
- `docs/10-prd/early-product-truths.md`
- `docs/20-product-tdd/*`
- `tasks/0006-v0.1.0/goal-forest-exploration.md`
- `tasks/0006-v0.1.0/scope.md`
- `tasks/0006-v0.1.0/session-handoff.md`
- `tasks/0006-v0.1.0/README.md`
- `tasks/0006-v0.1.0/remote-control-session-linkage.md`
- `tasks/0006-v0.1.0/work-session-and-goal-forest-language.md`
- `tasks/0006-v0.1.0/information-architecture.md`
- `tasks/0006-v0.1.0/user-journeys.md`
- `tasks/0006-v0.1.0/minimum-screen-inventory.md`
- `tasks/0006-v0.1.0/transition-map.md`
- `tasks/0006-v0.1.0/low-fidelity-layout-packet.md`

These are documentation changes only. No code or tests have been changed yet.

## Practical resume prompt

If a future session needs a concise restart point, use:

"Continue product-definition work for `(xiaoland's) Crafting Table`. Read `docs/00-meta/input-intent.md`, `docs/00-meta/mode-c-execute.md`, `docs/10-prd/glossary.md`, `docs/10-prd/behavior/claims.md`, `docs/10-prd/behavior/scope.md`, `docs/10-prd/behavior/workflows.md`, `docs/20-product-tdd/system-state-and-authority.md`, `tasks/0006-v0.1.0/scope.md`, `tasks/0006-v0.1.0/README.md`, `tasks/0006-v0.1.0/information-architecture.md`, `tasks/0006-v0.1.0/user-journeys.md`, `tasks/0006-v0.1.0/minimum-screen-inventory.md`, `tasks/0006-v0.1.0/transition-map.md`, `tasks/0006-v0.1.0/low-fidelity-layout-packet.md`, and `tasks/0006-v0.1.0/session-handoff.md`. Agent support is out of `0.1.0`. There is no standalone Home; the shell is SideBar + Content, with Goal Forest first and Remote Control parallel. The immediate task is to implement the low-fidelity SwiftUI shell skeleton."
