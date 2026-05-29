# Local LLM lifecycle boundary

## Current repo fact

The current iPad implementation owns all Local LLM platform work inside Swift:

- manifest file location under app support
- model cache directory
- Hugging Face discovery/download
- SHA-256 verification
- Keychain bearer token
- Network.framework HTTP listener
- llama.cpp runtime adapter
- foreground server state
- in-memory chat UI transcript

This is too platform-specific to move wholesale into CTCore.

## CTCore responsibility

`CTCore` feature `local-llm-core` now owns portable Local LLM business contracts:

- `LocalLLMManifest`
- `LocalLLMModelRecord`
- model source/download/verification/activation/runtime compatibility enums
- readiness rule: downloaded + verified + non-empty local path
- model selection rule: requested model wins; otherwise active model; unavailable models are explicit errors
- service state vocabulary:
  - stopped
  - starting
  - foreground listening
  - foreground generating
  - continued background
  - interrupted
  - failed
- generation request/result structs
- minimal OpenAI Responses API request parsing
- minimal OpenAI models-list and response-object output contracts

## Platform adapter responsibility

Platform clients still own:

- filesystem locations for manifest and model cache
- file download and verification execution
- credential storage and bearer token rotation
- HTTP listener implementation
- auth enforcement
- runtime loading and generation execution
- iPadOS background task mechanics
- OS interruption detection
- UI state and local chat transcript

This keeps CTCore portable across iPadOS, Android, macOS, and Windows without pretending iPad can provide desktop daemon reliability.

## Lifecycle honesty

`continued_background` is represented as a service phase, not a guarantee.

On iPadOS, this should map to a foreground-started continuation path such as a background task when available. The system can still suspend or terminate work, so clients must transition to `interrupted` or `failed` when they lose serving ability.

Desktop clients can map their own background residency and launch-at-login behavior to the same portable state vocabulary, but those policies remain client responsibilities.

## Current limit

CTCore does not yet implement a network client/server, model downloader, file verifier, Keychain/credential store, or llama runtime. It owns only the portable schema and decision rules.
