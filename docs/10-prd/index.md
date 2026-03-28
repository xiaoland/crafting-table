# PRD layer

## Purpose

This directory is the durable home for **product what and why** when that truth becomes stable enough to preserve.

For this repository, the PRD layer exists as part of the documentation system foundation, but it is intentionally sparse right now.

The product is still too immature for a filled-out PRD.
Current ideas are still exploratory and should not be promoted into durable product documents just to make the layer look complete.

For repository-level documentation system rules, read `docs/00-meta/`.
That layer explains how the documentation system is structured locally and how new durable docs should be admitted.

## What belongs here later

When product truth becomes stable, this layer may contain documents such as:

- product pressures
- product claims
- workflows
- rules and invariants
- scope boundaries
- important product-level open questions
- glossary terms that are costly to let drift

These documents should be added only when they capture truth that is:

- stable across more than one task or discussion
- expensive to rediscover later
- useful to future contributors or agents
- not better kept in code, tests, or temporary task notes

## What does not belong here

Do not use this layer for:

- implementation structure
- technical decomposition
- interface contracts
- build sequencing
- temporary planning
- brainstorming that has not survived discussion
- speculative product doctrine written too early

Those belong in code, tests, future technical design layers if justified, or `tasks/` while the work is still volatile.

## Current status

At the moment, this layer is intentionally minimal.

That means:

- there is not yet an admitted full PRD
- exploratory product thinking should stay lightweight
- temporary product clarification can live in `tasks/`
- durable product docs should appear only after real stability emerges

## Admission rule

Create additional files in this directory only when a product truth has become clear enough that future humans or agents would otherwise be likely to lose it, misread it, or pay too much to rediscover it.

If the truth is still moving, keep it out of the PRD layer.

## Promotion rule

Promote into this layer only:

- durable product meaning
- stable user-visible claims
- stable workflows
- stable product rules
- terminology that needs a canonical meaning

Keep volatile reasoning in `tasks/`.

## Reading guidance

If this layer is still sparse, do not force PRD reading as a ritual.

Read:

1. `README.md`
2. `AGENTS.md`
3. `docs/00-meta/` for repository-level documentation system rules
4. relevant files in this directory only if they exist and are populated
5. relevant files in `tasks/` for active exploration
6. code and tests for implementation truth

## Change discipline

Prefer adding fewer, stronger documents over many weak ones.

If a proposed PRD file does not answer an expensive future question, it probably should not exist yet.