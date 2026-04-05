# Concepts

Keep this file short. It owns framework concepts only, not business vocabulary.

## Typed input taxonomy

- `Intent` - a change to product behavior, scope, policy, or strategy; usually owned by `docs/10-prd/`
- `Constraint` - a change in technical, documentation-system, dependency, or environment boundaries while product behavior stays stable
- `Reality` - observed behavior diverges from expectation and needs evidence-first diagnosis
- `Artifact` - a bounded deliverable or temporary output that usually stays tactical

## Mode taxonomy

- `Explore` - map unknowns and temporary assumptions
- `Solidify` - restate stable claims, owners, and verification
- `Execute` - make the smallest safe verified change
- `Diagnose` - investigate symptoms before deciding on a fix

## Task packet

A task packet is the bounded volatile workspace for non-trivial work.

Every task packet README should make these anchors explicit:

- `Objective & Hypothesis`
- `Guardrails Touched`
- `Verification`

## Ownership boundaries

- `docs/00-meta/` owns reusable workflow rules and framework concepts
- `docs/10-prd/` owns durable product what/why, observable behavior, and business vocabulary
- local `AGENTS.md` files own tactical hazards and recurrence tripwires near code
- code, tests, build settings, and executable checks own implementation truth
- `tasks/` owns volatility
