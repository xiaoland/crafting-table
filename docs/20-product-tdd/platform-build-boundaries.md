# Platform build boundaries

## CTCore Apple artifact

- producer: CTCore
  consumer: iPad and macOS client targets
  artifact contract: `scripts/build-ctcore-apple.sh` regenerates UniFFI Swift bindings, builds CTCore for iOS device, iOS simulator, and macOS, and packages those static libraries into `clients/apple/iPad/Generated/CTCore/CTCore.xcframework`.
  source boundary: generated Swift binding source is checked in under `clients/apple/iPad/Generated/CTCore/`; generated binary artifacts are local build outputs and stay ignored by git.
  feature boundary: iPad slices are built with `swift-bindings`; the macOS slice is built with `swift-bindings,codex-remote-control-server` so the macOS client can start CTCore Codex Remote Server in-process.

- build-system rule: Apple Xcode targets link `CTCore.xcframework` through their Frameworks phases.
  required ordering: targets keep a `Build CTCore Apple Artifact` run script phase before Swift compilation so a fresh checkout can build without a preexisting XCFramework.
  dependency constraint: do not declare the generated `CTCore.xcframework` as a same-target run script output while the same target also links it in Frameworks. Xcode treats `ProcessXCFramework` as consuming that directory and creates a target dependency cycle.
  current tradeoff: the CTCore artifact script is marked to run every iPad build. If CTCore packaging later moves to a separate build target, Swift package, or CI-produced artifact, explicit output dependencies can be restored there instead.
