# ECLIPSE R11 — video reference, deliberate design translation, and de-dup ledger

## Source reference
Owner-provided 22.03 s / 30 fps video `1e4775fbcd6101479e32f2a76fbd557b.mp4` (provided in chat; not uploaded to GitHub).
It depicts a **black instrumentation canvas**, a broad curved radial band filled with dense short algorithm-like text, pale spokes/streaks across the surrounding canvas, and a grid of eight compact terminal/visualization panels along the lower edge. Sampled frames at 0, 3, 7, 11, 15, 19 seconds showed persistent layout with high-frequency changes in line density and brightness.
This informs the *motion grammar*, not a claim to reproduce exact copyrighted code or actual reasoning.

## R11 implementation and boundaries
1. Keep ECLIPSE inside the **existing VeilLink appearance engine**: `VeilAppearanceController`, `VeilTheme`, `.veilCard`. **Do not** paint the entire application black: only the inset rectangular instrument surface.
2. Existing R10 `VeilEclipseBoardThoughtField` supplies dynamic dense line field; R11 only adds **one** black text-flow dashboard to the original identity card and to expanded TRACE. The obsolete `EclipseAbstractThoughtField` duplicate was removed from the proposed SwiftUI file. No second board or custom theme.
3. `VeilEclipseConsoleStream`: ~14 scrolling decorative code rows/s, 6/s in Low Power, bounded line length/row count with deterministic content and no board/PV/candidate inputs.
4. `VeilEclipseComputeConsole`: actual `isComputing` + `actualSearchStartedAt` gate; refresh up to 24Hz (9Hz Low Power). Search starts only after controller's real pre-delay, stops on cancellation. Supports Reduce Motion. **Never delays a move.**
5. Measured depth/nodes appear only from previously validated `VeilEclipseTracePolicy.LiveMetrics?`. Today current main does NOT emit that stream, so show unknown fields; animated synthetic text is clearly labeled **视觉编码流 / 非真实搜索日志**.
6. R10 `VeilGomokuMatchArchive` preserves every finished/interrupted local match as a separate validated UUID JSON journal; does not replace last-match resume file or self-training database.
7. No live search projection, code line, grid mark, candidate cell, threat line or future PV is shown to the human player. Actual-match readonly replay remains **postgame only**.

## Reuse existing PR — DO NOT DOUBLE-APPLY
- **#208 is the canonical UI/history/visualization Inbox track; updated in place with R11 source and the combined product PATCH.diff.** No new UI PR.
- #203 (R8 theme), #204 (R9 gate), #197/#198 older UI: antecedents only, their proposals are not separately applied alongside #208. #208 already contains their applicable theme/fair-play work.
- #199 V9 difficulty and forcing-four, #206 V10 proven threat search: tactic lane remains independent. ECLIPSE only reads the actual `BoardBotDifficulty.title`.
- #193 / #196 R5 original native search: research / proposed engine; R11 UI does not fork or import its search algorithm.
- #207 R10 adversarial planner, #209 measured candidate learning, #210 R11 tactical oracle: independent competing/adjacent engine improvements. **DO NOT auto-merge or change their decision priority or compute budgets**. Integration Governor must arbitrate/search-test these before promotion.
- Dedicated active integration needs Governor staging branch, full current-main patch preflight, Xcode CI and XCTest; no silent promotion to main.

## Verified
- Swift 6.2.1 Linux strict: R11 console **413** assertions; R10 archive/thought pattern **39**; fair-play policy **18**; telemetry gate **35** = **505** total local test assertions passed.
- SwiftUI source Swift5 parser accepted; this **is not** Apple iOS typechecking.
- Chromium/Playwright at 320×640, 390×844, 768×1024: toggles, code scroll, TRACE sheet, no page JS exceptions or horizontal overflow.
- iOS/Xcode/device tests NOT RUN; no IPA, no release.
