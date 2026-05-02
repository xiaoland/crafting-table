# Handoff Architecture

## Purpose

This note captures the architecture conclusion from the Codex Remote handoff discussion. It remains task-local until implementation proves the companion boundary and handoff modes.

## Key Conclusion

CraftingTable should treat Codex Remote as a Codex control plane:

- semantic state comes from Codex app-server, local Codex stores, and Codex CLI capabilities
- desktop UI automation contributes active-window clues for hot handoff
- pixel or GUI streaming stays as a later fallback path
- CraftingTable keeps Codex Remote runtime state self-contained for the MVP

Goal Forest, Work Session, and Remote Control integration are later product decisions.

## Handoff Modes

### Semantic Mode

The companion has a known `threadID` and can control it through the semantic Codex layer.

Minimum behavior:

- list Codex threads with useful summaries
- resume a selected thread
- start a new turn from iPad input
- stream status, output, approval, and error changes
- interrupt an active turn
- expose the active host and thread as Codex Remote runtime state

### Reconcile Pending

The user is already looking at a Codex Desktop thread. The companion reads desktop-visible clues and tries to match them to a semantic thread.

Minimum behavior:

- detect the active Codex Desktop window
- collect active thread clues such as visible title, cwd, last user prompt, visible assistant text, status, and modal state
- compare clues against app-server and local thread metadata
- report confidence and mismatch reasons to CraftingTable
- enter Semantic Mode when confidence is high enough

### Mirror Mode

The companion has low confidence about semantic thread identity.

Minimum behavior:

- surface low handoff confidence clearly
- expose conservative state such as active window title, visible status, and modal presence
- allow limited actions that can run with visible desktop state, such as focus composer or request a manual thread selection
- keep the path back to Semantic Mode visible

## Companion Boundary

```text
CraftingTable iPad Codex Remote
        |
        | CraftingTable companion protocol
        v
Host Companion on macOS or Windows
        |
        | local stdio, loopback, or local-only app-server transport
        v
Codex app-server / Codex CLI / local Codex store
        |
        +-- Desktop Scout
            macOS Accessibility or Windows UI Automation
```

## Evidence Captured

- Local Codex CLI exposes `codex resume`, `codex app-server`, remote WebSocket options, and generated schemas with thread, turn, command, filesystem, and notification methods.
- The app-server surface is the strongest semantic source for Codex threads, turns, approvals, command execution, diffs, and filesystem events.
- Raw app-server WebSocket exposure on LAN carries protocol churn and security risk.
- Public issue evidence shows active uncertainty around Desktop/app-server live sync, source kinds, and Desktop history visibility.
- UI automation is useful for the desktop's active visible state, especially active thread clues, focus, composer, modal dialogs, approval prompts, and low-confidence fallback.

## Projection Store

The companion should maintain a local projection store so CraftingTable receives stable snapshots and events.

Minimum projected fields:

- `hostID`
- `threadID`
- `title`
- `cwd`
- `source`
- `createdAt`
- `updatedAt`
- `lastUserText`
- `lastAssistantText`
- `status`
- `activeTurnID`
- `pendingApprovalCount`
- `pendingUserInputCount`
- `lastError`
- `hasDiff`
- `desktopMatchConfidence`

## Current Product Boundary

Codex Remote is independent from:

- Remote Control
- Goal Forest
- Work Session

The MVP stores the state needed to connect to the companion, select or resume a Codex thread, send input, and display event updates.

## Risk Register

- app-server protocol churn: keep it behind the companion contract and version the adapter.
- Desktop/app-server thread visibility mismatch: use reconciliation confidence and preserve manual thread selection.
- AX/UIA fragility: use it for active handoff clues and fallback state.
- LAN control security: require pairing and store secrets in the platform credential store.
- permission friction: macOS Accessibility and Windows UI Automation permissions need explicit setup and diagnostics.
- event replay complexity: companion projection should own replay and deduplication.
