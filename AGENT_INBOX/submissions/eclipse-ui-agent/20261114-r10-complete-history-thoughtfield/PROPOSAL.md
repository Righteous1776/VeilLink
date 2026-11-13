# [AGENT-DROP] R10 Proposal: historical Gomoku match archive + non-informative dense board animation

## Owner intent

Every Gomoku match must remain accessible after the next match starts. On the *actual* 15×15 board, fast and dense multi-hued thought animation is desirable even when it conveys no analytical information. As tougher levels legitimately take more computation, elapsed time and cinematic visual buildup add perceived presence. The Owner has explicitly forbidden the visualization from becoming player move guidance.

## Verified baseline issue

Current main uses `LocalBoardMatchStore` to overwrite a single per-game JSON file after each move. `LocalAIGameController.restart` explicitly calls `discardOnExplicitRestart()`, removing the current saved game. AdaptiveBoardLearningStore stores training evidence but is not a canonical browseable per-match journal. Therefore the current app does not retain every historical match.

## Proposed implementation included in owner package

`VeilGomokuMatchArchive` is a distinct archive at `ApplicationSupport/VeilLink/GomokuMatchHistoryV1/<UUID>.json`, one atomic serialized game snapshot per match ID. It validates each step and prevents replacement of finalized games. It archives per committed move and final outcome; on re-start the previous match is marked `interrupted` rather than erased. History is paginated, no fixed total game count, corrupt files are retained, and missing directories are handled. **This does not replace** the existing current-match recovery file, training database, or their import/export semantics.

`VeilEclipseThoughtPattern` generates screen-space moving streaks based only on clock time and constant seeds, never board cells, opponent threats, move ranking, learning scores, PV, VCF or VCT. `VeilEclipseBoardThoughtField` puts these streaks in the background behind stones and the `VeilBoardTapSurface`, with no hit testing. It inherits `VeilTheme` gold/soft metal/success/muted gold, `VeilAppearanceController` and existing `.veilCard()` materials, across all five themes including experimental gated Plainline. Visual density grows gradually with actual elapsed thinking time but is **not computation progress**.

`LocalAIGameController` proposed hook records each actual human/computer move, finalizes result, protects old records from restart, offers postgame paged archive, and exposes a `eclipseSearchStartedAt` timestamp set *after* the controller's existing pre-search sleep. The clock is the true wall-time since calculation start; R10 does not add any delay or change engine budget.

`VeilEclipseTraceSheet` would show a postgame list of saved matches, outcome + timestamp, a paginated Load More, and read-only verified move replay. Active match input receives no candidate/root score, no threat-point legend, no heatmap and no PV line. Existing other-game Grok bot card is untouched.

## Subsystem boundaries

The source code is a proposed 6-file addition + 3-file modification in `PATCH.diff`, not a permitted product edit in Inbox. The patch is advisory, based on source-confirmed main excerpts; Apple Xcode/XCTest validation and full `main` checkout apply check have NOT occurred. Storage is a protected integration surface; promotion requires Governor review.

## R10 continuation revision — 2026-11-14

- Board thinking animation is now enabled only after the controller records a real search-start timestamp, not during the existing 180 ms pre-search delay; no added artificial wait.
- Archive JSON reads have a 128 KB cap before decoding, and oversize writes are rejected without overwriting records.
- Device clock rollback cannot invalidate a persisted match's timestamp ordering; updatedAt/completedAt stay monotone.
- Test inventory: 39 new archive/visual assertions, 18 fair-play and 35 telemetry = 92 passed.
