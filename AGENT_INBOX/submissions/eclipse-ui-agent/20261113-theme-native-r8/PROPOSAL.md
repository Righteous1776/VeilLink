# ECLIPSE R8 · Make UI an actual VeilLink citizen

## Owner correction
Earlier R6/R7 created a separate visual skin that did not correctly follow the installed VeilLink app. The owner explicitly requires the **existing app visual system**, not merely a similar theme. User screenshot is Instrument Dark. This proposal overrides earlier custom colors/shapes, but preserves R7 no-hints policy.

## Verified existing theme entrypoints on main eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0
- `VeilLink/Core/AppearanceTheme.swift`: `VeilAppearanceSelection` identifiers `veilOriginal, appleSoft, instrumentAuto, plainline, islet`, Light/Dark/Automatic color mode. `plainline` is an authorization-gated experiment.
- `VeilLink/Core/AppTheme.swift`: dynamic `VeilTheme` palette and `VeilCardModifier`, which chooses VeilPanelShape, VeilAppleSoftSurface, VeilInstrumentPlate, Plainline hairline or Islet elevated material.
- `VeilLink/Core/SkeuomorphicComponents.swift`: VeilIndicatorLamp etc.
- `VeilLink/UI/MiniGameViews.swift`: the production GomokuBoardView has a fixed brown field, 15×15 grid, five stars and dynamic VeilTheme gold highlights. Replay follows its established values, no new board skin.
- `GameLobbyView.swift`: existing optional Grok card at 362–379 and adjacent board. Replace **only Gomoku's bot slot**; other games keep Grok media.

## Implemented in owner source package
- Original SwiftUI ECLIPSE circular icon + identity card; all visual colors from `VeilTheme`; external card surface owned by `.veilCard()`; `VeilAppearanceController.shared` observed for live changes.
- TRACE sheet uses app ambient background, card modifier, text/accent/muted tokens and board replay using actual game-board palette.
- Existing theme selector determines ECLIPSE appearance. No separate ECLIPSE theme setting, no independent neon blue/gold palette.
- Existing UI only exposes genuine status and last duration; unknown future R5 depth/nodes remain `nil` until real engine emits them.
- Strict fair-play: active game never reveals recommendations, unsafe points, candidate rankings, PV, danger coordinates, directional chess animation. The abstract graph is decorative, independent of actual board. Postgame separate read-only board can replay actual verified moves only.

## Source patch maturity
Owner ZIP includes the full new Swift source, correct line-numbered diff against four targeted files (two source additions and hooks in GameLobbyView + LocalAIGameController), theme preview, screenshots, tests, SHA manifest. The latest patch was **recreated from actual current-main source lines** and removes stale synthetic patch pad placeholders. Four anchor fragments rechecked against GitHub API current main.

## What is not done
No full main checkout application, no Apple Xcode/iOS SwiftUI typecheck, no XCTest, no IPA, no R5 live telemetry, no governor merge. Previous partial fake-context patch should not be used.
