# R2 validation
- Source originals: both payload checksums match when preserving iOS JSONEncoder numeric key sort and Date lexemes.
- Offline 5-fold CV: 202/212 oracle-safe ranker selections; historical 153/212. Exact board transpositions join opening groups before split.
- Verify no original user files changed. Offline model weights and histories remain outside GitHub.
- Verify PATCH.diff applies to EXACT main SHA (not executed in Apple CI yet).
- Run new proposed XCTest including h112 a96 h81 a82 h110 a98 h111 a113 h109 a108 h95 state: 83 unsafe; 67/123 safe.
- Run GomokuBotTests, AdaptiveBoardLearningTests, NativeGomokuSelfPlayTests, formation tests and full iOS host / UI XCTest.
- Verify external engine ON plus repeated loss prefix routes to native bot and does not claim PVS learned the player's history.
- Paired real-device battle tests with no opening overlap, varying sides and budgets; measure win-rate, blunder rate, latency, battery, memory.
- Explicit NOT_RUN: iOS XCTest, actual physical device, model running in VeilLink.
