# ECON-V5: Financial Crisis Readiness Audit (2026-11-08)

Owner challenge: increasing nominal bank money is not a liquidity guarantee. V5 opening bank cash is 2,000,000 while four players hold 100,000: 20:1, but contingent deposits, stock exit proceeds, investment redemptions and prior claims still require bank coverage.

Implemented on independent risk review branch:
- Deterministic bank health report: bank cash, deposits plus yield, upper bound of investment payout, mark-to-market stock exits, bank queued claims, overdue/total loan exposures, safe lending capacity and stable/guarded/stressed/crisis risk status.
- V5 credit constrained by protected reserves (12% nominal base or contingent claims plus 5% buffer, capped at 80% money stock), aggregate new credit book up to 25% nominal currency, and freeze on queued claims or overdue loans. Experimental tuning, not real-world prudential banking.
- Matured savings, investment settlements and stock sales issue partial bank payments and FIFO bank claims if cash insufficient. V4/classic behavior unchanged. Claim redemption on new bank inflows uses existing reducer flow; V5 new salaries do not bypass earlier bank creditors.
- V5 stock-risk signal deducts an explicitly bounded liquidity-crisis penalty, and bank/asset UI shows risk and player-specific claims.
- Six XCTest regression sources included covering credit refusal, conservation, deposits, stock exits, claims and V4 compatibility.

NOT YET SAFE TO SHIP:
- Deep-crisis automatic debt liquidation and bankruptcy estate cash release are still on older logic. Their transactions may fail at the monetary-conservation gate in a bank run. Unresolved P0.
- No full order book/company balance sheet or stressed market-sale depth; synthetic stock marks are not actual bank assets. No reason to claim fully unified economic calibration.
- IOUs are liabilities, not spendable cash; no unlimited new currency and no promise of immediate settlement without inflows.
- Exactly scoped to new V5 offline match. P5 multiplayer still classic, no network-version negotiation.
- Full exact-head SwiftPM/XCTest, old saved-game fixtures, Apple SDK, simulator and physical phones NOT_RUN. Previous Codex test counts are historical evidence only.

Next task: run full exact-head SwiftPM; fix any compiler failures; stress 100+ seeds with empty treasury, high outstanding deposits, simultaneous loan maturities, forced bankruptcy and stock liquidation. Report natural completions vs capped games and pending-claim settlement times. Governor review required; no main merge, IPA or release.

Additional RISK-005/006: forced debt coverage must not liquidate inaccessible savings or stock exits when treasury is exhausted; it now skips that conversion and keeps the item intact, allowing the engine to enter the debt phase rather than conjuring cash that the central bank cannot reconcile. Bankrupt-estate disposition of assets remains a deliberate unresolved owner priority choice. Credit is also frozen when measured contingent liabilities exceed treasury, even if no queue is yet pending. Three additional regression source tests cover these cases; complete execution NOT_RUN.
