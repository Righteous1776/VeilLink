# ECLIPSE R7 — implement, but never coach the human player

The Owner refined ECLIPSE Thinking Studio: board-inference animation must be visible but MUST NOT provide player hints. Therefore this R7 proposal **supersedes the active-board spatial overlay in earlier R6 design**. Implement a new invariant:

- Active game: no colored candidate circles, heat maps, opponent threat coordinates, PV move arrows, suggested moves, per-root scores or rejection reasons anywhere in the human player's view. This includes live AI-thinking, human-turn and after AI completed move within an unfinished game.
- Abstract graphical motion (branch-like glowing paths) is permitted but is visually independent from board coordinates/search sequences and is clearly labeled decorative, not true search-tree position.
- The main interactive `GomokuBoardView` is left exactly unchanged: no overlay or tap interception.
- Postgame: a **separate read-only** board may play back ONLY actual committed game moves. Data source = existing `LocalBoardMatchMove` journal; it must match `GomokuState.board` and alternate black/white, with no duplicates or extra moves after terminal five.
- Event data: engine raw PV/candidates are filtered by pure Swift policy **before** any SwiftUI live widget; its only input will be `LiveMetrics { completedDepth?, visitedNodes? }`.
- At current main, no real native PVS telemetry is connected, so the R7 source passes nil for live metrics and shows dashes, never generated fake numbers. UI still shows real `isAIThinking` and prior measured milliseconds.
- Use original SwiftUI-built ECLIPSE robot, no Grok-branded media or strings. Keep other game Grok card paths unchanged.
- Restarts/seats/new games lock out history until a new game finishes. Disabled/unverified match archives produce empty replay.

## Implementation present in Owner-delivered source ZIP (NOT applied here)
- `VeilLink/UI/VeilEclipseTracePolicy.swift`, 5710 bytes, Foundation-only.
- `VeilLink/UI/VeilEclipseIdentityAndTrace.swift`, 15541 bytes, full SwiftUI identity and read-only replay components.
- A real 25,221 byte `PATCH.diff` adds these two files and updates exact existing `GameLobbyView.swift` + `LocalAIGameController.swift` source snippets.
- Full offline HTML prototype and live/after toggle and two screenshots. No private raw training records or user secrets inside the public proposal.

## Verification
- Swift 6.2.1: 15 native policy checks pass with `-swift-version 6 -warnings-as-errors -O`.
- `swiftc -frontend -parse -swift-version 5`: SwiftUI source parses, but **NOT TYPE-CHECKED against iOS SDK**.
- Chromium/Playwright 320x568, 390x844, 768x1024: live panel no hints, replay hidden until complete, postgame scrub/step works, no horizontal overflow or JS runtime errors.
- `git apply --check` applies owner patch to **synthetic exact-context snippets captured from eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0**, not the complete repository checkout.
- Outstanding: full-main patch test, Xcode build, XCTest, simulator and real-device validations, R5 native runtime telemetry integration. No IPA.

## Integration instructions
Governor must arbitrate overlap with drafts #186/#187/#190/#193/#196/#197. R5 may later publish only sanitized `LiveMetrics` to R7. Do not leak raw PV or consideredIndices into any live SwiftUI view, including diagnostics. No legacy JSCore removal in this UI task.
