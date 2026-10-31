# Validation required before acceptance

1. Governor applies advisory PATCH.diff only on isolated integration branch after reviewing overlap with #110 and latest main.
2. Verify XcodeGen source inclusion (existing files only). Execute `xcodebuild` simulator CI, all GomokuBotTests, AdaptiveBoardLearningTests, App boot/UI smoke, Release iphoneos unsigned compile.
3. Run new `testForcedGapBlockPrecedesLearningAndRootRank` (gap 110), `testImmediateWinningFiveRemainsFirstPriority` (guest four with both winning ends). Add further edge/corner/double-threat tests, including multi-ply attacks and 15x15 symmetry D4.
4. Test no regressions with fresh/empty cache and heavily biased stored learning; ensure forced blocks outrank 1,200 point root adjustments.
5. Confirm repeatable offline results using the supplied source hashes and independent seeds; parent-game split for any later neural training; no leakage across D4 transformations.
6. Require ≥5,000 color-swapped **native Swift** arena games against exact Build63 as regression baseline plus ≥1,000 adversarial Bagua examples against a different engine; report p-values/CIs and draw/timeout policy. Promote only with tactical regressions zero and statistically credible non-regression/improvement.
7. Profile iPhone 7 if supported and iPhone13 iOS26: 99p latency, app memory ceiling, battery and 15x15 on-device resource use.
8. CoreML/NNUE only if weights independently licensed/validated and explicitly authorized by Governor; keep rollback/toggle, ensure no main/IPA release in current lane.
