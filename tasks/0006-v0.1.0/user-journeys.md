# User journey draft

## Status
Active

## Date
2026-04-05

## Purpose

Describe believable `0.1.0` journeys that fit the current scope and the current shell direction.

These journeys are not exhaustive.
They are the minimum set needed to test whether the app feels like one crafting table rather than disconnected tools.

## Journey 1 — Re-enter work through `Goal Forest`

Goal:

- regain orientation
- find the relevant context
- resume execution quickly

Steps:

1. The user opens the app into the `Goal Forest` tab.
2. The user sees the relevant node or nearby structure first, rather than a generic dashboard.
3. The user notices linked sessions and chooses one to resume, or starts a new session from that context.
4. The content shifts into the `work session` as the dominant state.
5. `Goal Forest` remains visible only as compact supporting context.
6. The user continues work, adds notes, or opens tools from the session.

Why this matters:

- it proves that `Goal Forest` is real and operable
- it also proves that `Goal Forest` does not overshadow the actual execution object

## Journey 2 — Continue active work with session priority

Goal:

- return to doing without re-browsing the full structure

Steps:

1. The user already has an active or recent `work session`.
2. From the shell, the user resumes that session directly.
3. The session content takes priority over full-forest browsing.
4. The user sees continuity notes, recent activity, and linked tools first.
5. A compact `Goal Forest` minimap or related-context panel keeps orientation available without stealing focus.

Why this matters:

- it confirms that `work session` is the first-class execution object
- it prevents the product from becoming all structure and no action

## Journey 3 — Quick capture without classification tax

Goal:

- save something immediately
- avoid losing momentum

Steps:

1. The user is anywhere in the app.
2. The user taps the small floating create button.
3. A lightweight capture sheet appears.
4. The user records the capture first.
5. The user may optionally link it to the current session or a `Goal Forest` node.
6. If the right placement is unclear, the user saves anyway and moves on.

Why this matters:

- cheap capture is one of the clearest stable product pressures
- making capture global prevents the user from having to switch into a special intake world

## Journey 4 — Session-linked remote execution

Goal:

- act on a real machine
- keep that action inside the crafting table loop

Steps:

1. The user is inside a `work session`.
2. The user opens `Remote Control`.
3. The remote view already knows the current session context or offers one-tap attachment.
4. The user connects to a saved host and performs terminal or file-transfer work.
5. The user leaves a short human note or outcome tied to the session.
6. The user returns to the session with remote continuity preserved.

Why this matters:

- it proves that remote control is part of the crafting table rather than an isolated utility
- it provides a concrete action loop for `0.1.0`

## Journey 5 — Remote first, session second

Goal:

- allow quick real-world action without forcing too much ceremony upfront

Steps:

1. The user enters the `Remote Control` tab directly.
2. The user connects to a host before deciding what session should own the work.
3. The remote surface keeps the connection visibly unattached rather than silently orphaned.
4. The user later attaches the activity to a current session, a recent session, or a newly created one.
5. The crafting table preserves host, recency, transfers, and a short note as the continuity bundle.

Why this matters:

- it keeps remote work low-friction
- it avoids forcing premature session classification
- it still protects the app from becoming a disconnected SSH client

## Journey set coverage

Together, these journeys test whether `0.1.0` can support:

- orientation
- execution
- capture
- remote action
- continuity

That is enough to pressure-test the current scope without inventing late-stage UX detail too early.
