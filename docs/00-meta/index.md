# Documentation system

## Purpose

This directory holds the repository-local explanation of the documentation system.

The original `Sustainable Vibe Coding Framework v8` document is **not** stored in this repository, so this layer preserves the small amount of local guidance needed for future humans and agents to understand:

- which documentation layers exist here
- what each layer is for
- where volatile work should live
- how durable documentation should grow
- when a document should be deleted instead of maintained

This directory is not product truth and not implementation truth.
It is local operating guidance for the repo’s documentation system.

## Current admitted layers

The repository currently admits only these layers:

- `docs/00-meta/` — local guidance for how the documentation system works in this repo
- `docs/10-prd/` — durable product truth, when such truth becomes stable enough to preserve
- `tasks/` — volatile planning, exploration, temporary reasoning, and active coordination
- code, tests, build settings, and executable guardrails — implementation truth

The repository does **not** currently admit:

- `docs/20-product-tdd/`
- `docs/30-unit-tdd/`
- `docs/40-deployment/`

Those layers should appear only when real pressure justifies them.

## Layer roles

### `docs/00-meta/`

Owns only the local documentation system itself:

- layer definitions
- reading guidance
- growth rules
- promotion and demotion rules
- repository-local clarification of documentation discipline

It should stay small.

### `docs/10-prd/`

Owns durable product **what** and **why**.

Use it only for product truth that has become stable enough to preserve across multiple tasks or discussions.

Do not use it to make the project look more defined than it really is.

### `tasks/`

Owns volatility.

Use tasks for:

- primitive product ideas
- rough hypotheses
- naming exploration
- workflow sketches
- planning notes
- temporary reasoning
- active execution context
- unresolved short-term questions

Tasks are expected to decay.

### Code and tests

Own implementation truth:

- source code
- tests
- compiler-enforced structure
- build configuration
- executable checks

Do not restate code-level truth in prose unless prose is the only practical way to preserve it.

## Current repo stance

This repository is still pre-PRD in practice.

That means:

- the PRD layer exists as a foundation
- the PRD layer is intentionally sparse
- current product thinking is still too unstable for a filled-out PRD
- exploratory product material should stay in `tasks/` until it earns promotion

## Reading guidance

For most work, use this order:

1. `README.md`
2. `AGENTS.md`
3. this directory
4. relevant files under `docs/10-prd/` only if they exist and are populated
5. relevant files under `tasks/` if the work is active or exploratory
6. code and tests directly related to the change

Do not read broadly without need.

## Growth principle

The documentation system should grow only when it answers an expensive future question.

A new durable document or layer should exist only when it helps preserve truth that is:

- easy to get wrong
- costly to rediscover
- likely to matter again
- not better enforced mechanically
- clearly owned by one layer

If a proposed document does not pass that bar, keep the material in `tasks/` or do not create the document at all.

## Promotion rule

Promote information into durable documentation only when it becomes:

- stable across more than one task or discussion
- reusable by future contributors or agents
- risky or expensive to lose
- better preserved in prose than in code or tests

Use these destination rules:

- product what/why → `docs/10-prd/`
- implementation truth → code, tests, comments near code, or executable guardrails
- temporary exploration → `tasks/`
- documentation-system rules → `docs/00-meta/`

## Demotion rule

If a durable document becomes mostly:

- speculative
- duplicated elsewhere
- implementation trivia
- stale process ritual
- weakly differentiated from another doc

then simplify it, merge it, move its truth to a better home, or delete it.

Prefer deletion over ceremonial maintenance.

## Anti-patterns

Avoid:

- writing a PRD just because the folder exists
- storing unstable product ideas in durable docs
- creating future documentation layers before they are needed
- duplicating the same truth across `README.md`, `AGENTS.md`, PRD docs, and tasks
- turning this directory into a large process manual
- using docs to compensate for missing executable guardrails

## Change discipline

When updating this directory:

- keep it concise
- keep it local to this repository
- preserve only rules that future humans or agents are likely to need
- avoid copying large framework text into the repo
- update it only when the local documentation system actually changes