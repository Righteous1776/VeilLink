# Veilopoly unified gameplay composition

Task: `VEILOPOLY-GAME-COMPOSITION-004`  
Baseline: `f98b29a4223c0b3fd3acb961b6a217e273103e8b`  
Branch / scope: `dev/veilopoly:VEILOPOLY_DEV/**`

## Live composition

| Layer | Existing source / real assets | Gameplay connection |
| --- | --- | --- |
| Rules and cash | VeilopolyEngine, IntegratedBanking, StockMarket | One GameState, sequence and reducer for property, bank, market and trade |
| Board | Kimi K2 day/night table, frame, 40-cell atlas and live labels | Engine tile IDs, owners, mortgage and buildings control visuals |
| Player identity | Four Kimi token PNGs; existing Kenney token fallback | Same player identity appears on board, Astra HUD and collapsed operation entry |
| Native controls | Astra B01 panels, player skins, five hero cards and button states | Real Buttons, fields and reducer actions remain above decorative artwork |
| Cash and movement | Existing dice sheet, Kimi cash-chip/pulse/banner, sound and ACK pipeline | Stock trades now join bank cash feedback; price ticks stay quiet |
| Cards and settlement | Astra card/settlement art; existing chance/chest PNGs | Correct deck image and title; actual winner; shared account summary |

The 25 selected Kimi PNG and 20 Astra PNG runtime resource contracts are retained. No duplicate PNGs, new fonts or binary dependencies were introduced. The Kimi special-icons mask and card-face frame remain deliberately deferred where they compete with already working tile art and Astra card presentation. The larger incoming Astra source kit remains editable source material, not a full-screen gameplay image.

Historic FinanceSandbox / printed-tabletop profiles remain reference/oracle code. Conflicting GO, building/star and unapproved product-yield rules are not activated as a second game. The actual game follows the existing canonical reducer.

## Interaction flow

- Board-first landscape and the separate top-right More/Exit capsule are preserved. Tapping a board cell opens its detail drawer and selects the property section.
- Asset management uses four 44pt sections: property, bank, market, trade. The end-turn / extra-turn action stays outside the scroll area. Switching sections resets scroll position; routine market ticks do not.
- Purchase, auction, trade response, debt and winner decisions reveal the drawer after animation ACK. Free management remains collapsible. The terminal stays mounted, but disabled, while a stock cash effect plays, preserving buy/sell input state.
- Property actions preview the existing pure reducer and display rejection reasons. Bank deposit/loan and trade proposals do the same. UI projections never commit a move or consume the actual RNG.
- Actor changes clear stale trade drafts; target changes clear the requested property set. Cash counteroffers retain the existing property/card transfer terms in the recipient's perspective.
- Opportunity and chest cards use their actual deck art/title. New narration covers mortgage, redemption, rent, building sale and completed/rejected trade.
- Header and settlement use the same book-net-assets calculation: cash + property book value + savings principal + pending investment principal + stock market value - total agreed loan dues. This is a display projection, not a replacement winner rule or a promise of investment payout.

## Verification and handoff

`GamePresentationTests` covers reducer-derived property availability without state mutation, bank/stock/debt accounting, required decision routing, cash counteroffers retaining property, and a combined deterministic property→bank→stock→trade→end-turn replay. A guarded iOS test additionally checks stock cash command routing.

Linux Swift 6.2.1: `swift build --jobs 2` → successful → PASS; `swift test --jobs 2 --filter GamePresentationTests` → 5/5 → PASS; `swift test --jobs 2` → 139/139, 0 failures → PASS. This includes the bounded 500-seed AI smoke and 20 exploratory long games, not 500 naturally finished games. ARM64 iOS16 frontend parse → successful → PASS for grammar only. Apple SDK type-check and visual acceptance remain pending; no simulator/device result is claimed.

Apple acceptance: start via `veilopolyFullscreen`, confirm 844×390 / 852×393 / 1180×820 landscape; tap all corner/edge cells; buy/auction; switch four management sections; ensure pinned end-turn and independent Exit; buy/sell stocks and wait for cash ACK; switch human trade actor and cash counteroffer; read both deck types; test day/night, Reduce Motion, VoiceOver, keyboard and winner reset. Check actual texture contrast and gesture overlap on rendered frames before calling the composition visually accepted.
