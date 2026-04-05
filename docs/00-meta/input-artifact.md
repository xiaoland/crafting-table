# Input route: Artifact

## Trigger

Use this route when the request is to produce a bounded deliverable such as a one-off analysis, helper script, migration output, or temporary structured artifact.

## Primary owner

- `tasks/` or the local work surface

## Guardrails

- Do not promote one-off tactics into durable architecture by default.
- Do not leave completion criteria implicit.

## Read-do steps

1. Define the artifact output shape and completion proof.
2. Build the smallest artifact that satisfies the request.
3. Keep temporary assumptions local to the task packet.
4. Promote only if repeated reuse proves the artifact encodes durable knowledge.

## Exit criteria

- The requested artifact exists and matches the expected output.
- Verification is complete.
- Any promotion candidate is explicit rather than silently assumed.
