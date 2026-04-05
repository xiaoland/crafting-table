# Tasks

This directory holds short-lived task artifacts for planning, exploration, and execution.

## Purpose

Use tasks to capture work that is still changing, such as:

- bootstrap plans
- experiments
- implementation checklists
- open questions
- temporary coordination notes
- primitive product ideas that are not yet stable enough for durable documentation

Tasks absorb volatility. They are not the long-term source of truth.

## What belongs here

A task folder is appropriate when you need to record:

- the current goal
- constraints for the work
- a proposed approach
- unresolved questions
- next actions
- early product thoughts, rough concepts, and tentative framing
- links to any relevant durable documents

Good task notes are practical and disposable.

At the top level of `tasks/`, admit:

- this `README.md`
- task folders only

Do not create standalone task files directly under `tasks/`.

Inside each task folder, keep the structure minimal:

- one `README.md` for entry and navigation
- only the focused child notes that materially help

## Primitive product ideas

If a product idea is still vague, provisional, or mainly useful for current discussion, keep it in `tasks/`.

That includes things like:

- rough feature notions
- exploratory user stories
- tentative terminology
- possible workflows
- unvalidated claims about what the product should do
- comparisons among several possible product directions

Do not promote this material into the PRD layer just to make the docs feel complete.

## What does not belong here

Do not use this directory for durable product or architecture truth.

Promote stable knowledge to the right place instead:

- durable product intent, scope, rules, or vocabulary → `docs/10-prd/`
- implementation truth → code, tests, and code-level guardrails
- cross-unit technical truth → `docs/20-product-tdd/` only when multi-unit coordination becomes genuinely non-trivial

## Promotion rule

Promote task content only when it has become:

- stable across more than one task or discussion
- useful beyond the current execution step
- costly or risky to rediscover later
- clearly owned by a durable layer

As a rule of thumb:

- primitive idea → keep in `tasks/`
- durable product what/why → move to `docs/10-prd/`
- mechanically enforceable implementation truth → put it in code, tests, or checks

## Lifecycle

1. Create a task when the work is active and still fluid.
2. Update it as you learn.
3. Promote only the durable parts.
4. Close, archive, or delete the task when it no longer helps.

## Suggested task shape

A task folder can use this lightweight structure:

- `README.md` with title, status, date, purpose, navigation, and current outputs
- optional focused child notes for specific questions, trade-offs, or drafts

## Naming

Use simple, sortable folder names such as:

- `0001-bootstrap-foundation/`
- `0002-navigation-shell-spike/`
- `0006-v0.1.0/`

## Rule of thumb

If the note is mainly about **what we are doing right now** or **an idea we are still feeling out**, it probably belongs here.

If it is mainly about **what should remain true later**, it probably belongs somewhere else.
