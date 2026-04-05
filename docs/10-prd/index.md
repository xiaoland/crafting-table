# PRD layer

## Purpose

This directory owns durable product what, why, observable behavior, and business vocabulary.

It is intentionally sparse because the product is still early. The goal is to preserve only product truths that future humans or agents would otherwise be likely to lose, misread, or pay too much to rediscover.

## Current shape

The repository is still using the minimal `v9.5` PRD shape:

- `index.md` - what this layer owns
- `glossary.md` - stable business and product language
- `early-product-truths.md` - the currently admitted durable product truths

If the PRD layer grows materially later, prefer the `v9.5` one-way derivation shape (`_drivers/`, `behavior/`, `domain-structure/`) instead of adding flat files casually.

## What belongs here

Use this layer for:

- durable product pressures
- stable product claims and scope boundaries
- stable user-visible workflows or rules
- business vocabulary that needs canonical meaning

## What does not belong here

Do not use this layer for:

- implementation structure
- technical decomposition or interface contracts
- build sequencing
- temporary planning or brainstorming
- speculative product doctrine written only to look complete

Keep those in code, tests, future technical layers if justified, or `tasks/` while the work is still volatile.

## Vocabulary boundary

Business and product language belongs in `glossary.md`.

Product truth docs should use that vocabulary consistently instead of redefining terms in multiple places.

## Admission rule

Create or expand PRD files only when a product truth is stable across more than one task or discussion, useful to future contributors, and not better kept in code/tests or task notes.
