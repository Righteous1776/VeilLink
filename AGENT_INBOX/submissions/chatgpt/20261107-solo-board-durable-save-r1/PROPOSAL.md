# Gomoku and Xiangqi must keep solo progress after exit

Confirmed root: LocalAIGameController starts a blank sessionID and board in init; onDisappear calls cancelAI, which previously finalized learning as unfinished without saving match state.

PATCH.diff supplies LocalBoardMatchStore with per-game atomic JSON legal move journals, model restoration with deterministic rule replay, complete turn/repetition/check reconstruction, AI resume after re-entry, safe corruption preservation, and warnings for failed disk writes.

Human and AI moves are saved synchronously after each successful action. Existing AdaptiveBoardLearning archives and Wire/SQLite schemas untouched. Explicit restart deletes only the selected match; teaching-mode start explicitly replaces the Gomoku match. No auto deletion on navigation or termination.

Integration conflict: PR #128 changes solo player side and LocalAIGameController. Reconcile future side selection by persisting human/AI roles; current main uses human .host. PR #130 is multiplayer-only and does not fix this issue.

Previously lost in-memory matches cannot be reconstructed retroactively. Teaching mode not included in normal solo match persistence.