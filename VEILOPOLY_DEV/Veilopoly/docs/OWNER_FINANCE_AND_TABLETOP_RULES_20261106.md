# Veilopoly · Owner photographed banking and tabletop rules (source-based transcription)

**Source A:** Owner's handwritten banking/finance sheet, photo IMG_6678.jpeg, 2026-11-06.  
**Source B:** Owner's printed “银行游戏棋规则说明书” photo IMG_6677.jpeg, 2026-11-06.

This is an engineering record in our own words, not a verbatim copy of the printed manual. The photographs are not committed to the repository. The original printed game's graphics, branding and rulebook prose are not to be redistributed.

## A. Handwritten financial expansion

| Topic | Legible source facts | Decision / implementation status |
|---|---|---|
| Bank loans | First borrowing 20%, second 30%, third 40%, fourth 45%; no owned land gives ceiling 500, one lot 1,000, two 4,000, three 7,000. Example: 1,000 at 20% for three periods gives principal 1,000 plus 200 per period = 1,600 total. | Loan quote and isolated simulated ledger implemented; maturity, overdue, and liquidation details not final |
| Bank deposits | Two columns labelled current/demand and fixed. Handwriting contains balance brackets, crossed-out figures and replacement amounts. A visible zero interest for demand amount 0–1,000. Some ranges have gaps/overlaps. | Do NOT hardcode disputed brackets as yields. Configurable deposit product implemented; actual yield/maturity fields remain pending |
| Managed bank product | Title indicates 1.5× and 5 periods. Six dice outcomes; early results include complete loss, smaller losses, break-even, and gains. | Abstract 5-period outcome product implemented, but payout table not active without approval |
| Venture simulation | Title indicates 2× and 4 periods. Six-outcome risk ladder: first two all-loss, then very large losses, then break-even and gains. | Abstract 4-period product implemented, payout pending |
| Stock-market simulation | Title indicates 2.5× and 3 periods. Six-outcome ladder: first three all-loss, two partial-loss results, last gain. | Abstract 3-period product implemented, payout pending |
| Gambling / high-multiple note | 7× / one period and several dice-hit annotations appear, but their exact penalty conditions are ambiguous. | **Not implemented as a wagering feature.** Only an optional no-stake, no-prize dice challenge is present; the historical note is recorded for completeness. |

### Items requiring Owner ruling, not automatic guessing

- D01: Verify full demand/fixed deposit balance brackets, interpretation of crossed-out values and what numerical interest means (flat ¥ vs percent); define time to pay interest, and whether withdrawal is allowed early.
- D02: Borrowed-land valuation: whether the 0/1/2/3-lot table is hard cap, and what 4+ holdings or mortgaged holdings count as; whether first 20% is per period. Decide repayment installments, overdue costs, collateral default and simultaneous borrowing.
- D03: For 1.5×/2×/2.5× products, whether the multiplier applies to principal, interest only, or only dice face 6; settle six explicit payout values with rounding, and whether roll happens once or more.
- D04: Are “periods” individual player turns or a full table round? Define if finance matures before or after Start/GO settlement.
- D05: Whether deposits, loans and simulation positions count toward endgame net worth and bankruptcy liquidation.

## B. Printed tabletop reference — mechanics, not copyrighted expression

- A four-player banker oversees paper-money supplies and purchases. Players move around a property board by dice and take actions upon landing.
- Start/GO: pass = +1,000; exactly stopping on the start square does **not** pay another 1,000. This conflicts with the current classic engine's +200 including exact arrival.
- Empty lots may be bought; owned properties collect rent according to structures. The pamphlet's house-to-hotel conversion happens after **two** houses, contrasting with classic Veilopoly's four-house conversion.
- Two named landmark classes (museum/oil field on the photographed reference) cost 2,000, charge based on property card, and do not receive houses. These names and art must be original in Veilopoly if adopted.
- Opportunity/fate cards create game events; cards return to the bottom after use. A star collectible pool contains **eight** tokens; various events/landing/tolls award them, and exhausting the pool can trigger hotel development for the most-awarded player(s). Exact tie-break mechanics need a decision.
- Mortgaged properties do not collect rent; price from mortgage is half of card price; only original owner can redeem. Bare-land resale needs consent; developed plots must remove improvements first.
- Winner by surviving opponents' insolvency, or by preset 60/90-minute horizon using cash at end. A deterministic match clock would require the host to inject period events into a replayable move stream; no `Date()` in Engine.
- Starter banknotes are defined as two of each color; the photographed page does not provide all face denominations. Classic Veilopoly starts at ¥1,500. No automatic replacement.

## C. Mode separation and current deliverable

`PrintedTabletopProfile` records identifiable numeric parameters without modifying current gameplay. `FinanceSandbox` implements deterministic, separately testable virtual-credit bookkeeping, four borrowing rate tiers, collateral caps, quoted repayments, configurable deposits, owner-supplied outcome tables, and a no-stake dice event. It is **NOT** yet integrated into `GameState` or the in-game SwiftUI panel; this protects existing state hashes, snapshot replay and Kimi's P4 visual lane.

**Next integration gate:** Owner approves D01–D05 and the classic-vs-printed mode switch. Then a versioned game-state extension, typed moves, AI, ViewCommands, UI and network replay tests can be introduced together in `dev/veilopoly`; P5 VeilLink product integration remains separately gated.