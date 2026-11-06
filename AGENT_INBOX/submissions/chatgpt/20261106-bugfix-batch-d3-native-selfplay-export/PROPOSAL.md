# D3 — 修复“原生 Bot 自对弈棋谱无法导出”

## Evidence from main
1. LocalAIGameController creates a dedicated persistent `gomoku-native-selfplay-v1.json` via `nativeTrainingStore`; verified seed + actual completed Bot-vs-Bot results are recorded there.
2. `exportBoardLearning()` calls only `learningStore.exportPackage()`, i.e. the separate human-game repertoire.
3. GameLobbyView has only the ordinary “导出训练包” control; no native self-play export.

## Proposed fix
- Add explicit `exportNativeSelfPlayDetails()`, guarded for Gomoku, archive health and nonzero completed games.
- Reuse the existing checksum-enveloped `AdaptiveBoardLearningStore.exportPackage()` serialization. The package includes `payload.recentGames[].actions` (h/a-prefixed per-move sequence), result, finish time, position statistics and completed game count, not merely a summary or fabricated records.
- Add a separate “导出自对弈明细（逐手棋谱）” button in the native-training card. Use the existing iOS ShareSheet, disable it while native seed is importing or while no completed games exist.
- Allow a trusted internal filename label and unique UUID suffix for exports to prevent same-second overwrites; remove temporary share file on dismissal.
- No changes to training data, native Bot, engine selection, schema, compatibility, protocol, game counts, or existing human-learning export meaning.

## Acceptance
Export after one real saved self-play game includes exact h/a actions, outcome and timestamp; after restart, it is still exportable. A human-only export remains distinct. Empty/unhealthy archive does not create fake games or a misleading empty self-play package.
