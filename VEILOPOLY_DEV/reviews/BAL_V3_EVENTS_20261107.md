# Veilopoly BAL-001–004 · Opportunity / Chance / Fate / Economy cross-balancing

Baseline `dev/veilopoly@fdf7920`. Owner reported a ~20-minute match, premature bankruptcy and weak strategic cashflow; requested **balance across chance, fate, opportunity, lending, stock and the whole board**. This is a new-game experimental fix, not a measured claim of a target match duration.

## Findings (code-derived, not hypothetical)
- Classic `SampleCards.all` has 16 Chance + 16 Fate cards; there is no third `DeckKind` for 机遇. Three Chance tiles and three Fate tiles exist on the 40-cell board.
- Pre-change V3 multiplied EVERY sample cash card by 3 at runtime while its displayed card text/editorial still said original values. That was a concrete player-visible rules mismatch.
- Fixed repeated sample deck order also repeated every cycle; zero-cost jail card could accumulate indefinitely. Nearest rail/utility Chance cards in the sample charged 2x special rent; hotel rent could create severe early losses.

## Applied BAL-001–004 (V3 SOLO only)
1. **32 original themed cards** in a separate canonical pool: 16 chance / 16 fate. Opportunity/机遇 is a **category of the Chance deck**, not a third on-wire deck. Exact card title, story, ruling and effects are authored together. The existing legacy SampleCards 32 remain untouched; modified card effects fail editorial matching to prevent misleading UI.
2. Card cash now equals its printed amount instead of hidden 3x. Fixed monetary Chance bank transfers per full 16-card cycle sum **+1000** (3 positive, 2 negative), Fate sum **+2210** (7 positive, 4 negative), *excluding* peer-to-peer transfers, GO, rent, repairs and special movement. These numbers are design parameters, not actual expected profits per match. Maximum single direct bank fine ¥500; positive bonus <=¥800. There are 2 jail cards, 2 direct-jail cards and bounded repair cards.
3. Card duplicates: new V3 player may retain at most one same-deck jail card; a repeat gives exactly ¥250 and is visibly disclosed. Old games unchanged.
4. Deterministic per-deck reshuffle **only after full draw cycle**, using game-seed/domain/cycle salt; main dice and stock RNG streams untouched; order and cursor are saved and replayed.
5. Graduated rent: City V3 **per-landing charge** is capped at ¥900 initially, +¥80 each completed ordinary turn, max ¥6500. Railroad and utility base rents are first scaled 3x for the higher City property prices; street nominal rent already 2x. Old games have NO cap or multiplier changes. UI asset browser reveals current rent ceiling, avoiding a hidden rule.
6. AI City V3 liquidity buffer: minimum ¥1200, scales with half rent ceiling, capped ¥2400, combined with existing loan-due reserve; it cannot increase unboundedly and freeze buying. Old AI reserve unchanged.

## Regression coverage supplied as source
- CityLongCardBalanceTests: 32 exact cards & unique IDs, zero hidden cash multiplier, chance/fate monetary sum, player-transfer conservation, duplicate jail-card behavior, deterministic deck reshuffle, rent cap, classic/V3 JSON roundtrip and custom text safety.
- CityLongRentalPhaseTests: actual engine landing with hotel charges capped early and full late, no accidental debt in early protected case.
- CityLongLiquidityPolicyTests: poor AI declines risky purchase, solvent late AI can purchase, classic policy remains.
- Earlier CityLongEconomyTests adjusted for exact card denomination.

## Important validation distinction
- Inspected real GitHub source. Static parse of V3 card file confirms **32 IDs (0..31), 16+16, 7 opportunity-themed chance entries, exactly 2 direct-jail and 2 get-out-of-jail events, Chance direct-bank sum +1000, Fate +2210**.
- Exact-head SwiftPM engine/AI/UI package tests, iOS Apple SDK compile, simulator, actual iPhones and paired Bluetooth: **NOT_RUN**. Regressions are committed **test source**, not yet passed tests.
- No Apple packaging, signing, IPA, workflow dispatch, release or main merge. No modification of actual P5 two-device rooms (still canonical classic economy), protected transport, Wire, identity, SQLite or game-save schema.

## Still required
Run full exact-HEAD Swift 6.2.1 tests and 12+ paired seed A/B benchmark; report natural completes vs caps, first bankruptcy in ordinary turns, cash injection, probability of loss from cards, loan use, stock trades and current P5 compatibility. Fix failures and retune only from evidence. Then run Mac Apple SDK and actual device gates. Never convert move-count to minutes without human session data.
