# UI Information Architecture draft

## Status
Active

## Date
2026-04-05

## Intent

Define the minimum believable interaction structure for `0.1.0` without inventing a fake landing page, a busy multi-tool dashboard, or a second product around remote access.

## Admitted shell

`0.1.0` uses one app shell:

- `SideBar + Content`
- no separate `Home`
- no requirement that every important thing become a top-level tab

This matters because the product already has two distinct pressures:

- it must preserve orientation
- it must still privilege active execution

A fake `Home` screen would mostly repeat shortcuts that can live in the shell more honestly.

## Top-level tabs

The current admitted top-level tabs are:

1. `Goal Forest`
2. `Remote Control`

This is intentionally small.

### Why `Goal Forest` is first

- it is the broadest orientation surface
- it anchors the product's distinctive shared-workspace identity
- it gives context for sessions and captures instead of behaving like a separate utility

### Why `Remote Control` is parallel rather than buried

- remote work is already a core tool surface
- hiding it too deeply would contradict the real value it carries for the target user
- making it parallel does not mean it outranks `work session` as the primary execution object

## Object hierarchy inside the shell

The current recommended hierarchy is:

1. shell level — which primary surface is active
2. `work session` level — what the user is doing now
3. context level — where the work belongs in `Goal Forest`
4. capture level — what has been collected but not yet fully placed

This means:

- tabs decide the current surface
- `work session` decides the current execution focus
- `Goal Forest` provides context and navigation structure
- capture remains global and lightweight

## Content priority rules

### Rule 1 — Active `work session` outranks passive browsing

When a session is active, the main content should privilege that session over broad browsing context.

This does not remove `Goal Forest`.
It means `Goal Forest` should often shrink into supporting context, such as a minimap, linked-node panel, or nearby-structure summary.

### Rule 2 — `Goal Forest` exists in two scales

`Goal Forest` should appear in two valid forms:

- full-surface browsing and editing in its own tab
- compact context around active work in a minimap-like form

This lets the product preserve one shared structure without forcing the user to live in the full forest view all the time.

### Rule 3 — Capture stays global

Capture should not require entering its own world first.

The minimum form is:

- a small floating create button
- available from the main surfaces
- opens a lightweight creation sheet
- allows deferred classification

### Rule 4 — `Remote Control` remains session-aware

`Remote Control` is a top-level tab, but it should still expose session linkage clearly:

- current linked session, if any
- one-step attach to current or recent session
- one-step create-and-attach flow when needed

This is the main guard against remote control becoming a standalone SSH client with incidental notes.

## Surface definitions

## 1. `Goal Forest` tab

Primary job:

- orient the user in longer-lived structure
- create, edit, connect, and inspect nodes
- surface related sessions and captures

Minimum content emphasis:

- node structure first
- linked sessions and captures second
- current active session visible when relevant

This tab is where the user understands placement.
It is not where every action must stay.

## 2. `work session` content state

Primary job:

- hold the current execution context
- preserve continuity
- link out to tools, notes, captures, and remote actions

Minimum content emphasis:

- current objective or working state
- recent activity and continuity notes
- linked tools and artifacts
- compact `Goal Forest` context rather than full browsing by default

`work session` is not a top-level world competing with every other tab.
It is the dominant execution state that can be entered from several places in the shell.

## 3. `Remote Control` tab

Primary job:

- connect to saved hosts
- run terminal-first remote work
- transfer files in the same workflow
- preserve enough session linkage to stay inside the broader workbench loop

Minimum content emphasis:

- host list or selected host state
- connection state
- session attachment state
- file transfer actions

## 4. Capture overlay

Primary job:

- collect something quickly without demanding placement first

Minimum content emphasis:

- input first
- optional attach-to-session
- optional link-to-`Goal Forest`
- easy save without heavy classification

Capture should behave like a lightweight overlay or sheet, not a rival workspace.

## Entry and transition model

The current recommended transitions are:

- `Goal Forest` tab -> open or resume a `work session`
- active `work session` -> open `Remote Control` already linked to that session
- `Remote Control` tab -> connect first, then attach or create session if needed
- any main surface -> floating capture button -> save now, classify later

This keeps transitions short and legible.

## Information density stance

The shell should avoid two equal and competing dashboards.

The current density rule is:

- sidebar stays navigational first
- main content carries most working detail
- minimap context should summarize, not clone the full forest
- capture entry should stay visually small until invoked

In practice, this means:

- do not stuff the sidebar with every recent item and status object
- do not make `Goal Forest` full-screen all the time just because it is the first tab
- do not make capture feel heavyweight or modal before the user has typed anything

## What this IA deliberately does not decide yet

This draft does not yet lock:

- the exact sidebar substructure for current or recent sessions
- the exact visual form of the `Goal Forest` minimap
- the exact split between inspector panes and overlays
- whether manual review gets any first-version affordance beyond remote access

## Recommended minimum summary

If this needs to collapse into a short statement, the minimum is:

- `0.1.0` has no `Home`; it uses a `SideBar + Content` shell
- `Goal Forest` and `Remote Control` are the admitted top-level tabs
- `work session` is the dominant execution state in content
- `Goal Forest` can shrink into minimap context around active work
- capture starts from a small global floating create button
