# Meta engine

## Purpose

This directory is the repository-local adoption point for `Sustainable Vibe Coding Framework v9.5`.

It owns only the reusable operating guidance that future humans or agents would otherwise have to rediscover:

- typed input routes
- mode SOPs
- framework concepts that are easy to confuse
- local growth rules for the documentation system

This directory is not product truth and not implementation truth.

## Current files

- `input-intent.md`
- `input-constraint.md`
- `input-reality.md`
- `input-artifact.md`
- `mode-a-explore.md`
- `mode-b-solidify.md`
- `mode-c-execute.md`
- `mode-d-diagnose.md`
- `concepts.md`
- `growth-rules.md`

Keep this layer small. Add a new meta doc only when repeated drift shows that the existing routes or SOPs are not enough.

## Current admitted layers

The repository currently admits only these durable layers:

- `docs/00-meta/` - local route, mode, and ontology guidance
- `docs/10-prd/` - durable product what, why, observable behavior, and business glossary

It also admits:

- `tasks/` - volatile task packets, diagnostics, and temporary reasoning
- code, tests, build settings, and executable guardrails - implementation truth

The repository does not admit these layers by default yet:

- `docs/15-alignment/`
- `docs/20-product-tdd/`
- `docs/30-unit-tdd/`
- `docs/40-deployment/`

Add them only when real pressure justifies them.

## Route vs mode

Input type and mode answer different questions:

- input type decides durable ownership and blast radius
- mode decides the current working posture
- one task may move across several modes without changing owner

For non-trivial work, keep a task packet in `tasks/` with the three MVT anchors:

- Objective & Hypothesis
- Guardrails Touched
- Verification

## Reading guidance

For most work, use this order:

1. `README.md`
2. `AGENTS.md`
3. the matching `docs/00-meta/input-*.md`
4. the current `docs/00-meta/mode-*.md`, if needed
5. relevant files under `docs/10-prd/`
6. relevant task packets under `tasks/`
7. code and tests directly related to the change

Read `docs/00-meta/concepts.md` only when boundary language is ambiguous or the user explicitly asks for framework concepts.

## Growth principle

The documentation system should grow only when it answers an expensive future question.

A durable doc should exist only when it preserves truth that is:

- stable enough to survive this task
- costly to rediscover
- likely to matter again
- not better enforced mechanically
- clearly owned by one layer

If that bar is not met, keep the material in `tasks/` or in code/tests instead.
