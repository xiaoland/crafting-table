# Crafting Table App Guide

Read this file when working in `CraftingTable/` or making nearby app-structure changes.

- Build for an `iPad-first` SwiftUI app foundation.
- Prefer small, reversible changes that improve clarity.
- Keep unfinished surfaces honest with placeholders instead of fake completeness.
- Use UIKit only when SwiftUI is clearly insufficient.

## Scope

Current app scope is intentionally narrow:

- iPad-first
- minimal app shell
- foundation for future iteration

Do not over-optimize for iPhone, macOS, sync, backend architecture, or broad integrations unless the task clearly requires it.

## UI conventions

- Prefer native SwiftUI patterns.
- Keep the first pass simple, readable, and calm.
- Favor stable navigation structure over polished feature detail.
- Make incomplete areas explicit instead of implying that they are fully designed.
- Optimize layouts and interaction flows for iPad first.

## Architecture conventions

- Keep architecture shallow.
- Prefer feature-oriented structure when it improves discoverability.
- Avoid heavy abstraction layers without concrete pressure.
- Avoid protocol extraction purely for style.
- Add complexity only when it solves a real product or implementation problem.
- Before cross-feature structure changes, read `docs/20-product-tdd/` so state ownership and contracts stay aligned.

## State management

- Default to straightforward SwiftUI state patterns first.
- Keep ownership of state obvious.
- Name state by product meaning, not UI accidents.
- Escalate to more formal shared state only when coordination pressure becomes real.

## Naming and code quality

- Use clear, product-oriented names.
- Avoid placeholder technical names like `Manager`, `Helper`, or `Util` unless they are truly accurate.
- Prefer readability over cleverness.
- Keep files and functions easy to scan.
- Add comments only where intent or constraints are not obvious from the code.
- Do not create speculative extension points without evidence they are needed.

## Product-language note

- If a product term becomes durable enough to preserve, define it in `docs/10-prd/glossary.md` rather than inventing local glossary docs inside the app tree.
- If a cross-feature technical boundary becomes durable, record it in `docs/20-product-tdd/` instead of scattering it across comments.

## Change guidance

When changing app code:

- preserve the lightweight foundation-first approach
- avoid broad refactors unless they unlock immediate clarity
- keep code and documentation aligned
- prefer the smallest reasonable implementation move
- leave obvious room for future iteration without overbuilding
