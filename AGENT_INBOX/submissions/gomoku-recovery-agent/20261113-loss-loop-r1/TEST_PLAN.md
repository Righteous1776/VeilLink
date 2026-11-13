# Verification plan
1. Apply PATCH.diff to exact base SHA, inspect modified paths, run Swift parser and required iOS CI.
2. Add FILES/GomokuLossReplayGateTests.swift to real VeilLinkTests target.
3. Replay 11-move evidence position: block external 83, allow 67 / 123. Verify actual native fallback remains legal and fork-safe.
4. Test own immediate win first, unique opponent immediate win block, and terminal/counterattack paths.
5. Run GomokuBotTests, AdaptiveBoardLearningTests, GomokuFormationLearningTests, NativeGomokuSelfPlayTests plus all host XCTest and UI smoke.
6. Verify device route with external V2 ON/OFF (iPhone, iPad), CPU latency, and held-out opening win rates.
7. Preserve player data: do NOT import either .vltrain as overwrite without backing up and designing a transactionally merged import.

Verified so far: 185 imported JSON game-records parsed; 70 fork-evidence replays PASS offline, 5 identical a83 mistakes PASS. Full iOS/simulator XCTest NOT_RUN; physical game NOT_RUN.
