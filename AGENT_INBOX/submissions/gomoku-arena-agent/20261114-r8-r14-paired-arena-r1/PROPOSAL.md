# Goal: actual R8–R14 engine head-to-head, with no fabricated strength multiple

## Source-verified key fact

The latest V29 `GomokuBot.swift` R8 fallback search *suffix* and the R14 source suffix, after removing newly added read-only `onExploredLine` observations, are **byte-equal** (14,679 UTF-8 characters in the compared suffix). The R14 `chooseMove` argument `diagnosticEclipseUnified: Bool` selects whether to use `VeilGomokuUnifiedBridge.chooseMove`; choosing `false` preserves the old fallback branch, choosing `true` permits the new frozen 48-tree trained PVS. Immediate own-five, opponent-five, R4 fork defense, R6 and R8 forcing win protection remain upstream. This is a **source-compatible legacy-path test**, NOT an independently executed V29 release IPA binary benchmark. Both source files were read through the connected GitHub repository API.

## Concrete implementation

`FILES/VeilLinkTests/GomokuR8R14PairedArenaTests.swift` compiles against an **accepted R14 product integration** (NOT original V29 alone):

- Executes the actual shipped-state `GomokuState.apply`, actual `GomokuBot.chooseMove` and real learned bridge with shared legal rules.
- Same fixed `GomokuBotBudget` on both sides; main-mode cohort uses 180 ms target per move with the same initial radius/candidates/continuations and `balanced` candidate policy. Total work may still exceed target under the mandatory safety scans; actual elapsed times are reported.
- Baseline uses `diagnosticEclipseUnified:false`, candidate `true`, with matching `learning:.empty` and disabled formation so external/private user history cannot contaminate this isolated engine comparison. This isolates kernel difference, not a production-history personalized matchup.
- Each deterministic six-stone nonterminal opening produces **two complete games**, candidate once playing black and once playing white.
- No truncation: invalid move/no-move/exception cannot be counted as a loss or draw. Every legal move, decision timing, node number, engine label, winner and exact seed is exported as one JSON object per completed game.
- For ordinary CI the suite runs a legal-opening test and a same-position 2-branch decision test, and **skips** the full arena. The 2,500-pair / 5,000-game experiment activates only when the explicit `VEILLINK_GOMOKU_ARENA_PAIRS` environment variable is set.
- Independent `FILES/Validation/audit_r8_r14.py` recomputes all win results from stone placements, rejects duplicate/missing color pairs, invalid moves, mismatched journal, candidate routing discrepancies and incomplete matches. It produces paired-bootstrap 95% uncertainty and both sides' actual decision latency summaries. It specifically fails positive claims when no actual R14 bridge calls occurred.

## What this does not claim

No full native R8/R14 head-to-head game has been run. **Current count: 0 finished direct games.** Previous R10 trained/untrained 500 games and 420 four-tier calibration games remain unrelated experiments and must not be substituted. R13 15× microbenchmark gains refer only to one query type, not strength. No 6× strength or Elo gain is established.

## Normal workflow

1. Governor selects a single current R14 integration branch (e.g. cumulative #220 after overlap arbitration), pins its commit SHA and checks `GomokuBot.chooseMove(... diagnosticEclipseUnified: ...)` still exists with the documented switch and old path.
2. Apply advisory add-file `PATCH.diff` **only on an authorized integration branch**; CI must compile on Apple SDK before any game claims.
3. Run `testSameBoardDecisionsAreLegalAndDoNotMutateInput` first; then 30 pairs / 60 games to check legal replay and routing; then a predeclared 2,500 independent opening-pair / 5,000 complete-game tournament.
4. Save raw JSONL outside the repo; run the independent replay/paired-bootstrap auditor. Pin source commit hashes and output SHA-256. Repeat on a physical iPhone/iPad for time/thermal; Linux timing is not iPhone timing.
5. A score improvement with lower 95% paired-bootstrap bound greater than 50% supports only superiority under that exact rules/budget/opening distribution, not a general Elo or sixfold chess-strength claim.

## Governance

This branch stages proposals **only** under its own `AGENT_INBOX/submissions/` directory; no product source, release, workflow, main or user game data is changed. Agent does not dispatch CI, create IPA or self-merge.
