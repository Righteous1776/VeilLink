# D2 Tests
- [x] Inspected main@ccafebab147e069fbabfff579dbf323b0d54f191 for the permission default, `AppModel.executeAgentSuggestedGameMove` current-state validation, and sheet disabled policy.
- [x] Source anchors uniquely matched and patch built for exactly 2 product/test files.
- [ ] Apple SDK compile / XCTest: NOT_RUN here.
- [ ] Test defaults off, opt-in persistence, reset to off.
- [ ] Real iPhone: sheet shows toggle; with toggle OFF, execute is visibly disabled and analysis still works.
- [ ] Toggle ON and wait for current local-turn Gomoku legal recommendation, then execute; verify the authenticated game message and UI state move; ensure bot suggestion is not applied autonomously.
- [ ] Opponent's turn / stale state / link absent: button disabled or AppModel refuses; no unexpected packets.
- [ ] On supported iOS compact-device profile, the bot may defer recommendations entirely, so explain that missing feature rather than suggesting execution is always available.
- [ ] UI accessibility and multi-device game test; check with existing PR #130 game link recovery before integration.
