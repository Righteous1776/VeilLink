# ECLIPSE R12: Correct the trained PVS search horizon, without diluting Codex's fitted model

## Verified starting point
Codex PR #209 at d93e579a1b01e66be77b8e2d45cf2c60cd58b1df fits exactly 1,848,616 D4 canonical BOARD/ACTION candidates, generated from a much smaller real/source game corpus, into 48 Swift-compiled trees (1,348 total nodes). It produced 500 full native trained-vs-untrained assessment games and 420 same-model difficulty calibration games (920 complete, evaluated; no illegal moves). The 5,000-node depth-4 paired result was **55.25%** for trained, with 95% paired interval 49.5–61%, so larger/higher-budget benefit remains unsettled. The frozen model remains unchanged. Full data/models are NOT fabricated, retrained from the 920 evaluation games, or copied into this proposal.

## Specific source flaw and repair
In `VeilGomokuUnifiedSearch.negamax`, the exact Codex source returns `staticValue` immediately when `depth == 0`. This leaves the horizon sensitive to existing own immediate wins, opponent double five-completions, and forced single blocks. Internal full-depth nodes already perform some of these rule checks; extension at the leaf closes that mismatch.

New pure Swift `EclipseHorizonQuiescenceR12` exhaustively scans 572 line windows and returns ONLY four types: `ownImmediateWin`, `opponentDoubleFive` (distinct endpoints), `forcedBlock` (unique cell), or `quiet`. The Codex trained `VeilGomokuUnifiedSearch.swift` overlay adds:
- `Limits.r12HorizonQuiescence = false` by default (frozen rollback);
- `Limits.r12MaxForcedBlocks = 2`, clamped at 1..3;
- leaf evaluation that checks exact wins/losses, recursively explores at most 1..3 forced blocks, evaluates after—not before—the final forced block;
- the SAME global node count and wall deadline (no new 2×/4×/6× time), aborts incomplete depth on overrun;
- unchanged 48-tree trained ordering, tactical legality gates, root history/formation preferences, root fallback, protocol and UI.

## Real-data diagnostic/traceability
Read-only pass over all ten Codex `EVIDENCE/RAW_ARENA/*.jsonl` final assessment/calibration files, 920 games and 28,737 post-preset native decisions, zero index/side/replay inconsistencies. Pre-decision state labels: immediate own win 915; opponent distinct two-five completions 915; only forced block 4,534; quiet 22,373. This is a CLASS DISTRIBUTION, not errors. A stratified 192-case fixture (48 per label) has complete game-move prefixes and independent contiguous-line labels; 192/192 agreed with a second independent brute implementation. Because these matches were already evaluated and used here for engineering, they are regression cases, NEVER a new held-out chess-strength proof.

## Overlay order
1. Governor resolves the exact product source version of Codex #209 versus older proposed R5 #193/#196, V9 #199 (seven-tier, not calibrated) and R10/R11 #207/#210.
2. Apply the Codex #209 six-file product patch ONLY to a separate Governor-controlled integration branch.
3. Apply this R12 `PATCH.diff` onto that chosen trained kernel. Never stack two independent duplicate kernels.
4. Enable the extension only in an explicit shadow/calibration run by setting `limits.r12HorizonQuiescence = true` in the test driver. If results pass, Governor may choose tier-specific opt-in. Default remains false.
5. Full Xcode/iOS XCTest, symmetric tactical regression, equal-time paired full games, actual phone CPU/thermals and UI anti-hint gates before promotion. Do not use the old 920 game records as new training samples.
