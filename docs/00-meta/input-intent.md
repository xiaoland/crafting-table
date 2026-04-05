# Input route: Intent

## Trigger

Use this route when the requested work changes product behavior, scope, policy, or strategy.

## Primary owner

- `docs/10-prd/`

## Guardrails

- Do not smuggle implementation structure, topology, or interface details into PRD.
- Do not invent certainty just to make the product feel more complete.

## Read-do steps

1. Restate the intended product change and success signal.
2. Read the smallest relevant PRD set: `index.md`, `glossary.md`, and any stable product truth already admitted.
3. Keep exploration and uncertainty in a task packet until the claim is durable enough to preserve.
4. Update PRD only when the new or revised product truth is explicit.
5. Push downstream technical implications into code or future technical layers only after product truth is stable.

## Exit criteria

- The product claim or scope change is explicit.
- Business vocabulary remains consistent.
- Any still-volatile reasoning remains in `tasks/`.
