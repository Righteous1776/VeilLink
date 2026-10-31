# Test plan — S1 executed and S2 gates

## Executed

- PR #114 source head, source-file hashes and bundled seed SHA-256 checked: PASS.
- Existing 2,000 bundled records independently replayed: 2,000 complete, 0 invalid, FNV1a64 matched: PASS.
- Swift 6.2.1 Docker compilation of the unmodified target `GomokuBot.swift` plus target formation source and Foundation-only shell: PASS.
- S0 smoke: 10 complete native games / 430 Bot decisions / 0 invalid: PASS.
- S1: 1,000 complete native games / 51,292 Bot decisions / 0 invalid: PASS.
- Independent Python replay of every S1 move, terminal result and game checksum: PASS.
- 225-opening / 36-formation-pair coverage contract: PASS.
- 200 colour-swapped opening blocks (400 games), both sides independently replayed: PASS.
- Non-degradation promotion gate for Bagua: **FAIL / correctly not promoted**; score 49.75%, Wilson lower bound 44.88%.

## S2 / S3 required gates

1. Run 10,000 and 50,000-game append-only shards with a manifest per shard and rerun the independent auditor before each count is accepted.
2. Hold out full opening families and all their rotations/mirrors from paired evaluation.
3. Run 1,000 then 5,000 colour-swapped blocks against unchanged native formation-off; report score and confidence interval.
4. Reject a candidate on any illegal game, forced-win/forced-block regression, duplicate-resume count, or lower CI bound at or below 50%.
5. Run product XcodeGen, iOS Simulator XCTest and physical iOS testing before any App import or default-policy change.
