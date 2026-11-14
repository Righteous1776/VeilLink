# Proposal — Gomoku default AI mode regression test contract

## Goal
Remove a **test-contract mismatch**, not suppress an actual runtime regression. Restore a meaningful gate for the local Gomoku AI after its Build62 integration changes.

## Observed evidence
- Base main `403b3dc474746d3925ad52fa4169225905bac7fc` has `LocalAIGameController.selectAIMove` assigning `lastDecisionMode = "五子棋 Bot"`.
- Draft PR #96 HEAD `c72321cf8d3c18c9c8b34fac9d17e5ed9b360825` extends `LocalAIGameController` with `boardDifficulty = .balanced` by default, and sets the label to `"五子棋 · \(boardDifficulty.title)\(learned)\(formationLabel)"`.
- Exact-head iOS CI for PR #96, run 41108155991, compiled and executed 785 XCTest cases: **1 failure** at `VeilLinkTests/AgentControlAndLocalGameTests.swift:63`. Expected `"五子棋 Bot"`, actual `"五子棋 · 均衡"`.
- Stacked PR #99, run 41109981785, compiled and executed 789 tests: **the identical single failure**. The extra four tests are not failing.
- Draft PR #100 has a successful iOS CI run 41110884224, but is independent and not a substitute for #96/#99 acceptance.

## Root cause
The feature intentionally changed the human-readable AI difficulty label; the existing test hard-codes the pre-feature label. The failing assertion does not indicate a failed AI turn: preceding checks show `isAIThinking == false` and current player returns to host; subsequent test also checks exactly one AI stone.

## Proposed behavior
Replace one stale strict equality with a narrow **compatible contract**: the default local Gomoku mode is either the legacy `"五子棋 Bot"` or the difficulty-labelled `"五子棋 · 均衡..."` form (optional training/formation suffixes). Preserve AI turn completion and single-stone assertions.

The test must not accept arbitrary labels (`"规则 Bot"`, unrelated games, advanced/master difficulty) and should include the actual string in its failure output.

## Architecture / implementation
- One test source file in advisory `PATCH.diff`, based on exact latest main.
- No change to player-facing mode strings, control flow, learning/migrations or actual AI algorithms.
- The patch is meant to be applied by the Governor to the **isolated integration branch** after selecting the accepted product changes. Applying it alone to main has no product effect and does not signify the merged feature exists.

## User-visible impact
None directly. It isolates the remaining CI obstacle so real functional regression gates can run and future releases are not blocked by an obsolete label assertion.

## Alternatives considered
- Change production UI back to "五子棋 Bot": rejected because it hides the actual difficulty/training indication.
- Blindly skip/remove the test: rejected because it discards turn-taking and AI-stone regressions.
- Assert only substring "五子棋": rejected because it would accept unrelated difficulty states.

## Acceptance criteria
1. Exact source-context patch applies once; one test source file changes.
2. Main + selected integration candidate satisfy the compatible mode-label assertion.
3. Targeted XCTest passes on PR #96's new exact HEAD (not assumed from prior CI).
4. Complete iOS CI passes on subsequent exact PR head, then stacked #99 is rerun after upstream resync.
5. Physical iPhone7/iOS15 + modern iPhone gameplay still needs its separate device gate.
