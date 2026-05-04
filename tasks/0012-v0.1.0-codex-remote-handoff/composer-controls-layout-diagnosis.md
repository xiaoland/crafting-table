# Composer Controls Layout Diagnosis

## Date

2026-05-04

## Reported Reality

The model, reasoning effort, Fast toggle, and permission mode controls could lose their visual alignment when the app sidebar changed state. The visible symptom was abnormal text wrapping in controls such as `GPT-5.5` and `Medium`.

## Evidence

Simulator diagnosis used `iPad Pro 13-inch (M5)` on iOS 26.3 with a local Companion on `127.0.0.1:3765`.

Observed before the fix:

- With the app sidebar visible, `GPT-5.5` wrapped as `GPT` / `-5.5`, and `Medium` wrapped as `Medi` / `um`.
- With the app sidebar hidden, the same controls still wrapped, so the immediate layout pressure lived inside the composer controls row.
- Accessibility still exposed the picker labels as complete values, which confirmed this was a visual layout compression issue.

## Fix Shape

- Replace the `ViewThatFits` composer controls layout with one horizontal row.
- Put model, reasoning, Fast, and permission controls inside a horizontal `ScrollView`.
- Keep Send controls fixed at the trailing edge.
- Give picker and toggle labels a shared non-wrapping label view.
- Fixed-size the options strip horizontally so controls scroll before their labels wrap.

## Verification

- `xcodebuildmcp` simulator build and run succeeded on `iPad Pro 13-inch (M5)`.
- Simulator visual check with the app sidebar visible showed `GPT-5.5`, `Medium`, `Fast`, and `Sandbox` on one line.
- Simulator visual check with the app sidebar hidden showed the same controls still on one line, with Send fixed on the trailing edge.
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/craftingtable-derived build`
- `xcodebuild -project CraftingTable.xcodeproj -scheme CraftingTable -destination 'id=00008132-000245583AD1401C' -derivedDataPath /tmp/craftingtable-device-derived DEVELOPMENT_TEAM=7J9DJNJ782 build`
