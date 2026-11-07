# Regression gates
[x] 2 changed source files have unique anchors and exact-base patch application preflight.
[x] Added complete move journal, rule replay, and five unit tests.
[ ] macOS Xcode compile and XCTest NOT_RUN.
[ ] New store instance after kill: Gomoku 3 moves, current player .guest, sessionID same; Xiangqi two legal plies + checks.
[ ] Low disk/corrupt JSON: preserve file, show visible warning.
[ ] Restart clear only one game; learning archive remains separate.
[ ] UI: leave while AI thinking, re-open, exactly one AI move. Finish and re-open does not double-count learning.
[ ] Governor conflict resolution with PR #128 side selection before product promotion; no IPA/CI without gate.