# D2 validation plan

## Done: source/patch-level
- [x] Verified from main@ccafebab147e069fbabfff579dbf323b0d54f191: default opt-in flag false, AppModel send guard, 25-s suggestion expiry, supported native game adapters.
- [x] All source replacement anchors unique and patches generated with non-overlapping unified hunks.
- [x] Keeps native legal-action + authenticated-session validation untouched; no wire protocol/schema changes.
- [x] Only the 5 Inbox proposal text files committed.

## NOT_RUN: Xcode, XCTest, simulator, two iOS devices
1. Apply on Governor integration branch; `git apply --check` and compile full target.
2. Existing `AgentControlAndLocalGameTests` verifies default off, explicit local opt-in persists, reset to off.
3. Existing `AgentGameExecutionValidationTests` confirms wrong turn/session/stale/occupied candidate rejection.
4. On paired phones, active Gomoku/Xiangqi/Ludo: open assistant; see OFF and disabled execute; enable; click refresh; when recommendation appears click execute; verify one encrypted game packet and correct board.
5. Wait >25 sec: execute disabled; refresh makes current valid recommendation available again; stale board state must fail closed.
6. Non-local turn and game ended: no executable candidate; safe UX.
7. Tactical/2D game: read-only label; no executable button; language cannot inject moves.
8. Long conversation: profile synchronous `database.fetchMessages` under explicit refresh; if stalls, refactor the read to a controlled worker before production.
