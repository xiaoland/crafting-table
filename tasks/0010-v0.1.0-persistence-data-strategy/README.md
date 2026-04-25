# Task 0010 - v0.1.0 persistence data strategy

## Status
Proposed

## Date
2026-04-25

## MVT Core

- Objective & Hypothesis: define and implement the smallest persistence and data strategy that lets the `0.1.0` shell, sessions, Goal Forest, capture, host profiles, and remote continuity survive app relaunch; the expected result is repeat-use continuity without committing early to a heavy storage architecture.
- Guardrails Touched: keep product behavior aligned with `tasks/0006-v0.1.0/`; respect state authority in `docs/20-product-tdd/system-state-and-authority.md`; keep storage choices reversible until real implementation pressure proves durability.
- Verification: create, edit, relaunch, and recover sample Goal Forest nodes, work sessions, captures, host profiles, and remote continuity records through executable app checks or focused tests.

## Classification

- Input Type: Constraint
- Active Mode: Explore -> Solidify -> Execute
- Governing Anchors: `AGENTS.md`, `docs/00-meta/input-constraint.md`, `docs/00-meta/mode-a-explore.md`, `docs/00-meta/mode-b-solidify.md`, `docs/00-meta/mode-c-execute.md`, `docs/20-product-tdd/system-state-and-authority.md`, `docs/20-product-tdd/cross-unit-contracts.md`, `tasks/0006-v0.1.0/`

## Purpose

This packet separates the persistence slice from the first `0.1.0` layout and shell implementation.

The immediate `0.1.0` implementation can start with mock or in-memory seed data while this packet preserves the later persistence decision as its own bounded task.

## Scope

In scope for this slice:

- choose the first persistence mechanism for local personal use
- persist Goal Forest nodes and relationships needed by the first operable screen
- persist work sessions with active, paused, and done state
- persist captures before and after explicit placement
- persist saved host profiles at workspace scope
- persist the minimum remote continuity bundle recorded against a session
- define a small seed or migration strategy if early mock data needs to become local data
- separate durable app data from runtime-only UI state
- define the minimum credential-handling boundary for host profiles

Out of scope for this slice:

- cloud sync
- multi-user collaboration
- full history or audit trails
- terminal transcript persistence
- agent-generated restructuring history
- a generalized storage abstraction beyond the first real app need
- broad sync or migration seams beyond a documented escape path

## Temporary Assumptions

- The first implementation may use mock or in-memory data to validate navigation and layout.
- Persistence becomes active after the shell, minimum screens, and overlays have a stable first implementation.
- The first data model should follow existing product authority boundaries before introducing implementation convenience shortcuts.
- Host profile metadata may be app data, while secrets should be handled through the smallest secure platform-backed path that satisfies the first remote workflow.

## State Objects To Cover

- Goal Forest nodes and nearby relationships
- work sessions and session lifecycle state
- captures and explicit placement links
- host profiles
- host credential references
- remote continuity records containing host, recency, transfers, and a short human note
- runtime-only UI state that should remain outside durable storage

## Open Questions

- Should the first local persistence layer use SwiftData, plain Codable files, SQLite, or another small local option?
- Which data deserves stable identifiers in the first slice?
- How should sample data and user-created data be separated during early development?
- Does remote continuity need a single freeform note, or small fields such as outcome and next step?
- Should session-to-Goal Forest linkage support one primary link in `0.1.0`, or only a list of related links?
- Should unlinked captures exist as an explicit seed pool state, or as captures with no placement link?

## Verification Plan

- Create sample records for each admitted state object.
- Mutate each state object through the app surface or focused model tests.
- Relaunch or recreate the store and confirm recovery.
- Confirm authority boundaries remain visible in code ownership and write paths.
- Confirm runtime-only UI state can reset without losing product continuity.
- Confirm host secrets are outside plain app data if real credentials enter the workflow.

## Promotion Candidates

- Durable storage authority rules may move to `docs/20-product-tdd/` after the first implementation proves them.
- Product-facing behavior changes should move through `docs/10-prd/` only when they change observable user behavior.
