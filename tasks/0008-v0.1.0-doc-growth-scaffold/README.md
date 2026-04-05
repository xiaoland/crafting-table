# Task 0008 - v0.1.0 doc growth scaffold

## Status
Done

## Date
2026-04-05

## MVT Core

- Objective & Hypothesis: admit only the documentation skeleton that `0.1.0` implementation will actually need; the expected result is a sparse but durable PRD and Product TDD package that can grow naturally during development.
- Guardrails Touched: do not create layers that have not earned admission; do not duplicate product truth across task notes and durable docs.
- Verification: structured PRD files exist, `docs/20-product-tdd/` is admitted with real cross-unit content, and active `0.1.0` task read paths point to the new durable anchors.

## Classification

- Input Type: Constraint
- Active Mode: Solidify -> Execute
- Governing Anchors: `AGENTS.md`, `docs/00-meta/`, `docs/10-prd/`, `tasks/0006-v0.1.0/`, `/Users/lanzhijiang/Development/svc/src/index.md`

## Execution notes

- admit the smallest durable structure that prevents `0.1.0` drift
- promote only already-stable product truth out of task notes
- keep `docs/30-unit-tdd/`, `docs/40-deployment/`, and `docs/15-alignment/` unadmitted until pressure is real
- Result: the repo now has a structured PRD package plus a minimal Product TDD package that can guide `0.1.0` implementation without over-admitting later layers.
