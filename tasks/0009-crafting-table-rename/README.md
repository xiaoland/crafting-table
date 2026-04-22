# Task 0009 - Crafting Table rename

## Status
Done

## Date
2026-04-22

## MVT Core

- Objective & Hypothesis: rename the product and repository from `Xiaoland Workbench` to `(xiaoland's) Crafting Table`; the expected result is aligned durable docs, app-visible naming, technical identifiers, and GitHub repository metadata without over-expanding scope.
- Guardrails Touched: keep the change small and reversible; separate human-facing brand naming from technical identifiers where punctuation or readability would otherwise degrade maintainability.
- Verification: repository text search no longer treats `Xiaoland Workbench` or `xiaoland/workbench` as current truth, Xcode still builds with the renamed project/target/scheme, and the GitHub remote points at the renamed repository.

## Classification

- Input Type: Intent
- Active Mode: Solidify -> Execute
- Governing Anchors: `AGENTS.md`, `docs/00-meta/input-intent.md`, `docs/00-meta/mode-c-execute.md`, `docs/10-prd/index.md`, `docs/10-prd/glossary.md`, `CraftingTable/AGENTS.md`

## Naming decision

- Human-facing product name: `(xiaoland's) Crafting Table`
- Allowed short form in copy: `Crafting Table`
- Abbreviation: `CT`
- Technical identifiers: `CraftingTable` for Swift/Xcode symbols and `crafting-table` for repository slug

## Execution notes

- Treat earlier `workbench` wording as historical unless it still describes a generic product category rather than the actual product name.
- Avoid touching unrelated in-flight task notes under `tasks/0006-v0.1.0/`.
