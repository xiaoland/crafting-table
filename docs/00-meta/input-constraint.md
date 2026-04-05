# Input route: Constraint

## Trigger

Use this route when product behavior stays the same, but technical, documentation-system, dependency, tooling, or environment boundaries change.

## Primary owner

- the smallest durable technical or meta layer that prevents future drift

In this repository, many such constraints still belong in code, tests, local `AGENTS.md`, or `docs/00-meta/` because `docs/20-product-tdd/` and `docs/30-unit-tdd/` are not admitted yet.

## Guardrails

- Do not rewrite product intent just to justify a technical choice.
- Do not create new documentation layers without real pressure.

## Read-do steps

1. Restate the constraint in concrete terms.
2. Identify the smallest durable owner that should remember it.
3. Update code, tests, local AGENTS, or meta docs where future drift would be expensive.
4. Keep procedural exploration in a task packet until the stable boundary is clear.
5. Escalate if the constraint actually changes a product promise.

## Exit criteria

- The constrained boundary is explicit in the correct owner.
- Verification proves the change preserves existing product commitments.
- No unnecessary new layer has been admitted.
