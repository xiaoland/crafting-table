# Codex Remote Rich Message Rendering

## Objective & Hypothesis

Explore how the iPad Codex Remote client should render richer message content: fenced code blocks, syntax highlighting, and Mermaid diagrams.

Working hypothesis: message text should be segmented into content blocks so ordinary prose, code blocks, and Mermaid diagrams can use different renderers without forcing one monolithic Markdown renderer to own every capability.

## Input Type

Intent.

The requested behavior changes how Codex Remote messages are experienced in the iPad client, but the exact product and technical boundary is still under discussion.

## Active Mode

Explore.

Key unknowns:

- Whether to use a Markdown renderer that supports custom block rendering instead of a hand-rolled block parser.
- Where the SwiftUI-native boundary should stop and where a `WKWebView`-backed Mermaid renderer should begin.
- How streaming messages should transition from incomplete markdown text to stable block rendering.
- Whether user messages should remain plain text or adopt the same block renderer as assistant messages.

## Guardrails Touched

- `AGENTS.md`
- `clients/apple/AGENTS.md`
- `clients/apple/iPad/AGENTS.md`
- `docs/00-meta/input-intent.md`
- `docs/00-meta/mode-a-explore.md`
- `tasks/README.md`

## Current Rendering Snapshot

Current code path:

- `CodexRemoteThreadPage` owns transcript rendering.
- `CodexRemoteMessageRow` renders conversation messages.
- `role == "user"` renders with plain SwiftUI `Text`.
- `role == "assistant"` renders through `CodexRemoteMarkdownText`.
- Streaming assistant fallback also renders through `CodexRemoteMarkdownText`.
- `CodexRemoteMarkdownText` uses `AttributedString(markdown:options:)` with `.inlineOnlyPreservingWhitespace`.
- Non-conversation event messages render in a `DisclosureGroup`; command execution uses a monospaced font but no syntax highlighting.

Initial implication: block-level markdown is intentionally not rendered today. Fenced code blocks and Mermaid blocks will not become distinct visual blocks until the renderer boundary changes.

## Temporary Assumptions

- Rich rendering should first target assistant messages and streaming assistant fallback.
- User messages can be considered separately because today they are plain text bubbles.
- Mermaid rendering should not be reimplemented natively in SwiftUI unless a narrower product requirement appears.
- Any JavaScript renderer should be bundled locally and treated as an isolated diagram renderer, not as a full-message web renderer.

## Candidate Direction

Prefer a renderer pipeline shaped like:

1. Parse markdown into block-level content.
2. Render paragraph/list/quote/inline emphasis with native SwiftUI text where feasible.
3. Render fenced code blocks with a dedicated SwiftUI code block view plus syntax highlighting.
4. Render fenced `mermaid` blocks with a dedicated Mermaid view, likely backed by local `WKWebView` and bundled Mermaid JavaScript.
5. Fall back to code block rendering when block parsing or diagram rendering fails.

Open design question: use a maintained Markdown parser/renderer with custom block hooks if it fits SwiftUI and streaming constraints; avoid a bespoke parser unless the supported grammar is intentionally tiny and well-tested.

## Implementation Slice

Implemented first pass:

- Added `CodexRemoteRichMessageText` to split message text with `swift-markdown`.
- Added SwiftUI code block rendering with a copy action and lightweight built-in syntax highlighting for Swift, JSON, shell, and common literals/comments.
- Added `CodexRemoteMermaidBlockView` backed by `WKWebView`.
- Bundled `mermaid.min.js` from Mermaid `11.15.0` as an app resource.
- Kept Mermaid styling fixed to a simple black-on-white theme; no custom diagram styling is exposed.
- Mermaid render failures fall back to the code block renderer.
- Incomplete trailing fences are treated as code while streaming instead of eagerly rendering Mermaid.
- Replaced assistant, streaming assistant, and user conversation message bodies with the rich renderer.
- Added explicit ordered and unordered list blocks so list markers are rendered by SwiftUI instead of leaking literal markdown syntax.

Current deliberate constraints:

- Prose rendering still uses SwiftUI `AttributedString(markdown:)` with inline-preserving behavior.
- Syntax highlighting is intentionally modest and local; it is not a full grammar engine.
- List rendering currently targets flat list readability. Nested list content is preserved in the item body but is not yet recursively rendered as nested SwiftUI list blocks.
- Mermaid JavaScript is local, but the current visual verification is limited to successful iPad target build.

## Verification

For exploration:

- Confirm current rendering code path from the iPad client source.
- Compare feasible Swift Markdown/rendering libraries before implementation.
- Define MVP acceptance examples for inline markdown, fenced code, unclosed streaming fences, Mermaid success, and Mermaid failure fallback.

For a later implementation slice:

- Build the iPad app.
- Add focused parser/rendering tests if the chosen boundary includes custom segmentation.
- Verify transcript rendering with static and streaming sample messages.

Verified:

- `xcodebuild -resolvePackageDependencies -project clients/apple/CraftingTable.xcodeproj -scheme CraftingTable`
- `xcodebuild -project clients/apple/CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' build`

## Promotion Candidates

- If block-level rich message rendering becomes product scope for `0.1.0`, promote the behavior claim to PRD.
- If a reusable message content block contract emerges, preserve it in Product TDD or code tests rather than expanding durable docs prematurely.
