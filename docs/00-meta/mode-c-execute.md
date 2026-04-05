# Mode C - Execute

## Role

Use when the current slice of work is clear enough to implement or edit safely.

## Guardrails

- Do not skip local AGENTS and governing docs before changing code or durable docs.
- Do not keep executing when new evidence shows the problem is still not understood.

## Read-do steps

1. Restate the exact change and verification plan.
2. Load the nearest local AGENTS plus only the governing anchors for this slice.
3. Implement the smallest safe change.
4. Run checks or other verification that matches the declared proof.
5. If unexpected behavior appears, re-enter Explore or Diagnose instead of guessing.

## Exit criteria

- The requested slice is implemented.
- Verification passes.
- No known invariant is violated.
