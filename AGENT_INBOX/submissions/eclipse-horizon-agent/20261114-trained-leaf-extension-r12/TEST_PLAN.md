# ECLIPSE R12 verification

## Executed
- Linux Swift 6.2.1 `swiftc -O -swift-version 6 -warnings-as-errors` for `FILES/EclipseHorizonQuiescenceR12.swift` + `FILES/TESTS/main.swift`: **1,607/1,607 assertions PASS**, including 500 random valid in-range boards checked against independent contiguous-five brute evaluator, 32 D4 symmetry checks, directed defensive and attacking patterns, 3 identifiable frozen Codex evaluation positions.
- Read-only audit of Codex PR #209, 10 publicly staged evaluation files: **920 games, 28,737 postpreset decisions, zero index/actor/occupied replay inconsistencies**. Counts in `EVIDENCE/ARENA_920_LEAF_AUDIT.json`.
- **192/192** selectively sampled existing Codex game positions verified against a second independent brute-line classifier (48 per tactical label, not independent games).
- Patch structure: 3 sections (1 Codex kernel diff + 2 added product files), 2/2 existing source overlay preimage hunks EXACTLY matched `FILES/Native/VeilGomokuUnifiedSearch.swift` at commit `d93e579a1b01e66be77b8e2d45cf2c60cd58b1df` (NOT current main).
- Isolated helper microbench: 1,000 synthetic 30-stone positions; Swift6 -O Linux median 6.2µs, p95 6.58µs per classifier call. **Not** full PVS overhead or mobile result.
- Frozen model file left intact: `EclipseTrainedOrdering.swift` SHA256 `f89f234f...`; optional horizon code changes search semantics, not learned weights.

## HOLD (not executed)
- Compile full product from exact combined Codex trained source + R12 under actual iOS Xcode / Swift6 target. Audit all changes versus golden model Swift parity suite.
- Re-run 9,024 model feature-score parity + 82 tactics + 50 frozen baseline identity tests (with horizon OFF) and real Xcode XCTest.
- Re-run 500+ paired full complete matches R12 enabled vs R12 disabled using matched new opening seeds, opponent colors, **equal time and node budgets**. Report depth distribution, outcome confidence intervals, wall elapsed, p95, node spending, power/thermals; do not train on evaluation games.
- Verify R9 ECLIPSE true telemetry and no candidate/PV during live games; on undo/new game invalidate search session.
- Stress forcing-block chains, last move/terminal, node-deadline expiration and forced proof correctness; ensure incomplete iteration discarded.
- Explicit [INTEGRATION-GOVERNOR] review before main/IPA/release.
