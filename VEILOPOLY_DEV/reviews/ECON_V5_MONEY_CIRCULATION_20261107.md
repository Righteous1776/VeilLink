# ECON-V5-001–003: expanded bank treasury and circulation

Branch: `dev/veilopoly-economy-v5-20261107`; exact parent dev/veilopoly commit `542f6379d2255e6d4a2a5e6a114bf2e402afa385`. The branch was created after another worker advanced dev/veilopoly twice. Parent and source branch intentionally left untouched. Owner explicitly prohibits packaging, main merge and IPA.

## Reason for the change
User feedback: V4's initial bank ¥160,000 and combined player cash ¥28,800 were both too small; a one-scale increase without changing assets would make the game trivial. V4 had a hardcoded global supply invariant, so changing one constant in place would break genuine V4 saved checkpoints and authoritative reducer hashes.

## New V5 experimental denomination
| Variable | Frozen V4 | V5 new solo match |
| --- | ---: | ---: |
| Finance rule version | 4 | 5 |
| Initial bank treasury | ¥160,000 | ¥2,000,000 |
| Per-player immediately spendable cash | ¥7,200 | ¥25,000 |
| Four-seat circulating player cash | ¥28,800 | ¥100,000 |
| Total fixed minted game currency | ¥188,800 | ¥2,100,000 |
| Starting GO salary | ¥1,100 | ¥3,200 |
| Initial property purchase / house costs | classic ×3 | classic ×12 |
| Base rent tiers | classic ×2 | classic ×8 |
| Early rent ceiling | ¥900 | ¥3,200 |
| Rent ceiling at 70 completed turns | ¥6,500 | ¥24,000 |
| Income / luxury tax | ¥600 / ¥300 | ¥2,200 / ¥1,100 |
| Bail | ¥150 | ¥600 |
| Four loan principal limits | ¥1,500/3,000/6,000/9,500 | ¥6,000/12,000/24,000/40,000 |
| One-off contract rate tiers | 8/11/14/17% | 6.5/8.5/11/14.5% |
| Simulated stock nominal quote multiplier | base ×8 | base ×24 |
| V4→V5 event cash / repair amounts | 1x | 4x, with matching printed ruling |

This is not a real-world banking simulation. The fixed global supply is an explicit board-game denomination and settlement ceiling. `bank.reserveCash` is the game's treasury available to pay player claims; `sum(players.cash)` is immediately circulating player cash. A bank deposit moves money from the player to the treasury and creates a contractual liability. A loan moves money from the treasury to the player and creates a debt claim; the simplified model does **not** implement fractional reserve money creation, external issuance, a real order book or market clearing.

## Economic architecture and compatibility
- `financeRuleVersion=5` selects new V5 values; `makeV4` retains the exact V4 opening denomination and terms. All V1–V3 saved games continue to preserve nil treasury and their historical rule versions.
- `supplyCeiling(forVersion:)` differentiates V4 exact 188,800 from V5 exact 2,100,000 for engine preflight, atomic post-move settlement, persistence admission and UI labels.
- Bank queued-claim records from the concurrent V4 hardening commit are preserved for both V4 and V5. Older V4 saves missing `queuedClaims` are accepted and an empty list materializes only when a bank payment is committed. No silent migration of old save bytes.
- Player→player transfers conserve the global money stock and do not issue bank currency; loans, stock purchases/sales, tax, salaries and cards settle against the same reserve.
- A bounded deterministic macro impulse uses player cash, actual buildings, outstanding loan principal and wealth concentration. Frozen V4 formula retained. No ambient time, external finance data or extra RNG streams.
- All V5 chance/fate blueprints copy V4 card IDs and domains, scale explicit cash/repair/free-house fallback amounts ×4 and rewrite text to EXACT printed sums. Duplicate jail card substitution is ¥1,000 under V5, remains ¥250 in V4.
- New solo only. Current VeilLink P5 linked room economy remains classic; V5 matchmaking and handshake NOT authorized. No protected host, Wire, identity, database or workflows touched.

## Tests, evidence, and blockers
- New `CityExpandedLiquidityTests.swift` test source covers versioned supply, loan, direct transfer, deposits/salary, card funding, price multiplier, old V4 no-claim snapshot and tampered total rejection.
- Old V4 tests are explicitly switched to `makeV4` rather than silently changing expected outcomes. A manufactured legacy V3 fixture now also nulls the optional claim list so its serialized ABI matches actual V3.
- Source-level work and exact GitHub commits verified; **full exact-head SwiftPM tests NOT_RUN**, strict Swift warnings gate NOT_RUN, Apple SDK/iOS and two physical devices NOT_RUN. No statement about 40–60-minute average games is made. Price/loan parameters are provisional until measured same-seed A/B, actual player minutes and early bankruptcy rates are collected.
- RISK: increasing the nominal money stock does not by itself establish a more efficient cash velocity or profitable business cycle; banking claims are stylized, not complete bank balance-sheet accounting. Real gameplay balancing remains OPEN.
- RISK: the direct V5 stock quote scale and new card price tables require exact-head SwiftPM/XCTest, iOS UI and replay/hash validation. No IPA or workflow requested.

Next one task: `VLP-ECON-V5-004` run exact-head SwiftPM tests and 12+ paired V4-versus-V5 seeded, bounded games; report natural completion vs truncation, cash/credit usage, first bankruptcy, card/stock sensitivity and old-save hashes; fix any test failure before proposing a reconciled dev/veilopoly merge. **Do not merge, build IPA, package or publish.**
