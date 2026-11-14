# ECLIPSE R12 — actual GomokuBot search-branch board visualization

Base `main`: `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`.
Canonical Inbox PR: #208. This R12 amendment supersedes the decorative-only R10 board animation while preserving the R10 every-match archive and R11 black compute console.

## User-facing interaction
- Five-in-a-row → 训练与高级设置 → 棋盘思考可视化. `@Published` + `UserDefaults` key `VeilLink.Gomoku.EclipseTraceEnabled.v1`; **default OFF**. Independent of difficulty/deep-search choices.
- **Only while the native AI is actually searching**: draw up to 14 short-lived actual examined branches as thin lines; each hypothetical move appears as a translucent/dashed, circled ghost stone. A path represents the actual successive native `GomokuState.apply` calls, root → reply → continuation. No scores/probabilities, forced-win proof labels, ranked suggestions or final move highlight.
- Timeline 24fps (12fps low-power) with 1.35-second fade, respects Reduce Motion, `.allowsHitTesting(false)`, no change to underlying 15×15 board geometry; uses `VeilTheme` from the existing original skin.
- Cancel, restart, change seat or finish AI search: store.clear() and no events visible.
- If the standalone JSCore engine is chosen instead of native GomokuBot, there is **no truthful native branch stream**; show no paths, don't simulate fake candidate routes. R5 native unified backend must expose the same observer in a separately governed integration before JS removal.
- This is not a coaching UI. Nevertheless, displaying actual spatial search candidates can **incidentally reveal strategic information**, even if ephemeral. For strict no-assistance competitive play, leave this feature OFF. Do not claim absolute non-hint privacy while displaying true board coordinates.

## Real callback specification
```swift
GomokuBot.chooseMove(...,
    onExploredLine: (@Sendable ([Int], Int) -> Void)? = nil)
```
At existing native root/reply/continuation state application points, submit `[root]`, `[root, reply]`, `[root, reply, continuation]` with actual measured cumulative `nodes`. No new search, no score modifications, no artificial computation delay. Native non-observer paths are unchanged by `nil` default.

`VeilEclipseSearchTraceStore` locks the private current board snapshot and validates each candidate sequence by replaying GomokuState.apply, limits to 1–3 plies / 0–224, monotonic node counter, 20Hz throttle, preserves deeper reply/continuation of a just-recorded root, caps 14 recent traces. begin() revokes old session before validating; token UUID invalidates stale/cancelled detached Task callbacks. Public snapshot additionally requires exact match sessionID, turn, playing and aiThinking; no trace survives player turn.

## Dedupe and merge discipline
- Current main still has old 4 Gomoku difficulties, optional JSCore PVS and separate projects; R12 does NOT merge any draft search PR (#193/#196/#199/#206/#207/#209/#210).
- Canonical ECLIPSE UI/history code is PR #208, not older R8/R9 UI drafts (#203/#204). Replaces R10 random board effect with this real-path canvas in the **same source filename** and keeps R11 black console unchanged.
- Proposal patch modifies only: `GameLobbyView.swift`, `LocalAIGameController.swift`, `MiniGameViews.swift`, `GomokuBot.swift`, plus 8 new Swift UI/helper files. The advisory `PATCH.diff` is a single 12-file exact-main-targeted diff.
- Against source returned from exact current main, all hunks were applied **in-memory with exact context and old/new counts**, then all 8 proposed add-file outputs compared byte-for-byte to staged source. Result: 12/12 paths valid. This is a strong patch preflight, **NOT** an Xcode compile or a live repo merge.

## Test evidence
- Linux Swift 6.2.1 `-swift-version 6 -warnings-as-errors -O` trace store + source-faithful Gomoku rules stub + `TESTS/R12SearchTraceTests.swift`: **33/33 assertions PASSED**; includes stale session/token, occupied squares, 1→2→3 branch, illegal moves, rate limit, invalid begin fail-closed, cancellation.
- R11 413 console + R10 39 archive/board + 18 policy + 35 session = 505 previous assertions, R12 adds 33 = **538 total independent executed assertions across local suites** (not playing-strength results).
- SwiftUI R12 Canvas source passed Swift frontend syntax parse on Linux. Real Apple SDK typecheck, XCTest, real actual GomokuBot telemetry end-to-end in App, iOS simulator, thermal and UX remain UNVERIFIED.

## Blockers before production
Integration Governor review with other agents' `GomokuBot` modifications, real Xcode SwiftUI compile/XCTest, race/cancellation and match archive tests, enabling real V9/R5 events if merged, matched-budget performance and low-power accessibility checks. No main modification/IPA from this Inbox.
