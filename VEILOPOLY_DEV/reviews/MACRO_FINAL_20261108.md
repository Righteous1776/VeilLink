# VLP-MACRO-FINAL-20261108 — Veilopoly Economic Integration Review

## Scope
Reviewed source baseline `dev/veilopoly-risk-review-v5-20261108`, derived from `dev/veilopoly-economy-v5-20261107@24aaa700`. No PR/main merge, workflow dispatch, signing, IPA build or release. Only `VEILOPOLY_DEV/**`. Core goal: protect the **game**, not imitate a regulated real-money banking system. Currency cannot be purchased, cashed out or traded for real-world stakes.

## Money, banking, property, equity and human-player settlement
| Subsystem | Mechanics in V5 / risk lane | Acceptance |
| --- | --- | --- |
| Monetary base | Bank initial 2,000,000 + four seats x25,000 = fixed 2,100,000. Every reducer move reconciles net player liquid credits vs bank reserve; no silent money mint. | SOURCE REVIEWED; exact-head SwiftPM NOT_RUN |
| Bank liabilities | Claims/IOUs, unlocked/fixed savings principal+yield, investment maximum payouts, stock mark-to-market sell exposure reported separately from spendable reserve. | IMPLEMENTED risk report; scenario tests committed but NOT_RUN |
| Credit | Loan brackets and collateral caps V5 scaled; protected reserve >=12% base or covered claims plus buffer, aggregate loan principal budget 25% monetary base; credit frozen with uncovered liabilities, queue or overdue loan. | SOURCE IMPLEMENTED; real risk calibration pending |
| Stock | Shares/ticks remain synthetic. Sector/stock variation, limits and per-trade fees; cash and asset concentration feed macro pressure; V5 stress applies negative pressure. Stock exits can create **unpaid bank claims**, not cash. | PARTIAL, no exchange depth/order book, NOT calibrated |
| Properties | Costs/buildings scale with denomination; bank holds physical house/hotel inventory; free-house card respects building legality; progressive rent ceiling prevents early single-rent elimination. | SOURCE IMPLEMENTED; human play-time NOT measured |
| Player deals | Instant targeted credit transfer (not bank issuance), bilateral traded assets require acceptance; no invisible third-party transfer. | SOURCE IMPLEMENTED; iOS UX device NOT_RUN |
| Card events | V5 chance/fate event cash values match text, with large free-house prizes and fair fallback. | SOURCE IMPLEMENTED; scenario tests pending |
| Bank run/queue | V5 savings withdrawals, simulated-investment maturity and stock sales settle from actual bank credits first. Unpaid balance becomes FIFO claim; subsequent taxable/purchase inflows redeem claims. | SOURCE IMPLEMENTED; tests NOT_RUN |
| Forced debt | Savings and stock auto-sale cannot use unavailable bank money. Keeps unavailable positions intact and proceeds to explicit debt management/bankruptcy. | SOURCE IMPLEMENTED; tests NOT_RUN |
| Bankruptcy estate | V5 uses **noncash succession**: valid player creditor inherits deposits, investments, queued claims and shares; 100,000-share receiving-seat limit converts overflow to a quoted bank claim. Bank as creditor extinguishes debtor claims and seizes/cancels assets; outstanding borrower loans written off. V1–V4 legacy path unchanged. | SOURCE IMPLEMENTED; tests NOT_RUN. Estate queue-cap edge case remains |
| Replay/version | V3/V4 rules frozen for old saves; V5 new offline solo matches only; seed/RNG pure calculations, no ambient clock. | SOURCE REVIEWED; older-save fixtures and full CI NOT_RUN |
| P5 multiplayer | Still uses legacy room financial configuration. V5 is **not** negotiated or supported for two-device live-room play yet. | NOT IMPLEMENTED in V5; do not silently expose |
 
## Financial crises: exact meaning
V5 is intentionally a **finite nonconvertible game credit system**:
- The nominal money stock is fixed, but unredeemed claims and stock prices are **assets/liabilities**, not additional liquid currency.
- Liquidity shortfall can coexist with solvent-seeming net worth; a crisis restricts **new risky loans**, not all gameplay actions.
- A player owed cash may receive a bank claim and wait for inflows. A claim is not cash; no guarantee of instant settlement.
- A bank in a systemic panic is NOT an automatic trigger to bankrupt all players. Individual bankruptcy remains triggered by individual game debt procedures.
- Never describe this as a real banking model, actual stock exchange or economic crisis-proof engine.

## Remaining P0/P1 gates
P0: exact-head Swift 6.2.1 full package build/XCTest **NOT_RUN** (connector-only source editing); Apple SDK compile, simulator, iPhone touch, multi-device network also **NOT_RUN**.
P0: run and repair all new source regressions: monetary conservation per move, deposit/stock IOU FIFO, collateral loan timing, double-counting, interest receipts, estate succession and forced liquidation with no bank reserve; check old V3/V4 save snapshots.
P1: Stress test 100+ deterministic seeds and high-liability scenario matrix. Report naturally finished vs capped runs, median first bankruptcy in ordinary turns, player liquidity, bank reserves, claim repayment periods, portfolio exposure, rent-to-cash ratio and credit-default share. Do not conflate turn count with human wall-clock minutes.
P1: Governor integration review for three divergent branches `dev/veilopoly`, `dev/veilopoly-economy-v5-20261107`, `dev/veilopoly-risk-review-v5-20261108`. No automatic merge. Check changed paths are `VEILOPOLY_DEV/**`; do not pull bank-only patches into host app.
P1: Queue cap when multiple maximum-size estates converge can currently reject a bankruptcy if the claim queue is at 4096; if reproducing, devise bounded claim aggregation or explicit insolvency receivership rather than dropping claims or minting cash.
P2: Stock market currently has simulated, seeded quotation but no enterprise balance sheets, true order matching, depth, counterparty restrictions or correlated risk model. Such a feature is future development, not part of final macro acceptance.

## Evidence classification
- Confirmed by GitHub source: implemented functions and committed regression source, currency constants, all changes confined to allowed branch path.
- NOT confirmed: that `swift test` passes, that a human match lasts longer than 20 minutes, that none of the stress seeds freeze, that iOS builds or two-device communication work.
- Product status: **unreleased experimental economic engine**, independent review lane; keep main and IPA untouched.


## MACRO-005 balance instrumentation (SOURCE, not measured outcomes)
- `EconomyAutoplayEvidence` now includes bank reserve, unresolved and peak bank claims, loan principal outstanding, stressed-move count and crisis-move count. The measurements derive from the **real game reducer state**, not simulated offline approximations or elapsed wall time.
- `MacroFinalSeedStressTests.swift` exercises 100 independent V5 seeded AI games (max 1,200 engine actions each) and checks monetary-base conservation on every final state, natural completion vs capped runs, first bankruptcy, median completed turns, max claims and crisis duration. First three seeds have exact deterministic replay checks.
- `testOneHundredDeterministicV5SeedsReportBankLiquidityAndEarlyBankruptcy` is potentially expensive and **NOT_RUN**; its existence is not evidence that 100 games passed or that play duration improved.
- Avoid interpreting capped tests as natural completions or engine actions as human minutes. If V5 AI stalls during debt, report the specific failure rather than suppressing the result.
