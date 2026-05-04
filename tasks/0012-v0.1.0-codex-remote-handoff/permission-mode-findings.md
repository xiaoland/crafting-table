# Permission Mode Findings

## Date

2026-05-04

## Objective

Add a small Codex Remote composer control for per-turn permission mode:

- `sandbox`
- `auto_review`
- `full_access`

The control should stay inside the standalone Codex Remote path and should not depend on Goal Forest, Work Session, or Remote Control.

## Protocol Findings

The generated app-server TypeScript schema for `TurnStartParams` exposes these relevant override fields:

- `approvalPolicy`
- `approvalsReviewer`
- `sandboxPolicy`

The installed Codex binary also recognizes a `permissions` field, but local smoke showed that passing a profile selection such as `{ "type": "profile", "id": "auto" }` or `{ "type": "profile", "id": "workspace-write" }` tries to load a configured `[permissions]` profile and fails on hosts without that config.

For the MVP, Companion maps CraftingTable's stable `permission_mode` values to the schema-backed fields:

- `sandbox`: `sandboxPolicy.workspaceWrite` plus `approvalPolicy: "on-request"` and `approvalsReviewer: "user"`
- `auto_review`: `sandboxPolicy.workspaceWrite` plus `approvalPolicy: "on-request"` and `approvalsReviewer: "auto_review"`
- `full_access`: `sandboxPolicy.dangerFullAccess` plus `approvalPolicy: "never"` and `approvalsReviewer: "user"`

## Implementation Shape

- `TurnSubmitRequest` accepts optional `permission_mode`.
- Companion owns the mapping from public mode to app-server payload.
- CraftingTable stores `selectedPermissionMode` per active host runtime.
- Thread Page composer renders a compact permission picker.
- New iPad submissions send `permission_mode`; older clients can omit it.

## Verification

- `codex app-server generate-ts --out /tmp/codex-app-server-ts`
- local smoke confirmed profile-selection `permissions` payload is rejected without `[permissions]`
- `cargo fmt --manifest-path Companion/Cargo.toml`
- `cargo test --manifest-path Companion/Cargo.toml`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
- local async Companion smoke on `127.0.0.1:3775` started and reconciled turns for `sandbox`, `auto_review`, and `full_access`
- the smoke sent a final `sandbox` turn so the tested thread ended on the default permission path

## Remaining Risk

`workspaceWrite` currently passes an empty `writableRoots` array and relies on Codex's turn cwd handling for the active workspace. This matched local smoke. If a future Codex app-server release changes workspace-write semantics, Companion should switch this mapping behind the same `permission_mode` boundary.
