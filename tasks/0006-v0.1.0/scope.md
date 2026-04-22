# Task 0004 — v0.1.0 scope

## Status
Active

## Date
2026-04-01

## Purpose

Define a coherent `0.1.0` scope for personal use without pretending the product must serve a generic market.

## Why this is a task

The user has clarified that:

- this is not a general-market product
- the primary customer is the repo owner
- some degree of feature accumulation is acceptable

Even so, `0.1.0` still needs a cut line.

Without a version boundary, the repo will not know:

- what must work together
- what can slip safely
- what is deliberately postponed

## Version framing

`0.1.0` does not need to be broadly marketable.

It does need to be:

- personally useful
- coherent on iPad
- capable of supporting real repeat use
- narrow enough that the first version can actually be finished

## Recommended release goal

`0.1.0` should prove that `(xiaoland's) Crafting Table` can act as a personally useful central control surface that helps the user:

1. regain orientation
2. resume a work session
3. capture new state quickly
4. act through a high-value remote-control workflow
5. preserve continuity for the next return

`0.1.0` should prove the human-operated baseline first.
Agent-operated workflows in `Goal Forest` or `Remote Control` are explicitly deferred.

## Recommended in-scope features

### 1. Sidebar + Content shell

- no standalone `Home` surface
- one iPad-first `SideBar + Content` shell
- `Goal Forest` is the first top-level tab
- `Remote Control` is a parallel top-level tab
- active or recent `work session` entry should be available from the shell without inventing a second dashboard
- quick capture starts from a small floating create button available from the main surfaces

Reason:

- without this, the product drifts either into a fake landing page or into disconnected tools

### 2. Work session basics

- create a session
- resume a recent session
- mark a session active, paused, or done
- allow a session to begin from the shell or from a `Goal Forest` context
- attach notes, captures, and relevant tools to a session
- show recent activity or continuity context inside the session

Reason:

- `work session` is already a durable product truth and needs a usable first form

### 3. Goal Forest operable basics

- a user-facing `Goal Forest` view that is actually operable
- create, edit, and connect enough structure to place sessions and captures intentionally
- show linked sessions and captures as part of node context rather than only node-to-node structure
- inspect nearby relationships without requiring a sophisticated graph engine
- allow `Goal Forest` context to shrink into minimap-like support around active work
- manual editing and navigation only
- no requirement for autonomous restructuring in `0.1.0`

Reason:

- the term is already user-facing, so `0.1.0` should give it a real, understandable, non-decorative form

### 4. Seed pool / quick capture

- append-first capture from the main surface
- no heavy classification requirement at capture time
- later linking from captures into sessions or the forest

Reason:

- this is one of the clearest stable product pressures so far

### 5. Remote control first workflow

- saved host profiles
- one-tap connection into a terminal session
- a remote connection may begin from the `Remote Control` tab or from inside a `work session`
- file upload and download in the same workflow
- if remote starts outside a session, the user can still attach or create a session in one step
- preserve enough continuity in the session to remember host, recency, transfers, and a short human note
- host profiles live at workspace scope and can be referenced from sessions
- strong enough baseline that remote control stands on its own as a high-value action surface

Reason:

- this is already one of the highest-value real action surfaces

## Recommended stretch features

These are good candidates only if the baseline above is already stable:

- anchored review comments tied to files or patches
- session-aware shortcuts that jump directly into a host or review artifact
- lightweight user-driven organization aids for captures, sessions, or forest navigation
- Pencil-specific annotation workflows

## Recommended out of scope for `0.1.0`

- autonomous `Goal Forest` restructuring
- background clustering or grafting that rewrites user structure
- graph-model sophistication becoming a visible product promise
- GUI remote desktop
- any agent-operated workflow inside `Goal Forest` or `Remote Control`
- integrated agent-output review
- Pencil-specific review workflows
- broad third-party integrations
- multi-user collaboration
- a rich generalized planner that competes with the rest of the product for focus
- agent-review automation that depends on high trust before the basics are proven

## Main scope risk

The biggest risk is not "too few features."

The biggest risk is shipping several partially formed surfaces:

- a weak shell
- a shallow session model
- a barely usable terminal
- a `Goal Forest` that is only present as branding and not as a usable structure

That would create breadth without enough repeat-use value.

## Recommended cut strategy

If something has to give, cut in this order:

1. all agent-facing features
2. advanced `Goal Forest` behavior
3. integrated review surfaces beyond what remote control already covers
4. advanced annotation intelligence

Protect these first:

1. sidebar + content shell
2. work session basics
3. quick capture
4. remote control baseline
5. operable `Goal Forest`

## Current scope decisions

- `Remote control` must meet a real baseline in `0.1.0`.
- Agent support inside `Goal Forest` and `Remote Control` is out of scope for `0.1.0`.
- `Agent-output review` is out of scope for `0.1.0`.
- `Pencil` is currently a low-confidence idea and should not shape the first release.
- `Goal Forest` must be genuinely operable in `0.1.0`.
- There is no standalone `Home` concept in the current `0.1.0` shell direction.
- The current minimum `Goal Forest` operation set is being treated as sufficient unless repeat use proves otherwise.

## Proposed minimum `Goal Forest` operation set

To count as genuinely operable in `0.1.0`, `Goal Forest` should at least support:

1. create a node
2. rename or edit a node
3. connect a node to another node
4. attach a work session or capture to a node
5. move or re-link a session or capture when the structure changes
6. inspect a node with its nearby relationships
7. archive or remove a node without breaking basic continuity

This is intentionally plain.
The current assumption is that this set is enough for `0.1.0` unless actual use reveals a missing operation.

`0.1.0` does not need:

- autonomous graph reshaping
- sophisticated layout intelligence
- hidden AI structure inference
- deep graph analytics
- a visually complex "forest simulation"

## Remaining open questions

1. Does `0.1.0` need any manual review affordance at all beyond opening the relevant files through remote control?

## References

- `docs/10-prd/behavior/scope.md`
- `docs/10-prd/behavior/claims.md`
- `docs/20-product-tdd/system-state-and-authority.md`
- `tasks/0006-v0.1.0/goal-forest-exploration.md`
- `tasks/0006-v0.1.0/remote-control-session-linkage.md`
- `tasks/0006-v0.1.0/work-session-and-goal-forest-language.md`
- `tasks/0006-v0.1.0/information-architecture.md`
- `tasks/0006-v0.1.0/user-journeys.md`
