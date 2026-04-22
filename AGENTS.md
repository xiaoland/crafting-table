# (xiaoland's) Crafting Table

Early-stage foundation repo for an iPad-first SwiftUI crafting table app.

Keep changes small, reversible, and honest. Do not invent product certainty, architecture, or documentation layers before they are earned.

## Repository layout

- `CraftingTable/` - SwiftUI app source
- `CraftingTable.xcodeproj/` - Xcode project
- `docs/00-meta/` - typed input routes, mode SOPs, growth rules, and framework concepts
- `docs/10-prd/` - durable product truth and business glossary
- `docs/20-product-tdd/` - cross-unit technical truth admitted for 0.1.0 development
- `tasks/` - volatile task packets, exploration, diagnostics, and artifacts

## Documentation rules

- Start here, then read the nearest local `AGENTS.md` in the subtree you touch.
- Read only the smallest governing set: matching `docs/00-meta/input-*.md`, current `docs/00-meta/mode-*.md`, relevant PRD/Product TDD/task docs, then code/tests.
- Load `docs/00-meta/concepts.md` only when boundary language is unclear.
- Treat code, tests, build settings, and executable checks as implementation truth.
- Keep the PRD layer and Product TDD layer sparse; add files only when future drift would otherwise be expensive.
- Keep volatile product thinking in `tasks/`, not in durable docs.
- Update docs only when a durable decision is made or a recurring workflow boundary needs preservation.
- Do not expand scope silently.

## Operating model

1. Classify incoming work as Intent, Constraint, Reality, or Artifact.
2. Identify the owning layer and blast radius before editing.
3. For non-trivial work, open or update a task packet with Objective & Hypothesis, Guardrails Touched, and Verification.
4. Choose the active mode for the current slice: Explore, Solidify, Execute, or Diagnose.
5. Load only the route doc, mode SOP, and governing anchors needed for that slice.
6. Execute the smallest safe change and verify it.
7. Promote only stable truths after verification.

### Typed input guide

- Intent: product behavior, scope, or policy changes. Update `docs/10-prd/` first.
- Constraint: product behavior stays the same, but technical, documentation-system, dependency, or environment boundaries change. Put cross-unit truth in `docs/20-product-tdd/` and keep local truth near code.
- Reality: observed behavior disagrees with expectation. Gather evidence first; add recurrence tripwires near code when warranted.
- Artifact: produce a bounded deliverable or one-off output. Keep it tactical unless reuse is proven.

### Mode guide

- Explore: map unknowns, alternatives, and temporary assumptions.
- Solidify: restate stable claims, ownership, and verification.
- Execute: make the smallest safe, verified change.
- Diagnose: investigate symptoms before choosing a fix.

Mode changes are normal. Mode does not change durable ownership by itself.

## Development guidelines

- Prefer small, reversible steps.
- Optimize for clarity over completeness.
- Treat documentation as selective memory, not a second software system.
- Keep product exploration volatile until it proves durable.
- Avoid over-scaffolding both code and docs.
- Pause and ask when a shortcut would damage readability, maintainability, or an explicit guardrail.
