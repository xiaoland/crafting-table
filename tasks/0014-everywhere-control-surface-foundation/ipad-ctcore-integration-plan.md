# iPad Client CTCore integration plan

## Intent

The next architecture slice is to let the iPad client call CTCore-backed domain APIs directly.

This does not mean restoring a workspace aggregate. The post-Phase-6 client shape is already split into domain stores:

- `GoalForestStore`
- `SessionStore`
- `CaptureStore`
- `HostConfigStore`
- `RemoteContinuityStore`

Those stores should become client adapters over CTCore and platform services, one domain at a time.

## Current status

The first `HostConfigStore` slice is implemented.

- CTCore exposes a `swift-bindings` feature through UniFFI.
- `HostConfigStore` calls CTCore for portable config decode, encode, and validation.
- Xcode builds and links `CTCore.xcframework` through `scripts/build-ctcore-apple.sh`.
- Generated Swift binding source is checked in under `clients/apple/iPad/Generated/CTCore/`.
- Static libraries are generated locally and ignored by git.
- `scripts/smoke-ctcore-swift-binding.sh` verifies the generated Swift binding can call CTCore validation and JSON round-trip functions.

## Key technical decisions

### Binding mechanism

Recommended direction: use UniFFI for Swift bindings.

Rationale:

- CTCore is Rust and already feature-gated.
- Android will likely need Kotlin bindings later.
- UniFFI keeps Swift/Kotlin binding shape closer than a hand-written C ABI.
- The expected first surfaces are structured models and validation/mapping functions, which fit UniFFI better than callback-heavy runtime surfaces.

Rejected as the first path:

- Hand-written C ABI: lower dependency count, but expensive and error-prone for structured models, diagnostics, and future Android reuse.
- JSON-only shell command bridge: useful for smoke tests, not acceptable as an embedded iPad client boundary.

Open implementation detail:

- Whether generated Swift files are checked in from the start. Recommended for the first slice: check them in to keep Xcode builds deterministic while the build pipeline is still young.

### Build artifact

Recommended direction: CTCore should produce an iOS device + iOS simulator XCFramework.

Current implementation note: the iPad target links `CTCore.xcframework`. The Rust build still produces per-SDK static libraries as intermediate inputs, then packages them into the XCFramework.

The initial build target should include only the features needed by the iPad slice. Do not ship all CTCore features into the app by default.

Expected first feature set:

- `portable-config`

Later feature sets:

- `inkcre-graph`
- `local-llm-core`
- Codex Remote Control client-side contracts if the iPad UI needs them directly

Implementation detail:

- The XCFramework is built by `scripts/build-ctcore-apple.sh` and linked by the Xcode target.
- The script phase intentionally runs every build. Declaring the XCFramework as both a script output and same-target framework input creates an Xcode dependency cycle.

### First domain slice

Recommended first slice: `HostConfigStore` backed by CTCore `portable-config`.

Rationale:

- It is the smallest useful proof of CTCore inside iPad.
- It does not require InKCre server availability.
- It exercises Rust -> Swift model/diagnostic binding.
- It can replace local host validation and JSON shape without touching Goal Forest canvas logic.

Do not start with:

- Goal Forest / Capture, because they require an InKCre transport adapter and resolver assumptions.
- Local LLM, because it mixes manifest contracts with iPad lifecycle, filesystem, Keychain, Network.framework, and runtime loading.
- Codex Remote runtime, because server/client authority split and streaming events create a larger integration surface.

### Authority boundary

CTCore owns:

- portable config schema
- validation rules and diagnostics
- InKCre graph mapping semantics
- Local LLM portable manifest/request/response contracts
- Codex Remote Control portable contract vocabulary

iPad client owns:

- SwiftUI state and navigation
- file locations and app container paths
- Keychain
- Network.framework
- local background/foreground lifecycle
- InKCre base URL, auth token, retries, and offline behavior
- conversion between ObservableObject stores and CTCore calls

Never reintroduce:

- `WorkspaceDocument`
- a single `WorkspaceStore.document`
- an aggregate CTCore workspace API that hides the actual domain authority

## Store replacement sequence

1. `HostConfigStore`
   - Back with CTCore `portable-config`.
   - Keep file location in Swift.
   - Use CTCore for parse, encode, validate, and diagnostics.

2. `GoalForestStore`
   - Back with CTCore `inkcre-graph` mapping.
   - Add an iPad InKCre transport adapter.
   - Keep canvas selection and layout in Swift.

3. `CaptureStore`
   - Back with CTCore capture intake mapping.
   - Keep capture sheet UI in Swift.
   - Let CTCore choose CT capture block vs native InKCre text shape when the rule is ready.

4. `SessionStore`
   - Back with CTCore work session graph mapping.
   - Keep active-session UI policy visible in Swift until the durable active-status authority is proven.

5. `RemoteContinuityStore`
   - Split durable session/remote memory into InKCre where useful.
   - Keep live connection/runtime recency in client/runtime state when it is not durable memory.

## First implementation checklist

For the first `HostConfigStore` slice:

- add UniFFI dependency and minimal `.udl` or proc-macro binding setup
- expose CTCore portable config decode/encode/validate surface to Swift
- build iOS simulator/device static libraries and package them into `CTCore.xcframework`
- add generated Swift binding files or a deterministic generation step
- link the iPad target against `CTCore.xcframework`
- change `HostConfigStore` to call CTCore for config parsing and validation
- keep Swift responsible for choosing the app-support file URL

## Verification

Minimum verification for each binding slice:

- `cargo test --manifest-path CTCore/Cargo.toml --features <feature>`
- `cargo test --manifest-path CTCore/Cargo.toml --all-features`
- iOS simulator build through `xcodebuild`
- Swift smoke path proving the app calls CTCore, not a parallel Swift reimplementation

For `HostConfigStore`, the smoke path should cover:

- valid config decodes
- invalid config returns stable diagnostic codes
- encoded config round-trips
- app still builds without `WorkspaceDocument` references

## Risks

- UniFFI may force API shape changes in CTCore types. Prefer a small binding facade over reshaping core domain models prematurely.
- Generated binding churn can make reviews noisy. Keep generated files isolated.
- XCFramework build complexity can leak into normal app development. Keep artifact build explicit and documented before wiring it into every Xcode build.
- Host config currently has a lightweight Swift `HostProfile` shape. Mapping to CTCore `HostConfig` must not silently lose credential references or endpoint meaning.
