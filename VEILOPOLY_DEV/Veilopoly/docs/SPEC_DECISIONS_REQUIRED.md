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


## A14–A20: owner photo references (2026-11-06)

| ID | Owner-source ambiguity or clash | Interim engineering decision |
|---|---|---|
| A14 | Classic salary +200 (including exact GO) versus printed +1000 when passing GO, zero on exact stop | Add alternative printed-mode pure policy only; do NOT change GameState/Move |
| A15 | Printed hotel after 2 houses; classic 4-house rule with 32-house / 12-hotel bank | Separate policy only until mode and supply rules approved |
| A16 | Demand/fixed bank deposit table has edits, missing bands and unclear flat-value vs interest-percent interpretation | Configurable deposit accounts; default no yield/maturity, so action refuses with termsAwaitOwnerRuling |
| A17 | Loan tiers 20/30/40/45%, caps 500/1000/4000/7000; maturity/payment/late fees and >=4 collateral not defined | Implement four-tier safe sandbox quote, refuse unknown 4+ land case, don't write GameState |
| A18 | Managed / venture / stock products describe 5/4/3 periods and dice outcomes; exact positive payout multipliers and settlement sequence uncertain | Product slots and seeded outcome reducer exist, but active payout table requires approved injected policy |
| A19 | Printed star pool of 8 and possible multi-leader hotel prize; precise event triggers/tie adjudication not specified | 8-token pure collect/reset ledger and tied leader reporting only, no hotel board mutation |
| A20 | 60/90-minute printed end condition requires real time; Engine forbids Date() or ambient clock | Separate pure calculation accepts owner/host-injected elapsed-minute input, never uses Date() |

No rulebook text or printed game's proprietary illustrations/branding are copied into source. The user-provided rule examples are paraphrased and kept distinct from unconfirmed engineering proposals.
