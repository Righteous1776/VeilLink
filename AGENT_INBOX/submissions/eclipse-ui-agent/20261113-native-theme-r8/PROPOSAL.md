# Replace ECLIPSE's independent appearance with VeilLink's existing visual system

## Owner evidence
Two screenshots show the actual local Gomoku / Settings UI, specifically Settings > 外观与数据 > 外观主题, where **拟物仪器** is selected and display mode is **深色**. User explicitly rejects the isolated blue/gold/cyberpunk concept from earlier R6/R7.

## Exact current-main theme identifiers
`VeilLink/Core/AppearanceTheme.swift` defines `VeilAppearanceSelection`: `.veilOriginal`, `.appleSoft`, `.instrumentAuto`, `.islet`, plus authorization-gated `.plainline`.
`VeilAppearanceController.shared` manages `selection`, `colorMode` (automatic/light/dark), and dynamic `palette`.
`VeilLink/Core/AppTheme.swift` defines `VeilTheme`, `VeilSpacing`, `VeilCardModifier`/ `.veilCard()`; its dispatch automatically chooses Veil Original cut-corner panels, Apple Soft surface, Instrument plate, Islet island cards and Plainline divider rows.
`VeilLink/Core/SkeuomorphicComponents.swift` provides `VeilInstrumentPlate` and `VeilIndicatorLamp`.
`VeilLink/UI/MiniGameViews.swift` has the authoritative Gomoku board presentation: brown `Color(red:0.42,green:0.29,blue:0.15).opacity(0.46)`, 15x15 grid in white 0.27, star points [48,56,112,168,176].

## R8 implementation delivered separately to owner (source SHA in MANIFEST)
1. ECLIPSE remains in original Grok identity card slot **only in Gomoku**, now with original 76pt icon footprint, normal `.headline`, palette-driven `VeilTheme.text/gold/hairline/obsidian`, and existing card layout, not its own hardcoded metal blue.
2. `VeilEclipseAvatar` uses palette colors; Instrument theme can show native `VeilIndicatorLamp`. It is original SwiftUI glyph; does not rename/reuse Grok video asset.
3. `EclipseAbstractThoughtField` and in-sheet metric group directly use `.veilCard()` and `VeilPanelShape`, not a separately designed fixed palette. Light/dark follows the app automatically. No new theme UserDefaults key.
4. The independent postgame read-only board copies actual GomokuBoardView palette/grid/star-point numbers. It does not modify the interactive board.
5. Fair-play policy from R7 unchanged: no live coordinate, candidate, PV, threat location, win probability, heatmap, or advice. No user hints; historical replay only after finished and saved board validated.
6. This task does **NOT** attempt integration with native search R5 or delete the JSCore engine.

## Local validation
- Swift 6.2.1 Foundation-only FairPlay policy + 15 assertions pass; SwiftUI source parses.
- Full proposed four-product-file PATCH.diff (two new files and two existing-file wiring changes), 25,655 bytes, passed `git apply --check` on synthetic exact source snippets from eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0, NOT on a full checkout.
- Chromium at 320/390/768 widths: all five simulated themes, match/replay guard, no horizontal overflow or JS runtime errors. HTML palettes are visual approximations; **SwiftUI uses the real VeilAppearanceController**.
- iOS/Xcode/XCTest REAL compile/build remains unverified.
