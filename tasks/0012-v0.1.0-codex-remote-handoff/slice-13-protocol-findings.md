# Slice 13 Protocol Findings

## Date

2026-05-04

## Purpose

Record the app-server facts used by Slice 13 before exposing composer reasoning controls in CraftingTable.

## Evidence

The installed Codex Desktop app-server was probed through a loopback WebSocket with the normal `initialize`, `initialized`, and `model/list` flow.

Observed `model/list` fields:

- `id`
- `model`
- `displayName`
- `description`
- `isDefault`
- `defaultReasoningEffort`
- `supportedReasoningEfforts`
- `additionalSpeedTiers`

The visible model list contained six models. `gpt-5.5` and `gpt-5.4` advertised `additionalSpeedTiers` containing `priority` and `fast`. Reasoning efforts were advertised as structured values with `reasoningEffort` and `description`; the common supported set was `low`, `medium`, `high`, and `xhigh`.

The app-server embedded schema strings identify `TurnStartParams` fields named `model`, `effort`, and `serviceTier`. The schema description for `effort` says it overrides reasoning effort for the turn and subsequent turns. The schema description for `serviceTier` says it overrides service tier for the turn and subsequent turns.

A direct marker turn against the already-busy Codex Remote smoke thread was inconclusive because that thread was still running a long active turn. The Slice 13 parameter names are based on the embedded app-server schema plus `model/list` metadata.

## Companion Contract

CraftingTable continues to speak a CraftingTable-owned HTTP contract:

- `GET /models` returns model summaries plus `default_reasoning_effort`, `supported_reasoning_efforts`, and `additional_speed_tiers`.
- `POST /threads/{thread_id}/turns` accepts optional `model`, `reasoning_effort`, and `service_tier`.
- Companion maps `reasoning_effort` to app-server `effort`.
- Companion maps `service_tier` to app-server `serviceTier`.

This keeps app-server field naming and future protocol churn inside Companion.

## Slice 13 Scope

Implement only the MVP controls and rendering needed for practical remote use:

- model picker remains a menu
- reasoning effort uses a compact menu
- Fast appears only for selected models that advertise `fast`
- transcript rendering gains assistant Markdown text and clearer event/tool labels
