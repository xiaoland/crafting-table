# Product claims

## Claim 1 - One shared surface supports orientation and action

- claim intent: help the user regain orientation, choose focus, and act from one coherent workbench.
- evaluation dimensions: continuity, focus selection, surface coherence.
- evidence expectation: the main `0.1.0` journeys can start, resume, capture, and act without turning into disconnected products.
- source rationale: `_drivers/market-and-user-pressures.md`, `_drivers/business-and-service-objectives.md`
- realization pointers: `../../20-product-tdd/unit-topology.md`, `../../20-product-tdd/claim-realization-matrix.md`
- impact on existing claims: this is the umbrella claim for the release.

## Claim 2 - `work session` is the primary execution object

- claim intent: keep the product action-oriented instead of making orientation surfaces the main unit of doing.
- evaluation dimensions: session priority, continuity, clear execution ownership.
- evidence expectation: active or recent work can resume through session state without requiring a fake dashboard or full-forest browsing.
- source rationale: `_drivers/market-and-user-pressures.md`, `_drivers/operational-realities.md`
- realization pointers: `../../20-product-tdd/system-state-and-authority.md`
- impact on existing claims: constrains shell and Goal Forest design.

## Claim 3 - `Goal Forest` is operable orientation, not decorative branding

- claim intent: make the headline surface useful for placement and navigation rather than symbolic.
- evaluation dimensions: operability, context value, language clarity.
- evidence expectation: the user can create, inspect, connect, and use Goal Forest context around active work.
- source rationale: `_drivers/market-and-user-pressures.md`, `_drivers/operational-realities.md`
- realization pointers: `../../20-product-tdd/unit-topology.md`, `../../20-product-tdd/cross-unit-contracts.md`
- impact on existing claims: requires literal action language and real node/session/capture relationships.

## Claim 4 - Capture stays cheap and defers classification

- claim intent: reduce classification tax so important state can be saved before the right placement is known.
- evaluation dimensions: speed, low friction, later attachability.
- evidence expectation: capture can be saved globally without forcing full Goal Forest or session placement first.
- source rationale: `_drivers/market-and-user-pressures.md`
- realization pointers: `../../20-product-tdd/system-state-and-authority.md`, `../../20-product-tdd/cross-unit-contracts.md`
- impact on existing claims: constrains capture UI and data ownership.

## Claim 5 - `Remote Control` is a core, session-aware action surface

- claim intent: keep remote work inside the workbench loop without forcing too much ceremony upfront.
- evaluation dimensions: usefulness, session linkage, continuity.
- evidence expectation: the user can start remote work from a session or directly from Remote Control and still preserve session linkage and continuity.
- source rationale: `_drivers/market-and-user-pressures.md`, `_drivers/hard-constraints.md`, `_drivers/operational-realities.md`
- realization pointers: `../../20-product-tdd/system-state-and-authority.md`, `../../20-product-tdd/cross-unit-contracts.md`, `../../20-product-tdd/claim-realization-matrix.md`
- impact on existing claims: keeps remote control from becoming a disconnected utility.
