# Documentation growth rules

## Purpose

This file defines how the documentation system in this repository is allowed to grow.

It exists because the external framework that inspired this repo is not stored here. Future contributors and agents therefore need a small local source of truth for:

- when to add new durable documents
- when to keep material in `tasks/`
- when to create a new documentation layer
- when to simplify or delete docs that no longer earn their cost

The goal is not to create a second framework inside the repo.

The goal is to keep the doc system small, legible, and able to grow only under real pressure.

## Governing idea

Durable docs are a selective memory system.

They should preserve truths that are:

- stable
- easy to lose
- costly to rediscover
- useful beyond the current task
- not better enforced in code, tests, or other executable checks

If a truth is still volatile, local, or mostly useful for current execution, it belongs in `tasks/`, not in a durable layer.

## Current admitted layers

The repository currently admits only these durable layers:

- `docs/00-meta/` for local documentation-system guidance
- `docs/10-prd/` for durable product what and why, when such truth exists

It also admits:

- `tasks/` for volatile planning, exploration, primitive product ideas, and temporary execution context

The following layers are not admitted by default and should not be created until their admission rules are met:

- `docs/20-product-tdd/`
- `docs/30-unit-tdd/`
- `docs/40-deployment/`

## Promotion test

Before promoting anything into durable documentation, ask:

1. Is it stable across more than one task or discussion?
2. Will future humans or agents likely need it again?
3. Would rediscovering it later be risky or expensive?
4. Is it product or design memory rather than temporary execution chatter?
5. Can it be expressed more safely in code, tests, CI, or runtime checks instead?

Promote only if most of these answers are yes.

If the answer is still unclear, keep the material in `tasks/`.

## Durable destination rules

Use the smallest correct destination.

- **Local documentation-system rules** → `docs/00-meta/`
- **Product what/why** → `docs/10-prd/`
- **Cross-unit technical truth** → `docs/20-product-tdd/` only when admitted
- **Hard local unit design truth** → `docs/30-unit-tdd/` only when admitted
- **Runtime or operational truth** → `docs/40-deployment/` only when admitted
- **Mechanically enforceable truth** → code, tests, CI, types, schemas, assertions
- **Volatile reasoning or temporary plans** → `tasks/`

Do not create a new durable doc if an existing smaller destination already fits.

## Rules for `docs/10-prd/`

`docs/10-prd/` is the durable home for product what and why.

Add files there only when the content is:

- product-level
- stable enough to preserve
- likely to matter beyond the current task
- not just rough exploration or primitive ideation

Typical examples of material that may eventually belong there:

- durable product pressures
- stable product claims
- durable workflows
- product rules and invariants
- stable scope boundaries
- canonical terminology worth preserving

Do not put these in `docs/10-prd/`:

- implementation structure
- technical decomposition
- speculative architecture
- active planning
- rough brainstorming
- fake certainty written to make the repo look complete

## Admission rule for `docs/20-product-tdd/`

Create `docs/20-product-tdd/` only when at least one of these becomes true:

- the system has multiple meaningful technical units
- cross-unit coordination becomes non-trivial
- authority boundaries are easy to misunderstand
- important product claims depend on cooperation across multiple units
- system-level regressions can happen even when local units appear correct

If code and tests still explain the system well enough, do not create this layer.

## Admission rule for `docs/30-unit-tdd/`

Create `docs/30-unit-tdd/` only for genuinely hard local units.

A unit should get this layer only when at least one of these becomes true:

- authority or state ownership is non-obvious
- ordering, timing, or concurrency matters
- failure semantics are subtle
- several interfaces interact in risky ways
- invariants are easy to violate during normal iteration
- the unit repeatedly regresses
- the unit has high blast radius or high change cost

Do not create this layer for ordinary components just to be thorough.

## Admission rule for `docs/40-deployment/`

Create `docs/40-deployment/` only when runtime or operational truth becomes non-trivial.

Typical triggers include:

- deployment topology becomes complex
- configuration risk becomes meaningful
- releases or migrations need preserved rationale
- rollback or recovery depends on documented operational knowledge

If deployment remains simple, do not create this layer.

## Task rule

`tasks/` is the entropy buffer of the system.

Keep material in `tasks/` when it is:

- still changing
- primarily useful for the current task
- speculative
- procedural
- exploratory
- not yet worthy of durable preservation

This includes:

- primitive product ideas
- rough naming exploration
- possible workflows
- temporary plans
- sequencing notes
- comparisons among options
- open questions still under active discussion

Tasks are allowed to decay.
Durable docs should stay small.

## Demotion rule

If a durable document no longer answers an expensive future question, simplify it, merge it, or delete it.

Prefer deletion over ritual maintenance.

A doc should also be demoted or removed if it has become:

- mostly duplicate
- mostly speculative
- mostly task-local
- mostly implementation trivia better kept near code

## Change discipline

When adding a durable doc or layer:

- choose the smallest structure that solves the real problem
- avoid creating document families in anticipation of future needs
- avoid splitting a topic across many weak files too early
- keep naming clear and literal
- update neighboring docs only as much as needed to keep navigation honest

When in doubt, bias toward:

- fewer docs
- smaller docs
- later promotion
- stronger ownership of truth

## Practical rule of thumb

If the material is mainly about:

- what the product must be or why → consider `docs/10-prd/`
- how the documentation system itself should work → consider `docs/00-meta/`
- what the code must guarantee mechanically → put it in code/tests/checks
- what we are exploring right now → keep it in `tasks/`

If you feel pressure to create a doc just so the tree looks complete, do not create it.

## Current expectation

For now, this repository should remain minimal.

A good near-term outcome is:

- `docs/00-meta/` stays short and practical
- `docs/10-prd/` stays sparse until real product truth stabilizes
- `tasks/` absorbs product exploration and temporary reasoning
- code and tests carry implementation truth

That is enough foundation for the documentation system to grow later without drifting into ceremony.