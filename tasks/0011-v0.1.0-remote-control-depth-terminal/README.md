# Task 0011 - v0.1.0 remote control depth terminal

## Status
Proposed

## Date
2026-04-25

## MVT Core

- Objective & Hypothesis: deepen the `Remote Control` surface from layout-level placeholder into the smallest real terminal-first workflow with file transfer and session linkage; the expected result is a high-value action surface that remains part of the Crafting Table loop.
- Guardrails Touched: preserve `Remote Control` as session-aware product behavior; keep host profiles at workspace scope; avoid admitting agent-operated remote workflows into `0.1.0`.
- Verification: connect to a saved host, run terminal work, initiate upload or download, attach or confirm session linkage, and preserve the minimum continuity bundle in a work session.

## Classification

- Input Type: Constraint
- Active Mode: Explore -> Solidify -> Execute
- Governing Anchors: `AGENTS.md`, `docs/00-meta/input-constraint.md`, `docs/00-meta/mode-a-explore.md`, `docs/00-meta/mode-b-solidify.md`, `docs/00-meta/mode-c-execute.md`, `docs/10-prd/behavior/scope.md`, `docs/10-prd/behavior/workflows.md`, `docs/20-product-tdd/system-state-and-authority.md`, `tasks/0006-v0.1.0/remote-control-session-linkage.md`, `tasks/0006-v0.1.0/minimum-screen-inventory.md`, `tasks/0006-v0.1.0/transition-map.md`

## Purpose

This packet separates the real remote-control workflow from the first `0.1.0` shell and layout implementation.

The immediate `0.1.0` implementation can include disconnected and connected Remote Control screen states, host list UI, session linkage header, and file-transfer placeholders. This packet owns the deeper work required to make Remote Control useful against a real machine.

## Scope

In scope for this slice:

- choose a mature terminal or SSH implementation path suitable for iPad-first SwiftUI
- create and edit saved host profiles at workspace scope
- connect to a saved host
- show connected terminal state inside the admitted Remote Control screen
- support the first upload and download path in the same workflow
- decide the first file-transfer path, such as SFTP or another single explicit route
- show session linkage in the remote header using the agreed `C1` direction
- attach remote activity to current, recent, or new work session
- record host, recency, transfers, and a short human note against the linked session
- cover the minimum terminal UX: input, resize, copy and paste, disconnect, reconnect, and error state

Out of scope for this slice:

- GUI remote desktop
- terminal replay or transcript capture
- automatic command summarization
- agent-prepared remote actions
- integrated agent-output review
- broad provider integrations
- a full remote file browser beyond the first upload and download path

## Temporary Assumptions

- The first layout slice will already establish the Remote Control disconnected and connected states.
- `C1` is the current agreed header direction: a session chip when linked and an attach action when unlinked.
- File transfer can start with explicit user-initiated upload and download actions before any richer file browser exists.
- Any terminal library choice should be proven with a small spike before it becomes durable Product TDD.
- A local test host or controlled fixture should exist before this slice claims real workflow completion.

## Open Questions

- Which terminal or SSH library is the best first fit for the SwiftUI/iPad target?
- What is the smallest host profile shape that still supports one-tap reconnection?
- Should the first transfer path be SFTP, SCP, or a narrower app-controlled mechanism?
- Should the continuity note remain freeform, or split into outcome and next step?
- In connected state, should return-to-session live in the main header or a smaller contextual control?
- What local test host or fixture should verify the first real connection flow?
- What minimum credential handling belongs in host profile create/edit for `0.1.0`?

## Verification Plan

- Add or select a host profile.
- Connect from Remote Control disconnected state into connected state.
- Run a simple command and keep the terminal usable on iPad layout.
- Verify input, resize, copy and paste, disconnect, reconnect, and error recovery.
- Upload or download a small file through the admitted workflow.
- Attach an initially unlinked remote activity to a session.
- Confirm session continuity records host, recency, transfers, and note.

## Promotion Candidates

- The chosen terminal/SSH implementation path may become Product TDD once proven.
- The finalized host profile contract may move to `docs/20-product-tdd/cross-unit-contracts.md`.
- Any product-visible shift in Remote Control behavior should move through `docs/10-prd/behavior/`.
