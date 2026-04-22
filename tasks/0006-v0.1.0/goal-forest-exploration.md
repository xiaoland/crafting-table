# Task 0003 — Goal Forest exploration

## Status
Active

## Date
2026-04-01

## Purpose

Capture exploration around `Goal Forest`, a life/work central control surface, work-session-centered execution, AI review loops, terminal-based remote machine control, and lower-priority ideas such as integrated agent-output review without promoting unstable implementation assumptions into the PRD layer too early.

## Why this is a task

The current idea bundle mixes several different layers:

- product metaphor
- workflow ideas
- candidate AI behavior
- candidate storage shape
- adjacent execution surfaces

Some product choices have now been made, but several operational and interaction details are still volatile and belong here rather than in durable docs.

## Current product decisions

These decisions appear stable enough to constrain exploration, even if some of their consequences still need testing:

- the product is a central control surface for life and work rather than a developer-only crafting table
- the product must not become agent-centric
- the first-class object is the `work session`
- `Goal Forest` is intended to be user-facing terminology
- remote machine control is a primary tool surface rather than a merely adjacent utility
- remote terminal access and file transfer belong to the same first workflow
- "one-click remote connection" means connecting through preconfigured host profiles and credentials
- terminal emulation should build on a mature third-party open-source solution rather than a homegrown terminal
- agent-centric automation across `Goal Forest` and `Remote Control` remains a future possibility, but it is explicitly out of scope for `0.1.0`
- integrated agent-output review is out of scope for `0.1.0` because remote control already enables manual review
- Pencil-based annotation is currently a low-confidence idea and should not drive first-version scope

## Idea decomposition

### Signals worth preserving during exploration

- goals and work fragments should have visible relationships and lifecycle
- capture should be cheap even when structure is missing
- humans and agents should collaborate on the same shared state
- execution should focus on the subset relevant now, not on the entire corpus
- the crafting table should eventually connect planning to real action surfaces
- the product should function as one place to orient across multiple important parts of life and work
- `Goal Forest` should become a genuinely operable structure rather than a decorative label
- important tool surfaces may eventually need agent-operable actions, but `0.1.0` should stay fully human-operated
- agent work may later be reviewable in place against real files, not only via chat transcripts

### Risks and objections

- The forest metaphor is vivid, but it can overconstrain the product if treated as literal structure. Dependencies, shared resources, and cross-cutting context are not naturally tree-shaped.
- Making `Goal Forest` user-facing increases distinctiveness, but it also raises comprehension and onboarding risk if users cannot quickly map the metaphor to literal operations.
- There is a real tension between "work session is the first-class object" and "Goal Forest" as the headline concept. If that relationship is not made explicit, the product vocabulary may become poetic but operationally blurry.
- There is also a real tension between "central control surface for life and work" and product legibility. Without a hard inclusion rule, this can collapse into a busybox with weak focus and poor maintainability.
- There is a second long-term tension between "the product must not become agent-centric" and "core surfaces may later need agent-centric automation." For `0.1.0`, the cleanest mitigation is to defer agent support entirely.
- `Seed Pool`, `Mycelium Graph`, and `Spotlight Tree` are useful exploration handles, but they are still partly implementation hypotheses disguised as product language.
- Automatic AI grafting or clustering can create trust problems if the user cannot review, undo, or understand why structure changed.
- A property graph may eventually be the right substrate, but putting that into durable product docs now would smuggle architecture into the PRD too early.
- Remote machine control can easily become a second product unless it clearly strengthens the same core work loop.
- Treating remote control as core also raises interface pressure on an iPad-first app. The product has to stay legible without turning into a cramped admin console.
- If `Goal Forest` is promised as user-facing terminology, a non-operable or ornamental first version will undermine trust quickly.
- If agent-centric automation returns later across both `Goal Forest` and `Remote Control`, it raises the blast radius of mistakes. The system will then need an explicit authority model: what agents may suggest, what they may execute directly, and what always needs confirmation.
- Integrated agent-output review is useful in theory, but it should stay outside first-version scope while remote control already offers a practical fallback path.
- Pencil annotation looks attractive on paper, but currently has weak evidence of real utility and should be treated as speculative.
- The phrase "life or project management space" is broad enough to blur focus. Early product value needs a narrower, testable job.

## Working hypothesis

One believable product hypothesis worth testing is:

`(xiaoland's) Crafting Table` is a human-AI central control surface for orienting, focusing, and acting across the user's current life and work state.

That suggests a possible broad control loop:

1. Re-enter the shared control surface and regain orientation.
2. Choose or resume the most relevant work session or active area.
3. Capture or inspect the state that matters now.
4. Act through the right tool surface, which may include planning, remote control, or review.
5. Preserve continuity so the next return has lower restart cost.

## Open questions

- What review loop would be required before AI restructuring becomes trustworthy in a post-`0.1.0` version?
- How should the product explain the relationship between a `work session` and the broader `Goal Forest` so the metaphor does not obscure the real object model?
- What is the smallest stable meaning of "central control surface" that keeps the product legible instead of sprawling?
- What is the minimum session-aware remote workflow that feels complete on iPad?
- What minimum operations make `Goal Forest` feel truly operable in `0.1.0`?
- If agent support returns after `0.1.0`, which surface should earn it first and under what authority boundary?
- Where should saved host profiles live relative to sessions, contexts, or the broader workspace?
- What is the review unit for Coding Agent output: whole task, commit, patch, file, symbol, or line range?

## AI review loop options

These are future-facing interaction models for user review before AI-made restructuring is applied.
They no longer belong to the active `0.1.0` baseline.

### Option A — Review queue

AI suggestions land in a dedicated review queue with:

- short rationale
- affected nodes or sessions
- accept / edit / reject actions

Trade-off:

- simplest and safest mental model
- easiest to implement incrementally
- weakest locality because review happens away from the working surface

### Option B — Inline patch review

AI suggestions appear directly inside the current work-session or `Goal Forest` view as proposed edits.

Trade-off:

- strongest locality and best explainability
- makes the product feel collaborative rather than batch-oriented
- noticeably harder UI and state-management problem

### Option C — Shadow forest

AI restructures a temporary shadow copy. The user compares current vs proposed state, then merges selectively.

Trade-off:

- best safety for larger structural changes
- handles multi-node clustering or grafting well
- highest cognitive and implementation cost

### Option D — Tiered trust model

Different classes of AI action use different review gates:

- append-only capture or tagging can auto-apply with undo
- structural moves, merges, or grafts require explicit review
- destructive edits always require confirmation

Trade-off:

- best balance between speed and trust
- matches how users naturally tolerate different levels of risk
- requires a clean action taxonomy and undo model

Current assessment:

- `Option D` is the strongest default candidate
- `Option B` is the best long-term feel if the UI can support it
- `Option A` is the easiest first prototype if we need to learn quickly

## Agent-output review options

This area is now lower priority than the remote-control baseline and may land after `0.1.0`.

These are candidate interaction models for reviewing Coding Agent output on top of the file system.

### Option E — Structured code review

The system shows diffs or changed files and lets the user leave typed comments anchored to file paths and line ranges.

Trade-off:

- strongest mechanical clarity
- easiest to feed back into another agent step
- least differentiated for an iPad-first product

### Option F — Ink over diff

The system shows a rendered diff or file view and allows Apple Pencil markup directly on top of it.

Trade-off:

- highly natural on iPad
- strong feeling of direct inspection
- weak if ink cannot also resolve to stable anchors and structured feedback

### Option G — Dual-layer review

The user can annotate with Pencil, but the system also stores a structured review object:

- file or patch anchor
- optional line range
- ink payload
- extracted textual intent
- review status

Trade-off:

- best balance between expressive annotation and machine actionability
- creates a richer long-term review history
- materially more complex data model and interaction design

### Option H — Review cards from agent changes

The system groups agent output into review cards such as:

- risky file changes
- unresolved TODOs
- test-impacting edits
- user-requested checkpoints

The user reviews cards instead of raw file trees first, then drills into files when needed.

Trade-off:

- lowers review load
- stronger session-level orchestration
- risks hiding important raw detail behind AI summarization

Current assessment:

- integrated review no longer needs to anchor `0.1.0`
- if this area returns later, `Option E` is the safest re-entry point
- `Option F` should stay deprioritized unless a stronger Pencil use case emerges
- `Option G` is only worth its complexity if review becomes a high-frequency native workflow

## Candidate durable truths

These feel strong enough to consider for promotion:

- the product should reduce classification tax by separating capture from later structure
- humans and agents should share the same working canvas
- the product should behave as a shared control surface for life and work rather than as a developer-only workstation
- the product should not be agent-centric even when agent-related tools are important
- the product should center execution through work sessions rather than isolated notes or flat task lists
- the product should present a current execution slice instead of forcing constant full-system navigation
- remote machine control is a core tool surface for the target user
- the first remote shape should be terminal-first rather than GUI-first
- remote terminal access and file transfer form one primary workflow
- `Goal Forest` should be operationally real in the first version rather than merely decorative
- if agent-operable actions return later, they should remain subordinate to human-centered workflows rather than redefining the product

## Candidate inclusion rule for tool surfaces

A tool surface should earn admission only if it materially helps with at least one of these:

- orientation
- execution
- review
- continuity

This rule is not yet promoted, but it may be necessary to keep "central control surface" from degrading into a loose utility bundle.

## Next steps

1. Decide whether the candidate inclusion rule above is strong enough to prevent busybox sprawl.
2. Keep the current minimum `Goal Forest` operation set under review through actual use rather than reopening it speculatively.
3. Decide whether `0.1.0` needs any manual review affordance beyond remote file access.
4. Keep the task 0006 clarifications under review and promote only the parts that remain stable.
5. If agent support returns after `0.1.0`, decide which surface should earn it first and under what boundary.
