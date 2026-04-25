# Low-fidelity layout packet

## Status
Active

## Date
2026-04-25

## MVT Core

- Objective & Hypothesis: turn the current `0.1.0` IA, screen inventory, and transition map into a first SwiftUI shell skeleton; the expected result is a navigable low-fidelity app surface that proves the main structure without pretending the deeper persistence or remote-control slices are complete.
- Guardrails Touched: preserve `SideBar + Content`; keep `Goal Forest` and `Remote Control` as the admitted top-level tabs; keep `work session` as the execution state; keep capture global and cheap; keep Remote Control session-aware.
- Verification: the app can navigate among Goal Forest, work session, Remote Control disconnected, Remote Control connected, and open/dismiss capture plus session attach, node edit, and host edit overlays.

## Classification

- Input Type: Intent
- Active Mode: Solidify -> Execute
- Governing Anchors: `AGENTS.md`, `CraftingTable/AGENTS.md`, `docs/00-meta/input-intent.md`, `docs/00-meta/mode-b-solidify.md`, `docs/00-meta/mode-c-execute.md`, `docs/10-prd/behavior/scope.md`, `docs/10-prd/behavior/workflows.md`, `docs/20-product-tdd/system-state-and-authority.md`, `tasks/0006-v0.1.0/information-architecture.md`, `tasks/0006-v0.1.0/minimum-screen-inventory.md`, `tasks/0006-v0.1.0/transition-map.md`

## Accepted Layout Decisions

### A2 - Shell recency affordance

The sidebar shows:

- the two admitted top-level tabs: `Goal Forest` and `Remote Control`
- one active session affordance
- two recent session affordances

This is the first `0.1.0` balance between quick resume and sidebar restraint.
The shell remains navigational first.

### B2 - Goal Forest nearby context panel

The `work session` screen shows a compact nearby-context panel rather than a full graph view.

Minimum content:

- primary linked Goal Forest node
- nearby node labels
- linked capture and session counts
- a return path to the full Goal Forest surface

This lets Goal Forest remain present around active work without forcing full browsing during execution.

### C1 - Remote Control session linkage header

The Remote Control header always exposes session linkage.

Minimum states:

- linked state: show a session chip
- unlinked state: show an attach action

This keeps direct remote entry cheap while making unattached remote activity visible and recoverable.

## First Screen Layouts

### Persistent shell

- Left sidebar: product title, top-level tabs, current work section, recent work section.
- Main content: the selected screen-level state.
- Floating create button: opens capture sheet from any main surface.

### Goal Forest screen

- Header: `Goal Forest`, selected node summary, create/edit node action.
- Main area: low-fidelity node map using simple grouped cards.
- Side context: linked sessions and captures for the selected node.
- Primary transition: open linked or new work session.

### Work session screen

- Header: session title, lifecycle state, compact actions.
- Main area: objective, continuity notes, recent activity, linked tools.
- Nearby context panel: B2 Goal Forest context.
- Primary transition: open Remote Control linked to the session.

### Remote Control disconnected state

- Header: Remote Control title, C1 session linkage state.
- Main area: saved host list and recent host cards.
- Support actions: host profile edit sheet, session attach/create sheet.
- Primary transition: connect to selected host.

### Remote Control connected state

- Header: host connection state, C1 session linkage state, return-to-session affordance when linked.
- Main area: terminal placeholder that is explicit about future real terminal work.
- Side/support area: file transfer placeholder and continuity note.
- Primary transition: return to linked work session or attach the activity.

## Overlays

- Capture sheet: opens from any main surface and supports optional session/node placement.
- Session attach/create sheet: opens from Remote Control states and returns to the invoking remote state.
- Node create/edit sheet: opens from Goal Forest and preserves the selected local context.
- Host profile create/edit sheet: opens from Remote Control disconnected state.

## Implementation Cut

This slice should implement:

- local SwiftUI navigation state only
- static seed data for sessions, nodes, captures, and hosts
- low-fidelity connected/disconnected toggles for Remote Control
- honest placeholders for persistence, real terminal connection, and file transfer

This slice should leave to later tasks:

- persistence and data strategy: `tasks/0010-v0.1.0-persistence-data-strategy/`
- real remote-control depth: `tasks/0011-v0.1.0-remote-control-depth-terminal/`

## Verification Checklist

- App launches into `Goal Forest`.
- Sidebar contains `Goal Forest`, `Remote Control`, one active session, and two recent sessions.
- Selecting a session opens the `work session` screen.
- `work session` shows nearby Goal Forest context.
- `work session` can open Remote Control with linked session state.
- Remote Control can show disconnected and connected states.
- Unlinked Remote Control shows attach action.
- Capture, session attach/create, node edit, and host edit overlays open and dismiss.

## Verification Evidence

- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` succeeded.
- The app installed and launched on `iPad Pro 13-inch (M4)` simulator.
- Screenshot artifact: `tasks/0006-v0.1.0/artifacts/low-fidelity-shell-ipad-sidebar.png`.
- Major routes and overlays now have accessibility identifiers so a later UI test target can automate click-through verification.

## Residual Verification Gap

The repository currently has no test target.
Computer Use desktop permissions were unavailable during this slice.

Because of that, this pass verifies build, launch, initial shell presentation, and compiled route/overlay wiring, but does not include automated click-through UI tests.
