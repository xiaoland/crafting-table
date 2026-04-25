# Task 0010 - v0.1.0 persistence data strategy

## Status
Active

## Date
2026-04-25

## MVT Core

- Objective & Hypothesis: define and implement the smallest persistence and data strategy that lets the `0.1.0` shell, sessions, Goal Forest, capture, host profiles, and remote continuity survive app relaunch; the expected result is repeat-use continuity with a light and reversible storage architecture.
- Guardrails Touched: keep product behavior aligned with `tasks/0006-v0.1.0/`; respect state authority in `docs/20-product-tdd/system-state-and-authority.md`; keep storage choices reversible until real implementation pressure proves durability.
- Verification: create, edit, relaunch, and recover sample Goal Forest nodes, work sessions, captures, host profiles, and remote continuity records through executable app checks or focused tests.

## Classification

- Input Type: Constraint
- Active Mode: Explore -> Solidify -> Execute
- Governing Anchors: `AGENTS.md`, `docs/00-meta/input-constraint.md`, `docs/00-meta/mode-a-explore.md`, `docs/00-meta/mode-b-solidify.md`, `docs/00-meta/mode-c-execute.md`, `docs/20-product-tdd/system-state-and-authority.md`, `docs/20-product-tdd/cross-unit-contracts.md`, `tasks/0006-v0.1.0/`

## Purpose

This packet separates the persistence slice from the first `0.1.0` layout and shell implementation.

The first shell cut started with in-memory seed data. This packet now owns the first local persistence boundary for that app data.

## Scope

In scope for this slice:

- choose the first persistence mechanism for local personal use
- persist Goal Forest nodes and relationships needed by the first operable screen
- persist Goal Forest DAG edges, cross-links, and fixed grid layout positions
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

- The first shell implementation used in-memory data to validate navigation and layout.
- Persistence is now active after the shell, minimum screens, and overlays reached a stable first implementation.
- The first data model should follow existing product authority boundaries before introducing implementation convenience shortcuts.
- Host profile metadata may be app data, while secrets should be handled through the smallest secure platform-backed path that satisfies the first remote workflow.

## First Implementation Decision

- Local persistence uses a versioned Codable JSON workspace document at app-support scope.
- `WorkspaceDocument` is the first durable data shape for nodes, DAG edges, sessions, captures, host profiles, and remote continuity records.
- `WorkspaceStore` owns load/save and is injected at the app root.
- Existing feature views continue to receive value props and submit callbacks through `RootView`.
- Shell route, sheet presentation, split-view visibility, and live remote connection state stay runtime-only.
- Host profile app data stores `credentialReferenceID`; credential secret material belongs to the platform credential store.
- Seed data becomes the first local workspace document when the saved file is absent.
- Stable string IDs are admitted for the first slice because user data, links, and relaunch recovery need durable references.

## State Objects To Cover

- Goal Forest nodes and nearby relationships
- Goal Forest node grid positions and DAG edges
- work sessions and session lifecycle state
- captures and explicit placement links
- host profiles
- host credential references
- remote continuity records containing host, recency, transfers, and a short human note
- runtime-only UI state that should remain outside durable storage

## Open Questions

- When should the Codable file be promoted to SwiftData, SQLite, or another store under real query or migration pressure?
- Does sample data need an explicit reset or demo-workspace affordance during early development?
- Does remote continuity need a single freeform note, or small fields such as outcome and next step?
- Should session-to-Goal Forest linkage support one primary link in `0.1.0`, or only a list of related links?
- Should unlinked captures receive a dedicated seed-pool surface, or continue as captures with an empty placement link?
- Should grid positions remain stored directly, or should a later graph-layout pass derive them from topology?

## Verification Plan

- Create sample records for each admitted state object.
- Mutate each state object through the app surface or focused model tests.
- Relaunch or recreate the store and confirm recovery.
- Confirm authority boundaries remain visible in code ownership and write paths.
- Confirm runtime-only UI state can reset while product continuity remains durable.
- Confirm host secrets are outside plain app data if real credentials enter the workflow.

## Implementation Evidence

- `WorkspaceDocument` covers Goal Forest nodes, DAG edges, fixed grid positions, work sessions, captures with optional placement, host profiles, and remote continuity records.
- `WorkspaceStore` loads an existing local document or writes the seed document on first launch.
- Capture save creates a durable capture with optional session and node links.
- Node edit updates title, summary, and fixed grid position.
- Host profile edit updates metadata while preserving credential reference semantics.
- Work session status changes persist active, paused, and done state while keeping one active session in the sidebar model.
- Linked Remote Control connect or attach creates or updates a session-owned remote continuity record.
- Current executable verification: `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` succeeded.
- Focused store probe wrote a temporary workspace JSON, mutated capture, session status, and remote continuity, reloaded `WorkspaceStore`, and recovered the saved records.

## Residual Verification Gap

- The repository currently lacks a test target.
- Relaunch recovery is covered by a temporary store probe and still awaits automated UI or model test coverage in the repository.
- Host profile creation is still an edit-only surface in this slice.

## Promotion Candidates

- Durable storage authority rules may move to `docs/20-product-tdd/` after the first implementation proves them.
- Product-facing behavior changes should move through `docs/10-prd/` only when they change observable user behavior.
