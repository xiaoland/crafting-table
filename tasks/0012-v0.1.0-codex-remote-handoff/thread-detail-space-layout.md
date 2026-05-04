# Thread Detail Space Layout

## Slice Goal

Give the Codex Remote message transcript more vertical space by moving thread and project metadata out of the Thread Detail view.

## UI Changes

- Thread Detail view now starts directly with the message transcript and composer.
- Desktop status remains in the sidebar Desktop section.
- The Thread Detail metadata header was removed.
- Selected thread cards now show selected-thread detail metadata when available: updated time, status, and turn count.
- Project path / thread CWD is shown below each project section title in the sidebar.

## Verification

Commands run from `/Users/lanzhijiang/Development/workbench`:

- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
