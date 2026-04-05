# Input route: Reality

## Trigger

Use this route for bugs, anomalies, crashes, mismatches, or any observed behavior that disagrees with expectation.

## Primary owner

- `tasks/` for evidence and hypothesis tracking
- the nearest local `AGENTS.md` for recurrence tripwires, if needed after the fix

## Guardrails

- No evidence, no modification.
- Do not jump straight from symptom to fix.

## Read-do steps

1. Capture the symptom, timeline, and blast radius.
2. Collect direct evidence: logs, failing checks, repro steps, or traces.
3. Rank hypotheses before changing code or docs.
4. Fix only after the likely cause is justified.
5. Add the smallest recurrence guard that would help the next person avoid or detect the same failure.

## Exit criteria

- The likely cause is evidence-backed.
- Verification is explicit.
- Any recurrence tripwire is placed near the relevant code or workflow.
