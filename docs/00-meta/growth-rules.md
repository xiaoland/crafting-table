# Documentation growth rules

## Purpose

This file defines how the repository's documentation system may grow under the local `SVC v9.5` interpretation.

The goal is to preserve expensive truths without turning docs into a second software system.

## Governing idea

Documentation is selective memory.

Before adding or editing a durable doc, answer two questions separately:

1. What kind of perturbation is this: Intent, Constraint, Reality, or Artifact?
2. Which layer should own the truth once the work is no longer volatile?

Mode selection helps you work, but it does not decide ownership.

## Current admitted layers

The repository currently admits these durable layers:

- `docs/00-meta/` for reusable workflow rules, route protocols, and framework concepts
- `docs/10-prd/` for durable product what/why, observable behavior, and business vocabulary
- `docs/20-product-tdd/` for cross-unit technical truth needed by `0.1.0`

It also admits:

- `tasks/` for volatile planning, exploration, diagnostics, and artifacts
- code, tests, build settings, and executable guardrails for implementation truth

The following layers are still not admitted by default and should not be created until pressure is real:

- `docs/15-alignment/`
- `docs/30-unit-tdd/`
- `docs/40-deployment/`

## Admission note for `docs/20-product-tdd/`

`docs/20-product-tdd/` is admitted now because `0.1.0` already has several durable product surfaces whose authority paths would otherwise drift during implementation.
Admit `30-unit-tdd` later only when one unit becomes complex enough that cross-feature memory is no longer sufficient.

## Promotion test

Promote information into durable docs only when all are true:

1. it is stable across more than one task or discussion
2. future humans or agents will likely need it again
3. rediscovering it later would be risky or expensive
4. it is not better enforced in code, tests, CI, or runtime checks
5. the durable owner is clear

If any of these are unclear, keep the material in `tasks/`.

## Durable destination rules

Use the smallest correct destination:

- reusable route or mode guidance -> `docs/00-meta/`
- framework concepts and boundary language -> `docs/00-meta/concepts.md`
- durable product what/why and observable behavior -> `docs/10-prd/`
- business vocabulary -> `docs/10-prd/glossary.md`
- cross-unit technical contracts, topology, and authority paths -> `docs/20-product-tdd/`
- mechanically enforceable truth -> code, tests, build settings, and executable checks
- volatile reasoning, diagnostics, and temporary artifacts -> `tasks/`

## PRD growth rule

The PRD layer now uses the `v9.5` one-way derivation shape because `0.1.0` has enough durable product truth to justify it:

- `_drivers/` for upstream pressure sources
- `behavior/` for product commitments
- `domain-structure/` for derived semantic stabilization
- `glossary.md` for business language

Keep each file sparse and honest. Do not fill the tree with speculative doctrine.

## Task rule

`tasks/` is the entropy buffer of the system.

Every non-trivial task packet README must include these anchors:

- Objective & Hypothesis
- Guardrails Touched
- Verification

Focused child notes may inherit that packet context, but once a note becomes independently actionable or reusable outside the packet, add its own anchors too.

## Demotion rule

If a durable doc no longer answers an expensive future question, simplify it, merge it, move its truth to a better home, or delete it.

Prefer deletion over ritual maintenance.
