# work session and Goal Forest language

## Status
Active

## Date
2026-04-05

## Problem

`work session` is already the first-class execution object.
At the same time, `Goal Forest` is intended to be a user-facing product term.

If those two ideas are not separated cleanly, the product language becomes poetic but operationally blurry.

## Decision summary

The current recommended `0.1.0` interpretation is:

- `work session` answers: what am I doing now?
- `Goal Forest` answers: where does this work belong?
- capture answers: what did I just collect before I know where it belongs?
- shell answers: which surface am I in, and how do I move to the next action?

This creates a clearer role split without abandoning the `Goal Forest` term.

## Recommended role model for `0.1.0`

### 1. `work session` is the execution layer

Use `work session` for:

- active focus
- execution context
- remote actions
- continuity notes
- recent activity

This should remain the primary "doing now" object in product language and UI emphasis.

### 2. `Goal Forest` is the longer-lived orientation layer

Use `Goal Forest` for:

- placing goals and related work in visible relationship
- attaching sessions and captures to meaningful context
- navigating nearby related work
- preserving longer-lived structure across many sessions

`Goal Forest` gives shape and placement.
It does not replace `work session` as the main unit of action.

### 3. Capture stays cheap

Use capture or seed-pool style intake when:

- the user needs to save something quickly
- the correct session is unclear
- the correct `Goal Forest` placement is still unknown

This matters because forcing early classification would contradict one of the clearest stable product pressures.

## Relationship rule

The simplest relationship model for `0.1.0` is:

- a session may start from a shell-level recent-session affordance
- a session may also start from a `Goal Forest` node
- a session may remain temporarily unlinked if the user needs to begin quickly
- a `Goal Forest` node may gather multiple sessions over time
- linking a session into `Goal Forest` adds context around the work; it does not demote the session into a minor attachment

This keeps both concepts real without making either one absorb the other.

## Language rule

### Keep the metaphor at the surface-name level

`Goal Forest` can stay as a product term because it adds identity and memorability.
But the metaphor should not dominate core action labels.

### Keep operational labels literal

When clarity matters, prefer labels such as:

- create node
- link session
- attach capture
- move
- archive
- related work

Avoid extending the forest metaphor into action verbs that users must decode while they are trying to do work.

### Pair metaphor with literal helper copy

When the UI needs extra clarity, pair `Goal Forest` with literal supporting language such as:

- goals and related work
- map of goals, sessions, and captures
- related structure around this work

This matches the existing PRD guidance that metaphorical language should be paired with literal operational language when needed.

## UI emphasis rule for `0.1.0`

- The shell should privilege starting or resuming a `work session` over abstract browsing.
- `Goal Forest` screens should surface linked sessions and captures, not just node-to-node structure.
- `work session` screens should show nearby `Goal Forest` context without forcing full-graph navigation.

This keeps the first release oriented toward action instead of symbolic structure.

## What this does not imply

These clarifications do not mean:

- `Goal Forest` promises sophisticated graph behavior in `0.1.0`
- every session must be classified before work begins
- `work session` is merely a note attached to a goal node
- the app should speak only in metaphor

## Recommended scope summary

If this note needs to be collapsed back into a short scope statement, the minimum message is:

- `work session` remains the primary execution unit
- `Goal Forest` is the longer-lived map that gives sessions and captures context
- `Goal Forest` may keep its metaphorical name, but operational copy should stay literal

## Remaining open questions

- Should a session show one primary `Goal Forest` link in `0.1.0`, or simply list related links without a primary one?
- In the shell, how much session recency should remain visible without overcrowding the sidebar?
