# ECONOMY V3 — City Long · design and verification receipt (2026-11-07)

## Owner observations
A personal game reportedly ended within ~20 minutes, bankruptcy was too common, money/earning and spending felt too small. This is one human observation; no actual turn-by-turn telemetry or average has been measured. Owner requests more substantial stock, lending, cash flow and a longer, less punitive match.

## Changes: newly created SOLO matches only
The classic GameFactory.make and legacy saved solo matches remain unchanged. New GameSessionModel games and explicit resets use VeilopolyCityLongEconomy.make. P5 rooms STILL start the legacy canonical economy; do not misrepresent multiplayer as migrated.

| Mechanic | Legacy baseline | City-long V3 experimental |
| --- | ---: | ---: |
| Player starting cash | 1500 | 7200 |
| Passing starting tile | 200 | 1100 |
| Land/house price | x1 | x3 |
| Rent | x1 | x2 |
| Taxes | 200/100 | 600/300 |
| Bail | 50 | 150 |
| Card cash & repairs | x1 | x3 |
| Loan interest | 20–45% per period | 8–17% ONCE per contract |
| Loan caps for owned lots 0/1/2/3+ | 500/1000/4000/7000 (4+ blocked) | 1500/3000/6000/9500 |
| Demand deposit | immediate withdrawal, 0 yield | 1.5% once after one ordinary bank period |
| Fixed deposit | unavailable without injected terms | 8.5% once after 4 periods |
| Managed/venture/virtual-index contracts | withheld pending payout rule | seeded, finite, loss-capable payout tables, 5/4/3 periods |
| Stock V2/V3 | 5 fictional quotes, original 0.5% fee | 8x quote prices, 1.5x volatility and movement, 0.25% fee, min1 |
| AI cash reserves | 1x profile | 3x profile |

V3 persists with existing integrated bank financeRuleVersion=3 and stock market algorithmVersion=3, not with new fields in GameState. Historical V1/V2 bank, V1/V2 market and existing save JSON/Move schema are not automatically rewritten. V3 payouts are virtual in-game simulation, not real money or wagering.

## Evidence
Added CityLongEconomyTests source: starting state, legacy isolation, passing-start cash, taxes, deposit anti-arbitrage, loan quote and >=4 lot treatment, stock quote/fees/tape determinism, GameState Codable round-trip. Apple SDK/Simulator/phones and exact-head whole-package SwiftPM: NOT_RUN (connector-only repository). Prior 271 passing Linux tests refer to a previous HEAD. No claim that v3 achieves a 45+ minute play time until comparative seed and real-player telemetry are measured.

## Required next acceptance
1. Execute exact-head SwiftPM build and XCTest (no IPA), correct any failed cases.
2. Run paired legacy versus V3 AI seeded corpus: completed game %, first bankruptcy timing, completed-turn count, per-player cash flow, loan delinquency, number of loan/stock actions, max wealth share. Measure actual player minutes separately.
3. Verify fixed/deposit/invest bank UI on iPhone landscape and compatibility with existing solo saves and P5 legacy rooms.
4. Add **explicit versioned room configuration** and peer compatibility checks before enabling V3 in multiplayer. NO silent room economy divergence.
5. Review further balance tuning based on evidence rather than hardcoded completion-time promises.

No main merge, signing, workflows, version/release/IPA activity.
