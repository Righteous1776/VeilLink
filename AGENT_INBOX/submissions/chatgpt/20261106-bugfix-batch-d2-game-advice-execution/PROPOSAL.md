# D2 — 灵核合法建议执行的可见权限与最新棋局刷新

## Verified root causes
1. `AgentControlCenterSettings` deliberately defaults `allowSuggestedGameMoveExecution=false`, and AppModel rejects execution unless enabled.
2. The game sheet shows “执行建议” without explaining the authorization control and only disables on missing suggestion. Clicking can produce “禁止执行建议” even though a recommendation exists.
3. Suggestions age out after 25 seconds; the UI offers no direct latest-history refresh.
4. Native executable recommendations exist only for Gomoku, Xiangqi and Ludo; Tactical and the 2D mini games are high-level/read-only. Language-model prose must not be treated as a legal executable move.

## Proposed minimal repair
- Observe `model.agentControls` in the game sheet and add an **explicit OFF-by-default opt-in Toggle** for manual native legal move execution, reused from the existing Settings API. Never auto-enable or bypass `AppModel` gate.
- Disable “执行建议” unless permission enabled and a fresh native suggestion exists.
- Add “按最新棋谱刷新合法建议” action that reconstructs the authenticated latest session from local persisted chat history. It recomputes the native policy without transmitting or mutating a move.
- Unsupported games show only read-only analysis and an honest explanation, no misleading execution button.
- Update analysis prompt to explicitly abstain when there is no legal candidate; language output is never executed as a game packet.
- Keep final send path's validation against latest session and native legal moves fully intact.

## Deferred
This is a usability/execution-permission fix, **not** proof that every model-generated coaching response is tactically correct, and it does not add an unsafe generic action channel or new support to all game types.
