# VLP-CODEX-W2-001 — reject malformed purchase/auction references

Before: 72521c9c3828f13b075fac6df536df00ea8fbc1b; dev/veilopoly only.
Main rechecked unchanged: 2c5b5161027edff097b27fe3323d30f6ca3e430e.
Severity-driven W2 slice under #168: possible crash takes priority over remaining
HUD polish. Not a declaration that W1 Apple/device gates are complete.

## Red → fix → green

1. Add malformed-purchase regression without production changes; run only
   `PendingPurchaseSafetyTests.testMalformedPendingPurchaseReturnsFailureInsteadOfCrashing`
   with core dumps disabled → exit 1, `Fatal error: Index out of range`,
   unexpected signal 4 → FAIL, reproducible baseline crash (Linux).
2. Run baseline auction-start and two persistence regressions separately
   → 3 cases / 18 assertion failures → FAIL. Invalid auction start was accepted;
   malformed purchase state could replace a checkpoint, and even a correctly
   checksummed malformed newest record was selected over an older valid slot.
3. Engine buy/startAuction now check the existing isTile bounds helper before
   indexing or propagating the reference. Bid also rejects an already-malformed
   auction tile before settlement, returning invalidTile without partial state.
4. Persistence plausibility checks both optional deed references before save or
   accepting a loaded slot. Failed save preserves prior valid state; malformed
   newest slot falls back through existing A/B logic. Both invalid slots retain
   existing corrupt-checkpoint/explicit quarantine behavior. No silent deletion.
5. Targeted `swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2 --filter
   'PendingPurchaseSafetyTests|VeilopolySaveStoreTests|BuyPropertyTests|StartAuctionTests|BidTests'`
   → 20 cases / 0 failures → PASS. Includes 4 new Engine and 2 new persistence
   cases: negative/40/Int.min/Int.max references, pending and existing auctions,
   unchanged rejected state, valid purchase/auction replay and RNG counter,
   old sealed save compatibility, and checksum-valid malformed-slot fallback.

Full suite: `swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2`
→ 255 cases / 0 failures, 30.365s → PASS (Linux Swift 6.2.1).
Same existing AI corpora before/after: 0/500 short completions (500 capped),
9/20 long completions (11 capped), 79,661 long moves, zero illegal actions.
Timings and limitations in CHECKPOINT; no AI policy/strength/speed claim.
No valid-state rules, prices, rent, RNG consumption, Move/schema/checksum layout,
SQLite, host, real transport, resources or release settings change. Checkpoint
schema stays 1; this strengthens semantic validation, not serialization.

Limitations: this is NOT a complete malformed-state validator or network security
review; other participant/phase/card references still need systematic auditing.
FNV checksum is not authentication. Existing P3 and saved-state checks are not
real-peer or power-loss certification. Apple SDK/device tests NOT_RUN.
Strict warnings gate remains the historical Codable failure; no suppression.

NEXT_ONE_TASK: VLP-CODEX-W2-002 — remaining auction/trade/debt participant-index
and phase-payload safety, with reproducible regressions before each narrow fix.
