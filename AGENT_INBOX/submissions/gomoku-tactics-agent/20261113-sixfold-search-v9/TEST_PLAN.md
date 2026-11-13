# Verification matrix

Local executed: Swift 6.2.1 Linux typecheck of extracted V9 forcing-search source against minimal faithful GomokuState stub PASS. Deterministic native-rule-shape probes: synthetic fork -> 52, opening no false proof -> nil, synthetic counterattack -> 101 PASS. This is NOT a full app or XCTest run.

New proposed XCTest: seven Gomoku cases/four Xiangqi cases and 2x/4x/6x time allocations; V9 exact-double-win certificate; bounded no-false-opening-win.

Required Governor gates: (1) patch apply against eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0; (2) Swift compile all targets and project.yml source inclusion check; (3) all GomokuBotTests and saved-match regression, (4) full native host XCTest/iOS UI including black/white seat swaps and iOS15/26 if supported, (5) test bench pair 5,000 valid games + tactical corpus, (6) iPhone13 and iPad physical CPU/thermal/power/offline acceptance, (7) opt-in JS JavaScriptCore deadline and CPU audit, (8) validate fallback after voluntary deadline and chooseMove nil only terminal/out-of-turn.

Additional property-based tests: every reported V9 proof must survive exhaustive defender reply replay for its claimed forced sequence; randomized rotations/reflections preserve equivalent proof outcomes; capped search returns unknown not pseudo-proof; immediate self-win, mandatory opponent block, counterfork and R8 invariants preserved.

No workflows or IPA were started. No 6x empirical chess-skill outcome is asserted.
