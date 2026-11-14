# ECLIPSE theme adapter contract — no new visual system

- Veil 原生: `.veilCard()` chooses VeilPanelShape asymmetrical cut, original black/gold and Veil animation.
- Apple Soft: `.veilCard()` chooses VeilAppleSoftSurface, automatic day/night and iOS26 material under app's own implementation.
- 拟物仪器 (user screenshots): `.veilCard()` chooses VeilInstrumentPlate; use palette gold for orange accent, palette hairline for strokes, optional VeilIndicatorLamp.
- 浮屿: `.veilCard()` chooses elevated island with native glow border and shadow.
- 白描: `.veilCard()` chooses only hairline section, no background/material; remains protected by experimental permission gate.
- Source uses VeilTheme.text, secondaryText, tertiaryText, gold, goldBright, obsidian, hairline; VeilSpacing.md/sm/xxs. Only one explicit `Color(red:0.42,green:0.29,blue:0.15)` remains: parity with existing GomokuBoardView board color.
- The app's theme changes are observed through `@ObservedObject private var appearance = VeilAppearanceController.shared` and `.veilCard()`, without a second theme preference field.
- Only Gomoku's previous avatar slot becomes ECLIPSE; other-game Grok UI unchanged.
- During active play no spatial search traces, hints or PV/candidates; abstract-only render.
- See full 15,964-byte SwiftUI source and 25,655-byte four-file PATCH.diff in owner ZIP SHA from MANIFEST.
