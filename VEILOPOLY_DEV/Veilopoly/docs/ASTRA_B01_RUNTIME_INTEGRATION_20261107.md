# Veilopoly Astra B01 v1.1 · UI runtime acceptance report

## Status and sources
- **Intake:** `VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/`. Astra's 91 original assets, 15 landscape previews, source SVGs, MANIFEST, ASSET_MANIFEST, SPRITE_MAP, and validation scripts remain immutable.
- **Runtime subset:** `Veilopoly/Sources/VeilopolyUI/Resources/`: 13 copied PNG blobs with identical Git blob SHA to their originals, total 274,487 bytes per manifest; 8.94 MiB of RGBA decoded memory if all selected textures load simultaneously (not an iOS measurement).
- **SwiftUI bridge:** `AstraB01AssetNames.swift` (portable mapping), `AstraB01Skin.swift` (Image/bundle, 9-slice, ButtonStyle), and changes to `UI.swift`; 3 portable registry XCTest cases added but **not run in hosted CI**.

## Live in code
| Visual | Data source | Interaction boundary |
|---|---|---|
| Button normal/pressed/disabled | Existing `action()` callbacks and SwiftUI enabled/pressed states | Actual `Button` remains clickable; art is non-interactive and hidden from accessibility |
| Side action panel and compact player HUD | Existing SwiftUI views, four player names/cash/status | Decorative glass/action skins; player HUD remains visible for all four |
| Error/event display | `GameSessionModel.errorMessage`, `lastFeedback` | Text remains dynamic; not baked into feedback PNG |
| Card face | `shownCard` + `CardRevealGate` | Background only; scrollable text and explicit human confirmation preserved |
| BUY ticket | `tile.name/price/rent`, acting player's remaining cash | No static monetary information; buy/auction buttons remain real SwiftUI controls below |
| BANK ticket | Acting player's cash, `banking.accounts` saved principals and loan obligations | Bank actions and numeric input below; no inferred returns from undecided rules |
| SETTLEMENT ticket | Winner, actual net worth, property count | Rankings and restart action remain real UI controls |

## Explicitly not completed
- The AUCTION and TRADE hero PNGs are present in `Resources/`, **not yet displayed**: their painted +/- regions require real 44pt interactive overlays, keyboard-safe input and dynamic text mapping before activation.
- Astra's 91-alias design system is not fully integrated. Full-screen preview PNGs are not game views and remain outside `Resources/`.
- Four-player narrow HUD currently uses generic glass panel skins, not the taller Astra-specific player cards; importing the full-width player designs would require a revised compact 2×2 / carousel layout and new accessibility checks.
- No iOS SDK / Xcode compilation, simulator run, touch, keyboard, VoiceOver, GPU profiling, safe-area or real gameplay acceptance. Linux toolchain does not compile `#if os(iOS)` UI implementation.
- B02 sequences and Kimi 2.5D model/render improvements remain pending, as does separately authorized P5 integration into the VeilLink host app.

## Next UI gates
1. Xcode iOS16+ clean build + Swift Package resource lookup for all active skins; test in phone 844×390 / 852×393 and iPad 1180×820 landscape.
2. Readability and contrast audit: original paper ticket needs dark dynamic text; bank deposit and loan panels need light labels; Accessibility Large Text must not be clipped.
3. Real bank numeric keyboard/auction bid edit: confirm focus, actions and cancel stay tappable in landscape; no dead painted buttons.
4. Auction and trade dynamic hero cards with programmatic +/- hit controls and data-driven labels; verify 44pt minimum after any scaling.
5. Low-memory texture decode and sprite cache: measure actual system/GPU memory in Instruments; avoid loading the entire 91 alias set.
6. Owner visual sign-off + Kimi full 2.5D board layering / zIndex / color harmony.
