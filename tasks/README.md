# Tasks

This directory is the volatile workspace for planning, exploration, diagnostics, and temporary artifacts.

## Purpose

Use `tasks/` when the work is still changing, evidence is still being gathered, or the result should not yet become durable truth.

Typical task content includes:

- active exploration
- implementation sequencing notes
- diagnostic evidence
- temporary coordination context
- one-off artifacts or comparisons
- product ideas that are not yet stable enough for PRD

## Task packet minimum

Every non-trivial task packet README must include these anchors:

- `Objective & Hypothesis`
- `Guardrails Touched`
- `Verification`

Useful optional fields when they actually help:

- `Input Type`
- `Active Mode`
- `Governing Anchors`
- `Temporary Assumptions`
- `Promotion Candidates`

Focused child notes may inherit the packet context, but if a child note becomes independently actionable or reusable outside the packet, add its own anchors too.

## Top-level structure

At the top level of `tasks/`, admit only:

- this `README.md`
- task folders

Do not create standalone task files directly under `tasks/`.

Inside each task folder, keep the structure minimal:

- one `README.md` as the packet entrypoint
- only the focused child notes that materially help the current task

## Durable destination reminders

Promote stable material only when it passes the promotion test and has a clear durable owner:

- product what/why and business language -> `docs/10-prd/`
- reusable workflow or ontology rules -> `docs/00-meta/`
- mechanically enforceable implementation truth -> code, tests, build settings, and executable checks
- volatile reasoning -> keep it in `tasks/`

## Naming

Use simple, sortable folder names such as:

- `0001-bootstrap-foundation/`
- `0006-v0.1.0/`
- `0007-svc-v9.5-alignment/`
