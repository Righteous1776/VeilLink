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

## R11 implementation / explicit owner video request
Owner supplied 22s reference video with a black instrument field, kinetic radial lines, a curved text-heavy band, and compact bottom diagnostics. We implemented a mobile-sized black rectangle inside the existing ECLIPSE avatar card (compact 2-line visible code flow) and expanded TRACE (7-line visible flow), reusing the existing R10 high-density abstract board effect. Do NOT clone another site's complete screen or expose search internals. Simulated `vis.*` lines scroll ~14 rows/s; clearly labeled cosmetic and never mistaken for measured engine logic. Genuine node/depth telemetry uses the unchanged redacted type when available.

The R10 identity panel was modified rather than adding a duplicate standalone card. The obsolete `EclipseAbstractThoughtField` was removed to prevent double rendering. The full R10 archive and previous theme-native/no-hint policies remain unchanged. For de-dup with other Agents see `R11_REFERENCE_AND_DEDUP.md`.

Status: real source + one combined advisory product patch now staged directly in PR #208. Nothing merged into main. Apple SDK compile, full checkout patch apply, actual runtime telemetry and IPA are **not verified**.

## R12 owner-requested change
Owner rejected random board particles: actual searched candidates should be connected by thin transient lines and hollow hypothetical stones; controlled via Gomoku Advanced Settings. This replaces the prior R10 decorative board-field display, without removing R10 every-game archive or R11 black console.

Source-accurate native `GomokuBot` callback emits only after root/reply/continuation `GomokuState.apply` succeeded. A locked collector validates all 1-3 step paths against the board snapshot, enforces UUID/session/turn and 20Hz cap, promotes deeper same-root branches, expires after AI stops, and never changes move choice. UI renders only on current AI-turn and only when the independently persisted setting is enabled. No events from the JS alternative means no line rendering, NOT fake data.

Full code & single consolidated current-main patch are staged in this PR; code changes still require Integration Governor approval. See R12_ACTUAL_SEARCH_VISUALIZATION.md.
