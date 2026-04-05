# Input route: Constraint

## Trigger

Use this route when product behavior stays the same, but technical, documentation-system, dependency, tooling, or environment boundaries change.

## Primary owner

- `docs/20-product-tdd/` for cross-unit contracts, topology, and authority paths
- code, local `AGENTS.md`, or `docs/00-meta/` for smaller local or meta-level constraints

## Guardrails

- Do not rewrite product intent just to justify a technical choice.
- Do not create new documentation layers without real pressure.

## Read-do steps

1. Restate the constraint in concrete terms.
2. Identify whether the effect is cross-unit, unit-local, or purely procedural.
3. Update `docs/20-product-tdd/` before code when future drift would otherwise be expensive.
4. Keep local truth near code when the constraint does not need a cross-unit owner.
5. Escalate if the constraint actually changes a product promise.

## Exit criteria

- The constrained boundary is explicit in the correct owner.
- Verification proves the change preserves existing product commitments.
- No unnecessary new layer has been admitted.
