# Task 0006 — v0.1.0

## Status
Active

## Date
2026-04-05

## Purpose

Keep the current `0.1.0` product-definition work inside one task folder while still separating distinct reasoning threads into focused notes.

The current notes in this folder cover:

- the earlier exploration, scope, and handoff notes that led into the current shape
- how `Remote Control` should link back to `work session`
- how `work session` and `Goal Forest` should coexist in user-facing language
- the current UI information architecture
- the current user-journey draft

This task stays in `tasks/` because the detailed reasoning is still volatile.

## Why this is a folder

The work had started to sprawl across several single-file task notes.
At the same time, creating a new task folder for every follow-up would fragment the navigation too quickly.

This folder is the current compromise:

- one umbrella task for `0.1.0`
- several focused notes inside that single folder

## Read first

1. `AGENTS.md`
2. `docs/00-meta/index.md`
3. `docs/10-prd/early-product-truths.md`
4. `goal-forest-exploration.md`
5. `scope.md`
6. `session-handoff.md`
7. `remote-control-session-linkage.md`
8. `work-session-and-goal-forest-language.md`
9. `information-architecture.md`
10. `user-journeys.md`

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

## Remaining open questions

- Does `0.1.0` need any manual review affordance beyond remote file access?
- How much current or recent session state should remain visible in the shell without creating a second dashboard?
- What is the minimum screen inventory and transition map needed to make the current IA implementable?

## References

- `tasks/0006-v0.1.0/goal-forest-exploration.md`
- `tasks/0006-v0.1.0/scope.md`
- `tasks/0006-v0.1.0/session-handoff.md`
