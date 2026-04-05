# Remote Control and work session linkage

## Status
Active

## Date
2026-04-05

## Problem

`Remote Control` is now a protected `0.1.0` surface.
It needs to feel native to the workbench rather than like a standalone terminal app pasted into it.

The main tension is simple:

- if every remote action requires a session upfront, the workflow becomes heavy
- if remote control is fully standalone, it weakens the "central control surface" claim and drifts into a second product

## Constraints

- `work session` is already a durable product truth
- `0.1.0` should stay human-operated
- remote control is core, not optional
- the product should preserve continuity without turning into a terminal recorder
- host setup should stay reusable across many sessions

## Decision summary

The current recommended `0.1.0` model is:

- a remote connection may begin from the `Remote Control` tab or from inside a `work session`
- session linkage should remain visible before, during, and after remote use
- the product should preserve a small continuity bundle rather than a full transcript or replay model
- saved host profiles should live at workspace scope and be referenced by sessions

## Recommended minimum `0.1.0` linkage model

### 1. Entry rule

- A user may start remote control from the `Remote Control` tab or from inside a `work session`.
- Entering through the `Remote Control` tab should not force a full session-creation flow before the terminal opens.
- But the remote surface should immediately expose one-tap session actions such as:
  - attach to current session
  - attach to recent session
  - create a new session

This keeps quick remote work cheap without cutting it off from the rest of the workbench.

### 2. Attachment rule

- An unattached connection is acceptable temporarily.
- An unattached connection should never become invisible product state.
- Before leaving the remote surface, the user should still be able to attach the activity to a session without reconstructing everything from memory.
- If a connection is already session-linked, the remote header should show that session identity clearly.
- If unattached activity needs a recovery affordance, it should live in `Remote Control`, not in a separate `Home` surface.

This is the minimum needed to prevent "remote control" from becoming a separate utility silo.

### 3. Minimum continuity bundle

For `0.1.0`, the session only needs a small amount of remote continuity:

- host profile used
- last connection time
- file transfers initiated from the workbench
- a short human-written note or outcome
- a quick return path from the session back to the same host

This is intentionally narrow.
The point is to lower restart cost, not to capture or replay terminal history.

### 4. Host ownership rule

- Saved host profiles belong to the broader workspace.
- `work session` references a host profile when remote work is relevant.
- `Goal Forest` may later surface related hosts indirectly, but it should not own canonical host definitions in `0.1.0`.

This keeps hosts reusable and avoids duplicating connection setup across sessions.

## What `0.1.0` does not need here

To make remote control feel native, `0.1.0` does not need:

- terminal transcript capture
- shell replay or process restoration
- automatic command summarization
- agent-prepared remote actions
- remote-specific workflow automation

## Why this cut is the right size

- It preserves low-friction remote access for real life use.
- It keeps `work session` meaningful as the main execution unit.
- It protects the product from collapsing into "an iPad SSH client plus some notes."
- It avoids accidental commitment to a heavy terminal-state model.

## Recommended scope summary

If this note needs to be collapsed back into a shorter scope statement, the minimum message is:

- remote control may begin outside a session, but it must stay one-tap linkable to a session
- the minimum preserved remote context is host, recency, transfers, and a human note
- host profiles belong to workspace scope rather than session scope

## Remaining open questions

- Is one freeform human note enough, or does `0.1.0` need a tiny structure such as "outcome" and "next step"?
