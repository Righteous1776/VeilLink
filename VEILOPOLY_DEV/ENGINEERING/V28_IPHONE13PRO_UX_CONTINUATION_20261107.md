# Veilopoly V28 iPhone 13 Pro UX · Branch-only continuation

**Disposition:** DEVELOPMENT-ONLY / UNMERGED / NO IPA / NO RELEASE

**Owner instruction:** work directly on the existing dedicated integration branch like an Inbox drop. Do not open PRs, merge main, dispatch iOS CI, sign or export IPA until an explicit later integration/release instruction.

- Branch: `integration/v28-veilopoly-iphone13-ux-p0-20261107`
- Base main: `2c5b5161027edff097b27fe3323d30f6ca3e430e`
- Prior PR #164: closed, never merged.
- Published rollback: `v28.0-b65`; unchanged.

## Work staged in this branch

| Owner-reported defect | Code treatment | Key files |
| --- | --- | --- |
| Native iOS amount keyboard blocks the field/actions | Dedicated three-row, four-column numeric keypad, visible value and Done; numeric actions from auction, bank, stock and trade share one input flow | `VeilopolyNumberPad.swift`, `UI.swift`, `StockMarketPanel.swift` |
| Board squares appear untappable or select adjacent cells | Fixed-scene nearest-center selection and an independent pure geometry test suite; ignores empty center; tap opens read-only full-screen tile registry | `VeilopolyTileHitTesting.swift`, `VeilopolyTileHitTestingTests.swift`, `BoardScene.swift`, `UI.swift` |
| Must buy/auction before inspecting asset sections | Always-open, read-only property/bank/simulated-stock/trade browser; full-screen editable management workspace only in the legal .manage phase | `UI.swift` |
| Forced buy/auction | Explicit voluntary `skipPurchase` reducer move and regression tests; maintains cash, ownership and move-log replay; other classical choices remain | `Models.swift`, `Rules.swift`, `StartAuctionTests.swift`, `UI.swift` |
| Tiny buttons and over-decorated invisible hit zones | Visible SF Symbols, minimum 44–48-point touch targets, non-intercepting decoration, reachable pinned buy/pass and bid/pass controls | `UI.swift`, `StockMarketPanel.swift`, `AstraB01Skin.swift` (existing) |
| Board magnifies during movement and player loses token | Stationary camera; longer normal step duration (0.42s slow / 0.26s standard) with user-visible speed selection; Reduce Motion retains brief steps | `BoardScene.swift`, `UI.swift` |
| Insufficient asset, rent and document detail | Full-screen deed and independent 40-tile registry; complete rent table, building cost/status, larger documents and guide text | `UI.swift`, `VeilopolyCivicDocumentPanel.swift`, `VeilopolyGuideSheet.swift`, `VeilopolyGuideLibrary.swift` |
| Day/night toggles only one layer | Unified SwiftUI canvas + SpriteKit K2 and procedural fallback palettes; persisted preference; guide/document contrast | `BoardScene.swift`, `UI.swift`, `VeilopolyGuideSheet.swift`, `VeilopolyCivicDocumentPanel.swift` |
| No persistent movable finance/stock mini windows | Independent 44-point drag handles vs tap-to-inspect data area, clamp to available landscape space, persist x/y and visibility, one-touch reset | `UI.swift` |
| Missing gambling/chance feature | Standalone non-wager dice probability laboratory only. No stake, currency movement, gambling or cash-out functionality | `UI.swift` |

## Local / CI evidence boundaries

- **This continuation did not dispatch CI or IPA.** The workflow has push-main / PR triggers; PR #164 remains closed.
- Latest *historical* successful Apple CI #42355471423 belongs to old commit `7f2c78b9...`, **not** to this updated branch head. It does **not** validate the new SwiftUI changes.
- Portable geometry: seven nearest-tile cases were executed locally via Linux Swift command-line compilation and passed (overlap, dictionary-order independence, ties, center reject, radius boundary, invalid coordinate). This is **not** an iOS Simulator or iPhone device validation.
- New unit tests are staged but have not been run as part of a full SwiftPM package test in this batch. No iPhone 13 Pro screenshot/physical touch re-test on this candidate.

## Future owner-authorized integration gates

1. Re-sync `main`, review all changes and other agent overlap; resolve in controlled integration.
2. Run complete portable Engine/AI/UI tests, iOS Simulator SwiftUI compilation, XCTest/UI smoke and unsigned iPhoneOS build **only when Owner authorizes**.
3. Reproduce on iPhone 13 Pro landscape: first auction input, skip purchase, all 40 tile touches, swipe to scroll, sheet transitions, no overlapping buttons, HUD drag/tap and reposition across relaunch, night and day with/without K2 assets.
4. Replay older saved games and new `skipPurchase` move log, confirm financial invariants and no unwanted bank/stock mutations.
5. Produce new version and IPA only upon explicit release request; leave v28.0-b65 immutable.

## Known limitations / pending verification

- The large SwiftUI presentation has **not** been Apple-typechecked after the latest modifications.
- True iPhone hit-test and VoiceOver performance require a physical-device check.
- The probability tool deliberately avoids any wager/stakes; do not misrepresent it as a casino.
- Mini-window positions are locally persisted and clamped to known landscape layout, but multi-device and unusual dynamic-type dimensions need visual audit.
- No changes to VeilLink BLE/LAN protocols, SQLite migrations, version/build tags, signing settings or `.github/workflows/**`.
