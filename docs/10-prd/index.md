# PRD layer

## Purpose

This directory owns durable product what, why, observable behavior, and business vocabulary.

`0.1.0` now has enough stable product truth to justify the `v9.5` one-way derivation shape:

Drivers -> Behavior -> Domain Structure

Upstream pressure belongs in `_drivers/`.
Product commitments belong in `behavior/`.
Derived semantic stabilization belongs in `domain-structure/`.
Business vocabulary belongs in `glossary.md`.

## Current file set

- `glossary.md`
- `_drivers/market-and-user-pressures.md`
- `_drivers/business-and-service-objectives.md`
- `_drivers/hard-constraints.md`
- `_drivers/operational-realities.md`
- `behavior/claims.md`
- `behavior/capabilities.md`
- `behavior/workflows.md`
- `behavior/rules-and-invariants.md`
- `behavior/scope.md`
- `domain-structure/derived-boundaries.md`
- `domain-structure/cross-domain-interactions.md`

## Writing rule

Keep each file sparse and pressure-driven.

Do not use this package for implementation structure, interface contracts, or speculative architecture.
Put cross-unit realization memory in `docs/20-product-tdd/`.
