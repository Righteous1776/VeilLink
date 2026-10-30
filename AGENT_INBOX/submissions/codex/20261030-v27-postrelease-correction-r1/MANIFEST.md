# Manifest — V27 post-release correction R1

- Status: `VALIDATED_LOCAL` for source/static gates; Apple SDK and device gates pending Governor application.
- Lane: `INBOX_ONLY`
- base_main_sha: `403b3dc474746d3925ad52fa4169225905bac7fc`
- Baseline: `403b3dc474746d3925ad52fa4169225905bac7fc` (`origin/main`, 2026-10-30)
- Candidate payload: `PATCH.diff`
- Product tree mutation in this branch: **none**
- IPA / version / build / signing mutation: **none**

## Candidate scope

1. Apple Files import handoff and security-scoped staging for every current importer.
2. Game-scoped Gomoku/Xiangqi learning stores with no fixed position/history/file-size cap.
3. Four selectable board-strength tiers plus sequence/outcome learning at every tier, with an explainable personal coach profile.
4. A10-aware Settings, Agent and Owner Console presentation.
5. Automated six-hour SQLite integrity sampling and read-only user status.
6. Tool/game/story reclassification.
7. Restore the 48×27 Guandu battlefield for offline 三国兵器 and remove the visible 7×9 fallback.
8. Tests for learning separation/sequence response and imported-file materialization.

## Files

`PATCH.diff` changes 28 product/test files (1,368 insertions, 226 deletions), including new:

- `VeilLink/Core/VeilImportedFileAccess.swift`
- `VeilLink/UI/TacticalV2/TacticalV2SoloView.swift`
- `VeilLinkTests/VeilImportedFileAccessTests.swift`

Third-party engine intake evidence is recorded in `THIRD_PARTY_CHESS_ENGINE_AUDIT.md`; no external binary, weight or unlicensed source is included.

Supporting evidence:

- `PROPOSAL.md`
- `TEST_PLAN.md`
- `RISKS.md`
- `TRAINING_AUDIT.md`
- `GALGAME_RECOVERY.md`
- `STUDY_RECORD.json`
