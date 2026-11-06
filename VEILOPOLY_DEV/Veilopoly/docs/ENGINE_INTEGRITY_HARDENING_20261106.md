# Veilopoly P3/P4 · Rule & Snapshot Integrity Hardening

**Scope:** `dev/veilopoly:VEILOPOLY_DEV/Veilopoly/**` only. 2026-11-06.

## Why

Three invalid-state cases in the existing implementation affected the same deterministic engine used in local and authoritative-host multiplayer:

1. **Snapshot rollback:** `ReplicaClient.resync` accepted a validly encoded but older GameSnapshot. The client could silently lose already accepted moves and de-synchronize.
2. **Unbounded persisted banking fields:** `IntegratedBanking.validate` did not validate the `payoutBasisPoints` on saved positions, loan rates, maturity bounds or loan amounts. Corrupt/forged state could reach `Int` arithmetic with invalid values.
3. **No final-state integrity check:** `VeilopolyEngine.apply` validated the input but not all important *output* invariants. Large but valid monetary receipts could push a player's cash beyond the declared 1 billion cap; the transition returned success, leaving an unusable next state.

## Changes

- Replica snapshot sync requires the same session seed, a nondecreasing `nextSeq`, a contiguous in-state move log, an internally consistent `lastAppliedSeq`, and a matching deterministic state hash. Exposes clear `.staleSnapshot` / `.sessionMismatch` errors. Equal-sequence recovery remains possible to repair a local divergence **only after transport-host authentication at P5**.
- Banking ledger validation now bounds deposit interest, maturity, loan principal/interest/total due/term, stored record IDs, and position product categories, before operations calculate payouts.
- The transition reducer checks all player cash values, the entire bank ledger and the fixed bank house/hotel inventory after each move, *before* recording the move. Failure returns `.invalidState` and leaves the caller's original GameState and RNG untouched.

## Tests

- `SnapshotSafetyTests.swift`: 5 cases covering stale snapshots, wrong seed, corrupt seq/log, same-seq recovery, and normal host-to-client replay.
- `StateBoundarySafetyTests.swift`: 3 cases covering GO salary overflow atomic failure, malformed saving/loan values, and valid financial state acceptance.
- Local Swift 6.2.1/Linux `swift test --jobs 2`: **61/61 passing** on the local working tree that includes earlier parallel-engine changes. This is not an exact checkout of the GitHub branch, so **not an exact-HEAD CI claim**. Re-run the full suite on clean checkout in CI when available.
- Apple SDK / iOS 16 build, SpriteKit and SwiftUI touch/audio, actual transport integration and P5 authentication remain unverified.

## Hard boundaries

- No modifications to `main`, `Protocol 4`, `VLGM1`, SQLite Schema V8, the UI assets, the Kimi visual lane, signing, workflows or IPA.
- No game rule or economic payout table invented or altered. No gambling stakes or cashable rewards.
- Snapshot hash guards integrity only, **not authenticity**. P5 must authenticate the sender, gameId and existing secure VeilLink session before applying a snapshot.
