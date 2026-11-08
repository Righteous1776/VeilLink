# ECON-014..017: Bank IOU / compulsory-payout solvency safeguard

This is a scope-limited new SOLO V4 economic behavior. It does not alter V1–V3 bank policy, P5 linked rooms, transport, Wire, schema migration outside the Veilopoly bank ledger, identity, signing, workflows, main, or packaging.

## Rules
- V4 bank holds finite cash; its initial reserve is 160,000 and combined player+bank currency is exactly 188,800.
- When V4 treasury cannot cover a **mandatory** starting-tile salary or positive bank-funded Chance/Fate event (including jail-card duplicate, no-lot free-house alternative), the rule pays as much REAL bank cash as exists and records the remainder as a noncash bank claim. Such receivables do not count as circulating money or immediately spendable cash.
- FIFO settlement occurs after **every** committed move whenever funds return from player spending, taxation, purchases, stock orders, loan repayments, etc. First claim can be partially paid; partial amount remains in front of queue. Payment always comes from actual bank balance, never minting.
- Discretionary bank loans, contractual withdrawals, investment settlement, or stock sell transactions may still fail if the treasury lacks cash; no silent contract rewrite or phantom stock proceeds.
- A claimant who becomes bankrupt has an unsettled claim cancelled when it reaches the head of the FIFO queue (estate prioritization policy **requires separate Owner validation**). At most 4,096 claims per game; this safety quota is an explicit operational limit, not a finance reward ceiling.
- Existing old games retain exact previous salary, event and card behavior; nil optional `reserveCash` and `queuedClaims` omitted from old JSON. Intermediate preclaim V4 development snapshots decode to an empty queue.
- UI bank panel displays available cash, total supply, outstanding claims and player-specific unpaid claims. UI asset browser shows outstanding amount.

## Evidence
Engine test sources cover mandatory GO with only ¥100 bank cash, issuance of ¥1,000 claim, later ¥600 tax transfer + FIFO partial settlement, free-house fallback with zero bank cash, unchanged total supply and deterministic Codable round trip. Existing UnifiedCityEconomyTests include property/tax/loan/stocks/direct transfer conservation; V3 test now sets queuedClaims=nil and checks old JSON ABI. No full current-head SwiftPM, Apple SDK or iPhone test was executed in this connector environment. All are NOT_RUN, not falsely passed.

## Remaining high-priority checks
- Run exact-head full SwiftPM regression and repair compile/test failures before more expansion. Run 12-50 seeded long games; separate complete games from capped; check cash conservation on every accepted move and whether claims accumulate in late-game.
- Evaluate bankrupt claim treatment and mandatory card text/partial payout disclosure in real UI; ensure old snapshots/fixtures remain unchanged.
- Assess debt priority, bank solvency and how cash settlements affect financial stock signals without making new games impossible to finish.
- iOS landscape, VoiceOver, iOS SDK, and real two-phone P5 tests NOT_RUN. Do not migrate V4 to P5 without versioned room negotiation. NO IPA or main merge.
