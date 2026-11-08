# VLP-CODEX-W1-002 — independent read-only asset browsing

Baseline: de8893f; main unchanged at 2c5b5161027edff097b27fe3323d30f6ca3e430e.
Scope: dev/veilopoly:VEILOPOLY_DEV/**. No rule, save, network or resource changes.

## Implemented

- Separate asset sheet from More and a 44pt entry above the decision drawer.
  No manage-phase or pending-animation gate on these browsing entries.
- Switch public player seats, including bankrupt seats; view owned/all 40
  cells, printed rent tables and building/mortgage details; existing savings,
  loan and investment contracts; real stored simulated quotes/chart/holdings;
  pending trade cash/property/jail-card terms and public asset overview.
- Pure snapshot reads current canonical state. No banking initialization, RNG,
  Move or order callback; no hidden buy/auction/accept/borrow action in the sheet.
  Existing decision controls and reducer permissions remain unchanged.
- Scroll identity depends on seed/seat/section, not tick/sequence/phase. Return
  explicitly dismisses; opening does not promise to pause the match. New sheet
  uses the board's selected day/night scheme and native semantic text colors.
- No new art, dependency, license or binary. Reuses existing stock chart.

## Executed checks

`swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2 --filter AssetBrowserSnapshotTests`
→ 3 tests / 0 failures, covering all 8 phases × 4 seats, absent finance,
bank/market/trade copies, eliminated seat and invalid seat bounds → PASS.

`swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2`
→ Linux Swift 6.2.1, 240 tests / 0 failures, 39.571s → PASS.

`swiftc -frontend -parse -target arm64-apple-ios15.0 AssetBrowser.swift UI.swift`
→ exit 0 → PASS (grammar only). Apple SDK type-check, iOS XCTest, simulator,
real iPhone/iPad, VoiceOver and rendered UI → NOT_RUN.

## Remaining acceptance / risk

On 844×390, 852×393 and 1180×820, open from collapsed More and expanded drawer
in purchase, auction, trade, debt, animation and finished phases. Browse four
sections; return to the same pending decision without submitting a Move. Select
another seat; inspect all cells; verify tick refresh does not reset scroll;
check chart inspection versus vertical scroll, large text, VoiceOver and both
themes. Confirm underlying SpriteKit/ACK scheduling while a native sheet covers
the board; no physical behavior is certified by portable projections.

Synthetic all-phase projection tests are not full end-to-end UI phase fixtures.
Apple compile remains a required integration gate; no CI/workflow was dispatched.
NEXT_ONE_TASK: VLP-CODEX-W1-003 — keyboard-safe bounded numeric input.
