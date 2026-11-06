# Veilopoly · Kimi P4 visual usage R2 (2026-11-07)

Task: `VL-P4-KIMI-VISUAL-R2`
Original baseline: `29db11b5b3679a879f589cf8eaa8dcfc3c210f3d`.
Additional parallel stock-market change was checked at `b69f2644d4a870de4423686f988b7adb1baaad1f` and preserved; this change is additive outside that line's files.

## Integrated source behavior
- Kimi board now uses **dark and light** versions of Table / Edge / Base / Frame and the 40-tile atlas. The theme swaps SKTexture references only; existing Engine state, tile hit shapes and camera are not rebuilt.
- The **four-frame Kimi token shadow atlas** now renders shadow siblings below the four player tokens and follows token movement with an independent ground path; idle frames are static and reduced-motion/fast-forward paths reset them.
- **Kimi Victory Badge** now appears from `GameState.winner` only, with a dynamic player name and resets when no winner remains. Astra settlement text/HUD remains authoritative and accessible.
- Menu **更多 → 切换日间棋盘 / 切换夜间棋盘** allows switching without putting gameplay controls by the Exit capsule or shrinking the landscape board.
- Expanded iOS-only XCTest sources assert theme retains 40 tile identities and camera geometry, shadow state changes, and winner badge removal.

## Source wiring inventory and duplication decisions
- Out of the **25 Kimi PNGs** previously imported into SwiftPM Resources (897,638 compressed bytes), **23 have source-level UI/scene references**, tracked in `KimiK2VisualUtilization.swift`. This is a source-audit figure, NOT an empirical iOS rendering utilization metric.
- Deliberately deferred **two**: `kimiK2SpecialIconsMask` (already baked icons in 40-tile image; would draw twice) and `kimiCardFaceFrame` (keep the more complete working Astra B01 card-face).
- Original four Kimi tokens, six-state pulse, coin, banner, board frame, mortgage, owner strips and K1 building art remain integrated.
- Kimi supplied `fxPawnShadowAtlas` original dimensions 1024×128 / four 256×128 frames, verified locally against `fx-atlas-meta.json`; pulse 768×512 / six frames; cash 1024×256 / four frames.
- No extra external PBR ZIPs, fonts, or unconverted OGG bundles were added.

## External audio readiness, not integrated
- Selected Kenney CC0 impact, interface and music sources were locally inspected. Three mono 22,050 Hz PCM WAV candidates were generated with SHA-256/expected Git blob hashes; **the connected upload bridge failed (`container_session_expired`)**. Therefore they are not checked into GitHub or referenced by runtime. Audio extension should be retried via an authenticated asset-drop mechanism later.

## Verification boundaries
- Verified local source package PNG dimensions and frame boundaries; committed Swift source + XCTest additions.
- **NOT RUN:** exact-head Xcode iOS 16+ build, complete SwiftPM XCTest on macOS, simulated/physical iPhone touch/safe-area/VoiceOver, GPU texture memory/60-fps, 500-seed AI, P5 host integration.
- Both light and dark atlases are preloaded on skin initialization; memory pressure must be measured before release. Keep original fallback and avoid claiming optimized GPU memory.
- Did not modify `main`, versions, build workflows, signing, IPA, transport, bank/stock rules, or other Agent branch state.

## Follow-up: dynamic tile text overlays (2026-11-07)

- Original Kimi atlas artwork contains **static demo text**. Using it without an edit would show both demo names/prices and actual Engine names/prices on top of each other.
- `BoardScene.swift` now adds two small opaque parchment plates under the live label nodes on each of the 40 2.5D tile sprites, covering exactly the regions declared in the original `SPRITE_MAP.json`: name `[−(w−10)/2, −12, w−10, 32]`, price `[−(w−10)/2, −33, w−10, 14]`.
- An independent local source check compared these formulas against the original JSON for **all 40/40 tiles: PASS**. Kimi color bands/frame remain, label text/price are always read from `GameState`.
- Added `testFortyKimiTilesMaskPreviewTextAndUseEngineLabels` to the iOS-only SpriteKit test source. It must still run under Apple Xcode; no device success is claimed.
- Added a safe fallback guard: `更多 → 切换日间棋盘` is disabled if Kimi textures were unavailable and the original procedural board was selected.
- At final branch audit `e04cbb0bf01e31b1414c06d8784940ad6d0c4b29`, 10 additional commits vs original `29db11b5` were detected, including an unrelated **parallel stock-market feature**. These files were preserved, not cherry-picked or overwritten by the visual audit. GitHub returned **no CI statuses** for that head.
