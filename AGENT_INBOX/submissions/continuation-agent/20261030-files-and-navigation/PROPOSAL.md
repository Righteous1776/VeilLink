# Continuation from Codex: owner issues 1–8 (P1 focused implementation)

Base main: `403b3dc474746d3925ad52fa4169225905bac7fc` (VeilLink 27.0 Build 62), checked Oct 30 2026. GitHub PR #90 contains earlier Codex V27 feature convergence but none of the owner's new 8-item fix batch. No known newer Codex product-fix PR.

## Implemented as staged source / exact original-source patches

1. **Files import repair:** new `VeilFilesImportStage` obtains user-granted scope, coordinates read with NSFileCoordinator (important for Files/iCloud), copies small/medium selected documents to a UUID-scoped app Caches folder for later password-sheet restoration or background tasks; separate coordinated streaming read for very large file SHA-256 avoids duplicate 2GB copies. The staged source supports safe extension mapping and validates ordinary file/byte budget after copying. Real flow changes in `PATCH.diff`:
   - Settings encrypted backup recovery, and pre-identity first-run Onboarding recovery: stage before showing password sheet, safely release temporary file after dismissal; preserve BackupManager's existing password/decryption and all DB/Keychain contracts.
   - Gomoku/Xiangqi `.vltrain.json` picker: stage before existing import/format validation (current legacy training max is **still** enforced by old store).
   - HTML and ZIP preflight: stage in background task, inspect app-owned file, discard after return; show a file-access error in ZIP preflight.
   - File-integrity SHA-256: coordinated streaming read, not eager full-copy.
   - Image Files picker: stage and clean up, keep existing image compression and encrypted-send path; PhotosUI selection remains unchanged.
2. **A10-only/Independent live status:** `PATCH_A10_LIVE.diff` adds observed coordinator updates in Settings and Owner Console. Requires current mode session ID and current A10 mode plus a nonnil `ultraDecision`; otherwise explicitly renders waiting status. Does not claim A9 data is live; production A9/Ultra authority controls untouched.
3. **Game entrances:** `PATCH_GAME_NAV.diff` adds playable existing `VeilRhythmR6NativeGameView`, `LatticeClashLabView`, `VeilStoryLabView` to game lobby. Adds an honest Galgame missing-resource info dialog, NOT a fake player.

## Not implemented yet; reserved follow-up lanes

- Training 2+3: existing shared `AdaptiveBoardLearningStore` still has one 1600-position/40-game/512KiB data limit, and influences scoring/search ordering only. Need two physically independent per-game stores with one-time v1 migration, separate stats/clear/export, a sequence + formation prediction engine, and full legal-move gating. Never remove all memory/disk safeguards blindly; replace hardcoded record caps with measured storage policies and streaming persistence.
- Tool grouping 5: diagnostics and link sampling must move behind existing governance status surfaces, not be deleted silently or falsely presented as background services.
- Galgame 7: owner R5 archive `VeilLink_Monogatari_Playability_R5_20261025.zip` (5,697,469 bytes, SHA256 `068ba55bfa36672d61960240a684dc4d90ceb7a10868409baf73bc4e6ac6c6f1`) is **not in main or available owner attachments this turn**. PR #85 has only partial text overlays. Official Monogatari 2.8.0 ZIP known SHA256 `16d221485888b0193312e9989ecafa57cb1913978bf2f09ba554552ba3885806`. Recover owner R5 archive by exact hash, audit 115 files, install vendor and native host after Governor / iOS15 validation. Only a missing-assets entry is staged.
- Sanguo 8: true `guandu_large_map_v2_48x27.json` **already exists** alongside TacticalLargeMapLoaderV2 and TacticalLandscapeShellV2. `TacticalV2LaunchGateView` loads it in compatible peer multiplayer; `LocalAIGameView(game: .tactical)` is a different small-board game. An offline V2 campaign adapter is required before removing the small-board navigation/implementation; otherwise an existing playable option would be lost. No false claim of completed large-map gameplay.

## Scope

No current main, SQLite v10 schema, Wire v4, Keychain, signatures, A9/A10 authority, workflows or IPA release changed. Follow-up integration needs current main rebase and protected-surface Governor approval.
