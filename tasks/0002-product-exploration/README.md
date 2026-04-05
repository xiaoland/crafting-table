# Task 0002 — Product exploration

## Status
Active

## MVT Core

- Objective & Hypothesis: keep early product exploration volatile while testing whether a believable core job and first workflow are emerging; the expected result is clearer product direction without premature PRD promotion.
- Guardrails Touched: do not invent stable product truth too early; do not smuggle implementation structure into product exploration.
- Verification: durable conclusions are promoted only when they recur, while open questions and competing ideas remain in this task packet.

## Classification

- Input Type: Intent
- Active Mode: Explore

## Purpose

Capture early product exploration for `Xiaoland Workbench` while the product is still too immature for a filled-out PRD.

This task is the working place for primitive ideas, rough framing, and open questions that are useful right now but not yet stable enough for durable documentation.

## Why this is a task

At the current stage:

- product direction is still exploratory
- several ideas are interesting but not yet committed
- terminology is still moving
- likely first workflows are still unclear

That makes `tasks/` the correct home for this material.

Do not promote ideas from this file into `docs/10-prd/` just to make the documentation tree look complete.

## Current context

The repository currently has:

- an iPad-first SwiftUI app foundation
- a lightweight documentation system baseline
- a sparse PRD layer reserved for future durable product truth

This task should help explore product direction without inventing false certainty.

## Working assumptions

These are current exploration assumptions, not durable product truth:

- the product is personal-first rather than team-first
- iPad is the primary design target for now
- the near-term goal is a believable product direction, not a broad feature map
- the first useful version should likely be narrow and legible rather than ambitious
- documentation should preserve only stable conclusions, not raw ideation

## Exploration areas

### 1. Core job of the product

Possible directions worth exploring:

- a place to resume meaningful work quickly
- a personal coordination center for active work
- a workspace for asking questions with context attached
- a lightweight layer connecting notes, tasks, schedule, and messages
- some combination of the above

Key question:

- what is the smallest believable job this product does better than a notes app plus ad hoc task tracking?

### 2. What “workbench” might mean

Possible interpretations:

- a home for current work
- a system for preserving context between sessions
- a calm operational overview
- a container for connected work threads
- a conversation surface with memory

Key question:

- which interpretation is actually strong enough to anchor the first product shape?

### 3. Candidate first-user value

Possible early value signals:

- lower restart cost after interruption
- clearer sense of what to do next
- easier recovery of recent context
- less manual stitching across tools
- better continuity between thought and action

Key question:

- which one of these would feel obviously valuable in an early prototype?

### 4. iPad-first implications

Questions worth testing:

- what should the home screen optimize for on iPad?
- should the first structure be split-view, sidebar-driven, or single-focus?
- what information deserves permanent visibility?
- how much writing, reading, and triage should happen from the main surface?

### 5. Possible adjacent surfaces

These are exploration topics, not commitments:

- tasks
- calendar
- mail or communication
- recent sessions
- active threads
- captured questions
- references and notes

Key question:

- which adjacent surface, if any, is necessary for the first convincing version?

## Rough idea fragments

These fragments are intentionally loose.

### Fragment A — Resume work quickly
The product might be strongest if it helps answer:

- what I was doing
- why it mattered
- what changed
- what the next good step is

### Fragment B — Ask with context
The product might support asking questions from within active work, with local context already attached.

### Fragment C — Current work is a first-class object
Instead of just storing notes or tasks, the product might make “current work” explicit and easy to re-enter.

### Fragment D — Calm operational center
The product should avoid becoming another maintenance-heavy system.

### Fragment E — Connected work, not flat lists
There may be a better model than disconnected notes plus todos, but the repo should not pretend that model is already known.

## Constraints for exploration

- do not assume broad integrations early
- do not assume sync architecture before product pressure exists
- do not assume a final domain model yet
- do not turn metaphors into product truth too early
- do not create durable docs until a conclusion becomes stable and repeatedly useful

## Open questions

### Product identity

- Is the first product primarily about orientation, coordination, or inquiry?
- Is `workbench` the real product concept, or only a temporary umbrella term?
- Is there one strong core loop, or are there several weakly related ideas?

### User value

- What user pain is most worth reducing first?
- What would make this clearly better than existing lightweight tools?
- What would make the first version feel calm instead of busy?

### Interaction model

- What should be visible immediately on launch?
- What should count as the main object on the home surface?
- Should the product emphasize one active context or several nearby contexts?

### Vocabulary

- Which terms are genuinely useful?
- Which terms are poetic but operationally weak?
- Which concepts should stay internal until they survive more testing?

### Scope

- What is explicitly out of scope for the first meaningful version?
- Which adjacent surfaces are distractions at this stage?
- What should be proven before any major architecture expansion?

## Suggested next steps

1. Pick one candidate core job and test whether it can anchor a narrow first product shape.
2. Sketch one or two believable first workflows in a future task if needed.
3. Identify which current terms are useful enough to keep using during exploration.
4. Keep the app shell simple enough to support discussion rather than overcommitting to implementation.
5. Promote only durable conclusions into `docs/10-prd/`.

## Promotion notes

Promote material from this task only when it becomes:

- stable across multiple discussions or tasks
- clearly product-level
- costly to rediscover later
- worth preserving for future contributors or agents

Possible future promotion targets:

- stable product claims
- durable workflow descriptions
- stable terminology
- clear scope boundaries
- product rules that should constrain future decisions

## Non-goal of this task

This task does **not** attempt to:

- define a full PRD
- settle the feature set
- define technical architecture
- commit to integrations
- resolve the full domain model

Its job is only to hold exploratory product thinking in the right volatile place.
