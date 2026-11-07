# Fix: iOS exit must not erase solo Gomoku / Xiangqi

## Verified current bug
Main creates a brand-new LocalAIGameController, empty Gomoku/Xiangqi boards and fresh sessionID on navigation. LocalAIGameView.onDisappear calls cancelAI, and its old implementation finalized unfinished learning, erasing active learning plies. The learning archive is *not* the user's current playable match.

## Proposed actual source changes
1. Separate per-game local JSON durable move journal under Application Support/VeilLink/LocalMatchesV1. No SQLite schema/key/wire changes.
2. After every successful human or AI move, synchronously atomically write both move actors plus sessionID and difficulty. File is protected until first device unlock. No reliance on app shutdown callbacks.
3. On controller creation, validate archive replay through actual native GomokuState/XiangqiState.apply() methods, recreating side-to-move, last move, threefold repetition/check state and adaptive learning plies. Restore pending AI only on screen appear, never during init.
4. Navigating away cancels task but does not count unfinished result or erase match. Explicit “重开” archives corrupt data before delete and only resets selected game. A failed write is visibly flagged and old disk data is never silently overwritten if corrupt.
5. Developer formation recorder is kept separate from persistent ordinary match while recording.
6. Add 5 XCTest scenarios, scoped isolated storage.

## Conflicts
PR #128 changes LocalAIGameController/GameLobbyView to allow black/white/red/black role selection, so human/AI role mapping needs Governor reconciliation before production; #141 game export PR and #129 file-import PR also change GameLobbyView. Multiplayer PR #130 is a different subsystem.
