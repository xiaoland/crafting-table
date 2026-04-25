# Minimum screen inventory

## Status
Active

## Date
2026-04-07

## Purpose

Turn the current `0.1.0` IA draft into the smallest believable set of first-version screens and overlays.

This note exists to answer one practical implementation question:

- which content states deserve screen-level treatment
- which interactions should stay as overlays or lightweight flows

## Decision summary

The current recommended `0.1.0` inventory is:

- one persistent app shell
- four first-version screen-level content states
- four lightweight overlays

This is enough to express the current scope without inventing a fake `Home`, a separate capture workspace, or a second product around remote access.

## Admitted shell

The shell is persistent rather than a screen in its own right:

- `SideBar + Content`
- top-level tabs in the sidebar
- global floating capture button

The shell should not behave like a dashboard that competes with the real working surfaces.

## Screen-level content states

### 1. `Goal Forest` screen

Primary job:

- orient the user in longer-lived structure
- inspect and edit nodes and relationships
- surface linked sessions and captures

Why it is a screen:

- it is a top-level tab
- it supports meaningful browsing and editing on its own
- it carries the broadest orientation surface

### 2. `work session` screen

Primary job:

- hold the current execution context
- preserve continuity
- gather notes, tools, remote actions, and linked artifacts

Why it is a screen:

- it is the primary execution object
- it needs sustained focus rather than modal treatment
- it can be entered from multiple places and must still feel like one stable state

### 3. `Remote Control` screen — host selection / disconnected state

Primary job:

- browse saved hosts
- inspect recent or relevant connection targets
- begin a connection
- expose session-attachment affordances before or after connect

Why it is a screen:

- it is a top-level tab
- host selection is a substantial part of the remote workflow
- it needs room for connection state, session context, and host management affordances

### 4. `Remote Control` screen — connected state

Primary job:

- run terminal-first remote work
- transfer files
- preserve visible linkage back to a session when relevant

Why it is a screen-level state:

- connected remote work is not a small modal interaction
- it needs enough space to feel like a real action surface
- it changes the dominant content state inside the `Remote Control` tab

## Overlay-level interactions

### 1. Capture sheet

Use as:

- global floating create flow
- fast append-first capture
- optional attach-to-session or link-to-`Goal Forest`

Why it is an overlay:

- capture should stay cheap
- it should not force navigation into a separate screen

### 2. Session attach / create sheet

Use as:

- attach remote work to current or recent session
- create a new session when needed

Why it is an overlay:

- this is a branching support action, not a destination in itself
- moving to a separate screen would add too much ceremony

### 3. Node create / edit sheet or inspector

Use as:

- create a node
- rename or edit a node
- adjust nearby relationships in focused context

Why it is not a separate screen:

- the user should stay anchored in surrounding `Goal Forest` context while editing
- the editing act is smaller than the navigation surface it belongs to

### 4. Host profile create / edit sheet

Use as:

- add a saved host
- edit connection details for an existing host

Why it is not a separate screen:

- host setup supports the remote workflow but is not itself a primary workspace
- a separate full screen would overstate configuration as a product surface

## What is deliberately not a screen

`0.1.0` deliberately does not need these as standalone screens:

- `Home`
- a standalone capture inbox screen
- a standalone session list screen
- a standalone review surface
- a full-screen `Goal Forest` minimap mode separate from the main `Goal Forest` tab

## Screen relationships

The intended weight is:

- shell provides navigation
- `Goal Forest` provides orientation
- `work session` provides execution
- `Remote Control` provides action on real machines
- overlays support quick branching actions without stealing the main flow

## Minimum implementation reading

If this note needs to collapse into the shortest useful statement, the minimum is:

- `0.1.0` needs four screen-level states: `Goal Forest`, `work session`, `Remote Control` disconnected, and `Remote Control` connected
- capture, session attach/create, node edit, and host edit should stay as overlays
- there is no standalone `Home` or separate capture world

## Remaining open questions

- Should node editing feel more like a side inspector or more like a centered sheet on iPad?
- Does `work session` need a lightweight session-switcher overlay, or is shell-level recency enough?
