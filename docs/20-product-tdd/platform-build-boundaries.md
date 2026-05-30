# Platform build boundaries

## CTCore iOS artifact

- producer: CTCore
  consumer: iPad client target
  artifact contract: `scripts/build-ctcore-ios.sh` regenerates UniFFI Swift bindings, builds CTCore for iOS device and simulator, and packages those static libraries into `clients/apple/iPad/Generated/CTCore/CTCore.xcframework`.
  source boundary: generated Swift binding source is checked in under `clients/apple/iPad/Generated/CTCore/`; generated binary artifacts are local build outputs and stay ignored by git.
  feature boundary: the iPad artifact is built with the `swift-bindings` CTCore feature, which currently pulls only the portable config binding surface into the client.

- build-system rule: the iPad Xcode target links `CTCore.xcframework` through its Frameworks phase.
  required ordering: the target keeps a `Build CTCore iOS Artifact` run script phase before Swift compilation so a fresh checkout can build without a preexisting XCFramework.
  dependency constraint: do not declare the generated `CTCore.xcframework` as a same-target run script output while the same target also links it in Frameworks. Xcode treats `ProcessXCFramework` as consuming that directory and creates a target dependency cycle.
  current tradeoff: the CTCore artifact script is marked to run every iPad build. If CTCore packaging later moves to a separate build target, Swift package, or CI-produced artifact, explicit output dependencies can be restored there instead.
