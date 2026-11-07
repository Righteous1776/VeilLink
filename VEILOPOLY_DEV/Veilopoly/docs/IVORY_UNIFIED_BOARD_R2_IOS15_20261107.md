# Veilopoly 象牙白古典主视觉：统一合成 R2

Owner-selected authoritative main visual: `VL-IVORY-R1-004 / ivoryR1CenterInlay.png`, actual existing asset from previous generated batch.

## One integrated board, not 19 unrelated decorative images
- `KimiK2BoardSkin.install` now constructs a **single** SpriteKit `Veilopoly/IvoryUnifiedBoard` root. The 4 light Kimi material layers, master ivory center inlay, two card decks, turn banner and all 40 Codex-fine property tile sprites are children of the same unscaled, fixed 1024×940 board. No double perspective, duplicated positions or detached separate overlays.
- Prioritized master center image is **ivoryR1CenterInlay**; Codex `astraCenterCity` and Kimi emblem remain untouched fallback resources. Only one center is drawn.
- Light Kimi materials and 40 live Codex fine property tiles are the **default**. The dark theme remains opt-in without resetting the Engine.
- The two shallow physical card decks are brought to x248/x776, exactly adjacent to the x288…736 center plaque, and use the full ivory Chance/Chest card faces instead of scattering unrelated decorative icons. If either asset is absent, that deck gracefully uses Codex card face and icon.
- The previously unused ivory Turn Banner is now a subnode of the same board, visible only during a local human roll; it cannot falsely announce YOUR TURN during an AI turn or after victory.
- Original Codex **astraTileFace, astraTile[icons], astraCenterCity, house/hotel, four token variants, Astra B01 native actions, bank/auction/trade cards** are not overwritten. Icons and property prices are always live Engine data; card text and event ACK remain untouched.
- Runtime card reveal and victory display continue using the previous approved Ivory R1 assets. The 12 generated icons and alternate 2.5D house/hotel are kept dormant; drawing them on top of current Codex art would create double images.
- `BoardScene` keeps the same tile indices, hit targets, player token geometry, and camera focus. Only the cohesive board skin and default theme are changed.

## IOS 15
- Package minimum iOS15; iOS16 orientation geometry update gated; iOS15 public rotation fallback.
- `.scrollIndicators` and `.persistentSystemOverlays` unavailable dependencies removed.
- Full Xcode 15-target archive build, iPhone 7/ iOS15.8.3 GPU/touch, sprite placement, image memory and real two-device games are NOT YET RUN.
- All games in VeilLink share owner's iOS15 *policy goal*; this dedicated Veilopoly lane cannot edit the other game paths or production main without the other lane's review.

## Verification gates
- Sources prepared and branch-scoped. XCTest source includes root/style aliases, iOS15 contract, plaque/deck geometry and texture existence.
- **Do not** call this an Xcode verified render: SwiftPM iOS SDK and simulator are unavailable here.
