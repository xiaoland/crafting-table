# Task 0001 — Bootstrap foundation

## Status
Done

## MVT Core

- Objective & Hypothesis: initialize the repository for honest early exploration; the expected result is a minimal app and documentation baseline that future work can build on without pretending the product is already fully defined.
- Guardrails Touched: keep durable product truth sparse; keep implementation truth in code, tests, and executable guardrails.
- Verification: the repo has a minimal app shell, a minimal doc system, and no unjustified durable technical layers.

## Purpose
Initialize the repository for early-stage exploration with:

- a minimal `Swift + SwiftUI` app shell
- an `iPad-first` direction
- a lightweight documentation baseline aligned with the minimal `Sustainable Vibe Coding` model

This task captures the initial setup work for a repository whose product direction is still immature. The goal of the bootstrap was to create a clean foundation for later discovery and implementation, not to pretend that the product is already well-defined.

## Why this is a task, not permanent architecture
Per the repository’s documentation discipline:

- this work was primarily setup and coordination
- the product is still too undefined for a filled-out PRD
- durable product truth should be promoted later, only after it becomes stable and repeatedly useful
- implementation truth should remain in code, tests, and executable guardrails

This note should not become a second source of truth for product behavior.

## Scope
Included:

- repository bootstrap
- minimal app shell scaffold
- initial documentation structure
- guardrails for future development discussions
- a PRD-layer baseline under `docs/10-prd/`

Not included:

- committed feature architecture
- a populated PRD based on speculative ideas
- `docs/20-product-tdd/`, `docs/30-unit-tdd/`, or `docs/40-deployment/` before they are justified
- implementation of mail, calendar, tasks, or multi-machine flows
- deep domain modeling

## Decisions made

### 1. Keep initialization intentionally narrow
The project is still exploratory. The bootstrap should prepare future work rather than prematurely encode product decisions.

### 2. Establish the PRD layer without inventing PRD content
The repository should include the PRD layer location, `docs/10-prd/`, but that layer should stay intentionally sparse until durable product truth actually exists.

### 3. Let tasks absorb product volatility
Primitive ideas, open-ended product discussion, and temporary reasoning should stay in `tasks/` until they survive enough change to deserve promotion.

### 4. Favor iPad-first
The initial app direction should optimize for iPad usage and a spacious SwiftUI shell, without committing to full multi-platform behavior yet.

### 5. Separate durable from volatile knowledge
When stable product truth appears, it belongs in `docs/10-prd/`.
Volatile planning and bootstrap notes belong in `tasks/`.

## Expected repository outcomes
After this task, the repository should contain:

- a minimal app entrypoint and navigation shell
- a home or placeholder surface for future exploration
- `README.md` updated to explain repo purpose and workflow
- `AGENTS.md` updated to guide future contributors and agents
- `docs/10-prd/` initialized as the PRD-layer baseline
- `tasks/` established as the volatile task layer

## Promotion candidates
If these become stable and repeatedly referenced, promote them into `docs/10-prd/` in the smallest durable form that fits:

- product vocabulary that stops drifting
- product claims that become real commitments
- workflows that remain important across multiple tasks
- rules or invariants that should constrain future decisions
- scope boundaries or open questions that become durable enough to preserve

## Explicit non-promotions for now
Do **not** promote the following yet unless real pressure emerges:

- speculative product ideas that are still changing quickly
- fake certainty written only to fill out a PRD structure
- `docs/20-product-tdd/`, `docs/30-unit-tdd/`, or `docs/40-deployment/` without clear admission pressure
- full UI maps
- system-wide topology docs
- per-unit technical design docs
- extensive implementation plans

## Follow-up suggestions
Good next steps after bootstrap:

1. Keep the app shell simple and useful as a discussion artifact.
2. Use tasks to explore product ideas until some of them become durable.
3. Promote only the smallest stable product truths into `docs/10-prd/`.
4. Add new documentation layers only when drift or complexity clearly justifies them.

## Exit condition
This task is complete when the repository is ready for iterative product discussion and incremental app development, while keeping speculative product thinking out of durable documentation until it earns promotion.
