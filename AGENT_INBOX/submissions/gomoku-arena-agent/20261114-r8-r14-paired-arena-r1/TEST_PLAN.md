# Direct-native R8-compatible versus R14 test plan

## Local executed, NOT native engine games

- `swiftc -frontend -parse FILES/VeilLinkTests/GomokuR8R14PairedArenaTests.swift` — PASS (Swift 6.2.1)
- `swiftc -swift-version 6 -warnings-as-errors -typecheck -I <temporary VeilLink API stub module> FILES/VeilLinkTests/GomokuR8R14PairedArenaTests.swift` — PASS with interface stub. This is **not** actual product typecheck or XCTest execution.
- `cd FILES/Validation && python3 -m unittest -v test_audit_r8_r14.py` — 7/7 PASS on artificial legal fixture; fixtures are *not evidence of game strength*.

## Governor Apple CI test order (not run)

1. Pick and pin exact R14 integrated product head; verify complete frozen model is compiled and existing `GomokuBot` switches are present. Configure Xcode with project.yml. Observe license, legacy saves and protected interfaces.
2. Run product `GomokuR8R14PairedArenaTests.testOpeningPairsHaveLegalNonterminalDistinctPresets` and `testSameBoardDecisionsAreLegalAndDoNotMutateInput`.
3. For a short real smoke run: `VEILLINK_GOMOKU_ARENA_PAIRS=30 VEILLINK_GOMOKU_ARENA_MS=180 VEILLINK_GOMOKU_ARENA_SEED=937551941` with `xcodebuild test` targeting only `GomokuR8R14PairedArenaTests/testFullPairedArenaWhenEnabled`. Save logged `GOMOKU_R8_R14_ARENA_JSONL=...` path before runner cleanup.
4. Execute `python3 FILES/Validation/audit_r8_r14.py <raw-60-games.jsonl> --min-pairs 30 --output <replay-report.json>`; verify no invalids or incomplete games, both challenger and baseline actually played, color-swap symmetry, seed/pair IDs and routed engine use.
5. Freeze budget/opening seed before a larger tournament; run `VEILLINK_GOMOKU_ARENA_PAIRS=2500` at 180ms target, and independently sample a different seed/budget for replicability (such as 950ms master, if Apple device budget permits). Do not change test settings after viewing outcomes without labeling them exploratory.
6. Audit all completed full-game moves, paired score and 95% interval, node/candidate routing and actual mean/p95/max decision times. Compare separately to V29 release binary if a genuine standalone release-harness adapter is built; do not label `diagnosticEclipseUnified:false` as a different signed binary.
7. Xcode/XCTest, full iPhone/iPad energy/thermal, regressions in no-web mode, save/recovery and same-source hash gates remain prerequisites before main release.

## Rigor

Fifteen-by-fifteen freestyle Gomoku (>=5 unblocked continuous stones wins, no Renju restrictions), fixed seeds, 6-ply preopening; each opening played twice with candidate black and white. Incomplete and invalid matches fail the entire set. Opponent is the actual old search path in the same R14 kernel. Baseline versus candidate latency is a second outcome, not ignored. No future process or background job was started.
