# Xiaoland Workbench

Early-stage foundation repo for an iPad-first SwiftUI workbench app.

Keep changes small, reversible, and honest. Do not invent product certainty, architecture, or documentation layers before they are earned.

- Read `docs/00-meta/` for the repo-local documentation-system rules.
- Read `docs/10-prd/` only for durable product truth that has actually been promoted there.
- Use `tasks/` for active exploration, primitive hypotheses, temporary reasoning, open questions, sequencing notes for implementationm, workflow sketches and more.
- Treat code, tests, build settings, and executable checks as implementation truth.
- Read and keep current of the nearest `AGENTS.md` to where you are working at.
- Keep the PRD layer sparse until stable product truth exists.
- Keep volatile product thinking in `tasks/`, not in durable docs.
- Update docs only when a durable decision is made.
- Do not expand scope silently.
- Prefer deleting speculative docs over maintaining ritual structure.

## Development guidelines

- Prefer small, reversible steps.
- Optimize for clarity over completeness.
- Treat documentation as selective memory, not a second software system.
- Keep product exploration volatile until it proves durable.
- Avoid over-scaffolding both code and docs.

## Source layout

- `Workbench/` — SwiftUI app source
- `Workbench.xcodeproj/` — Xcode project
