# Apple Client Guide

Read this file when working in `clients/apple/`.

## Scope

- `CraftingTable.xcodeproj` owns Apple client targets.
- `iPad/` contains the current iPad SwiftUI app.
- `macOS/` contains the first macOS Host Runtime client target.

## Boundaries

- Keep platform lifecycle in the Apple client layer: scenes, windows, login item, background residency, Keychain, permissions, and asset catalogs.
- Keep portable business behavior in `CTCore`.
- Keep generated CTCore Swift binding source under the client tree while the binding pipeline is young.
- Keep generated CTCore binary artifacts ignored by git.

## Build Notes

- The Xcode project lives two levels below the repository root, so scripts that need repo-root paths must use `$(SRCROOT)/../..` or a `REPO_ROOT` environment variable.
- Do not declare generated `CTCore.xcframework` as a same-target run script output while the same target links it in Frameworks; that creates an Xcode dependency cycle.
