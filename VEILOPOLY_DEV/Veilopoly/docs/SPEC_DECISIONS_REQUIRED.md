# Specification rulings required · 未经裁决不得将演示规则当作正式版

The three design files have been read in full. The following specification gaps are **not** silently treated as signed-off product rules.

| ID | Ambiguity / conflict | Provisional code behavior | Recommended ruling |
|---|---|---|---|
| A01 | 40-cell street table lists only indices; apart from tile 1, no prices, rents, localization or building costs | Uses canonical-style U.S. board numbers in `GameFactory.board()` and Chinese labels | Approve a frozen machine-readable 40-tile JSON as formal source |
| A02 | Chance/Chest described by examples, not the exact complete 16+16 cards or deck reinsert mechanics | `SampleCards.all` provides **clearly marked provisional** 16+16 data-driven cards; jail card can recur | Approve exact card IDs, texts, effects and get-out-of-jail removal/reinsert rules |
| A03 | GO: passed +200; exact GO +400 optional | +200 only, including exact landing | Keep +400 as explicit optional game configuration, default off |
| A04 | Free Parking pooled fines optional; fast bankruptcy mode optional | Both off | Confirm default-off and required UI controls |
| A05 | Auction min increment, bidding order after refusal, maximum turn duration/timeouts not fully specified | Any integer strictly above current bid (first ≥1), circular active turn; all-pass returns to bank; no timer | Define host-authoritative integer turn clock or non-time-based bidding for low-connectivity sessions |
| A06 | Can owners sell/buy property improvements as part of trade? Mortgage interest on receipt? | Trades forbid properties in improved color sets; mortgage flag simply transfers with land, no automatic fee | Define full acquisition liability, restrictions, and balancing rules |
| A07 | Automatic liquidation order vs mortgage prohibition on improved color sets; negotiations and voluntary bankruptcy | Mortgage all legally unimproved tiles, sell buildings evenly, then mortgage newly clear tiles; remaining debt requests `declareBankruptcy`; no trade negotiation step | Owner should specify deterministic liquidation order and whether trade window intervenes before bankruptcy |
| A08 | Last jailed turn doubles / forced bail / insufficient funds exact sequencing | Third non-double roll pays ¥50 before moving; unpaid bail triggers debt; released-on-double does not get extra roll | Approve standard ordering; add explicit test fixtures for bail debt |
| A09 | Cross-OS JSON canonicalization, hash algorithm and snapshot trust not specified | Sorted-key JSON + FNV-1a 64; snapshot hash is **not cryptographic authentication** | Agree on stable cross-platform test vectors; P5 authenticate gameId, sender and messages via existing E2EE session |
| A10 | 15 move rows enumerate 18 distinct variants (trade counter/accept/reject and jail bail/card) | 18 case kinds, individual tests for all | Confirm 15 groups / 18 wire `type` strings |
| A11 | UI spec says “rendering does not callback logic” but animation must ACK before phase advance | Rendering ACK goes to the session coordinator; coordinator invokes pure engine after last ViewCommand | Confirm coordinator ACK interface as the binding contract |
| A12 | Owner monthly decision: “no new features” vs active game implementation | Independent package only, uncommitted; INBOX staging included | Authorize product integration after the baseline freeze/P5 launch governance |
| A13 | Hardware budgets and 25–45min average game time require real measurements | No wall-clock claim and no 60fps claim | Set target telemetry protocol + seed corpus + human game playtest plan |

None of these rulings should be inferred from green Linux unit tests.
