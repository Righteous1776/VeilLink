# Veilopoly Astra B01 v1.1 · UI runtime acceptance report

## Status and sources
- **Intake:** `VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/`. Astra's 91 original assets, 15 landscape previews, source SVGs, MANIFEST, ASSET_MANIFEST, SPRITE_MAP, and validation scripts remain immutable.
- **Runtime subset:** `Veilopoly/Sources/VeilopolyUI/Resources/`: 20 copied PNG blobs with identical Git blob SHA to their originals, totaling 333,980 bytes per Astra manifest; 10.21 MiB estimated RGBA decode if loaded together (not iOS GPU profiling).
- **SwiftUI bridge:** `AstraB01AssetNames.swift` (portable mapping), `AstraB01Skin.swift` (Image/bundle, 9-slice, ButtonStyle), and changes to `UI.swift`; portable registry and auction-hit-zone XCTest source added; **not executed in hosted CI or Xcode**. Standalone Swift 6.2.1 geometry smoke checked five assertions.

## Live in code
| Visual | Data source | Interaction boundary |
|---|---|---|
| Button normal/pressed/disabled | Existing `action()` callbacks and SwiftUI enabled/pressed states | Actual `Button` remains clickable; art is non-interactive and hidden from accessibility |
| Side action panel and 2×2 player HUD | Live SwiftUI names/cash/location/status, actor | Astra action/glass and four state-specific player skins; player content remains data-driven |
| Error/event display | `GameSessionModel.errorMessage`, `lastFeedback` | Text remains dynamic; not baked into feedback PNG |
| Card face | `shownCard` + `CardRevealGate` | Background only; scrollable text and explicit human confirmation preserved |
| BUY ticket | `tile.name/price/rent`, acting player's remaining cash | No static monetary information; buy/auction buttons remain real SwiftUI controls below |
| BANK ticket | Acting player's cash, `banking.accounts` saved principals and loan obligations | Bank actions and numeric input below; no inferred returns from undecided rules |
| SETTLEMENT ticket | Winner, actual net worth, property count | Rankings and restart action remain real UI controls |
| AUCTION ticket | Live property name, high bid, leading player, typed amount | Real native 44×44pt +/- hit regions over painted positions and separate native bid/fold buttons; reducer validates amount |
| TRADE ticket | Offer/request property counts and cash from live TradeState | Original accept/reject/counter buttons still call engine actions |

## Explicitly not completed
- The AUCTION and TRADE hero PNGs are now **displayed with dynamic live values and native controls**. **iOS keyboard positioning and actual hit-testing are not yet verified**. The 44pt touch boxes are geometric design coordinates and have not been device-measured.
- Astra's 91-alias design system is not fully integrated. Full-screen preview PNGs are not game views and remain outside `Resources/`.
- Four-player narrow HUD now uses a 2×2 grid with Astra state-specific textures and dynamic VoiceOver descriptions; **large-font legibility, visual overlap and real device accessibility remain unverified**.
- No iOS SDK / Xcode compilation, simulator run, touch, keyboard, VoiceOver, GPU profiling, safe-area or real gameplay acceptance. Linux toolchain does not compile `#if os(iOS)` UI implementation.
- B02 sequences and Kimi 2.5D model/render improvements remain pending, as does separately authorized P5 integration into the VeilLink host app.

## Next UI gates
1. Xcode iOS16+ clean build + Swift Package resource lookup for all active skins; test in phone 844×390 / 852×393 and iPad 1180×820 landscape.
2. Readability and contrast audit: original paper ticket needs dark dynamic text; bank deposit and loan panels need light labels; Accessibility Large Text must not be clipped.
3. Real bank numeric keyboard/auction bid edit: confirm focus, actions and cancel stay tappable in landscape; no dead painted buttons.
4. Validate the implemented auction and trade dynamic hero cards: actual +/-/input hit priority, native bid/fold behavior, keyboard focus and 44pt minimum after any hero scaling.
5. Low-memory texture decode and sprite cache: measure actual system/GPU memory in Instruments; avoid loading the entire 91 alias set.
6. Owner visual sign-off + Kimi full 2.5D board layering / zIndex / color harmony.


## Astra B01 second-stage concurrent UI intake and regression fix (2026-11-07)

- `c30d192ee9ec...`: 7 extra textures were staged by another scoped UI Agent (secondary button normal/pressed/disabled + current/jailed/bankrupt/normal player HUD), bringing selected B01 runtime PNGs from **13 to 20**. No Kimi textures or game Engine were overwritten.
- `b5669cc5c95ad075f2892415308ea73f2f51dfa5`: uses explicit @2x `UIImage` scale via cached `AstraB01Artwork.image` for pixel-to-point correctness; enables secondary action skins and dedicated four-player status skins. This was a concurrent branch change, preserved rather than overwritten.
- `cc0958a6e9987b9e9ec20fd62b49e6d42b4f1cc9`: card/financial UI quality follow-up on current source: prevent Astra feedback background's baked icon from overlapping a duplicate SF Symbol, show "余额不足", disable BUY when available cash is below cost, and disable a bid below or equal to current high bid.
- `d6662637d4678a162ed048a68a0f606d7098e32c`: fix a definite stale test assertion expecting 13 unique names after the asset set grew to 20; compare unique count to registered runtime count.
- Static Git tree audit confirms **20/20** imported B01 PNG aliases have corresponding Resources paths with blob SHA identical to Astra intake originals; per-manifest compressed PNG total **333,980 bytes** and decoded RGBA estimate **10.21 MiB** if all decoded at once (not device GPU telemetry). Nine-slice source cap insets remain within each original logical asset size.
- The broader 91-alias Astra package still lives in `INCOMING_ASSETS/`, and **AUCTION/TRADE hero overlays were implemented in source after that note**. Kimi B02 and P5 are not part of this change.
- No exact branch-hosted XCTest, Xcode iOS build, safe-area, haptic, keyboard/VoiceOver, GPU/frame-time, or IPA verification was performed in this turn.


## P4 completion delta — interactive AUCTION and TRADE (2026-11-07)

- `ea35976fcd1037c3b875db9f86173940aa0f6064`: added genuine AUCTION and TRADE paper hero views, bound to the current `AuctionState` / `TradeState`; the +/- skin decorations now have real SwiftUI 44×44pt controls. Auction field edits a live `bidderCash` value, while submit/withdraw still use the authoritative `.bid` reducer. No new bidding rules were invented: the minimum legal bid remains `currentBid + 1` in Engine.
- `7f7a8fc41989f28d501c9eec71407dd1e0864784`: explicitly convert portable source-coordinate centers to `CGFloat` in SwiftUI. Geometry comes from Astra's 256×174pt hero metadata, not from 512×348px bitmap positions.
- `AstraB01AuctionHitZones.swift` + `AstraB01AuctionHitZonesTests.swift`: separate 44pt +/- and 132pt bid-input slots; **standalone local Swift 6.2.1 geometry smoke: 5 assertions passed**, with **no Apple SDK/iOS XCTest run**.
- This report supersedes the historical '13 assets', 'generic player HUD' and 'auction/trade still staged' statements above. All 20 runtime PNGs remain source-identical, the other 71 incoming B01 aliases are not automatically loaded. Full manual iPhone/iPad UI acceptance and Kimi composition still pending.
