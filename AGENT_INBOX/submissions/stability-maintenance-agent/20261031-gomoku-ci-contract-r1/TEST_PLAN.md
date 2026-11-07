# Test Plan — Gomoku decision contract

## Verified evidence (from GitHub exact-head CI; no new CI claimed)
- PR #96, head `c72321cf8d3c18c9c8b34fac9d17e5ed9b360825`, iOS run 41108155991: iOS build succeeded, 785 XCTest methods executed, 1 assertion failure.
- PR #99, head `3dac0a866935fd8692ed12fc81e792f206395e7b`, iOS run 41109981785: iOS build succeeded, 789 XCTest methods executed, same 1 assertion failure.
- Both fail on the expected old `"五子棋 Bot"` vs actual new `"五子棋 · 均衡"`, `AgentControlAndLocalGameTests.swift:63`.
- Governor must verify the actual new exact-head run after patch application; above results are observations, not proof the patch passes.

## Static checks
1. Assert baseline main is `403b3dc474746d3925ad52fa4169225905bac7fc`.
2. `git apply --check` the `PATCH.diff` against exact branch during integration; require one modified test source, zero unintended changes.
3. Inspect default `BoardBotDifficulty.balanced` and `LocalAIGameController` mode-string construction before applying, because later feature changes may supersede this contract.

## Unit tests
1. `AgentControlAndLocalGameTests/testLocalGomokuFallsBackToBaselineAndCompletesAITurn`
2. `AgentControlAndLocalGameTests/testRestartCancelsPendingAIAndPreventsGhostMove`
3. `GomokuBotTests` and board-learning migration tests.
4. Full `VeilLinkTests` XCTest suite; do not count a passed isolated test as full success.

## Integration tests
- Reconcile with PR #96 source/test batch; rerun iOS CI on the *new* exact PR head.
- Resync PR #99 after #96's selected fix and rerun it separately.

## Negative / failure cases
- Mode is blank, "规则 Bot", another game, "五子棋 · 高手", or "五子棋 · 进阶" for the default controller: the assertion must fail.
- `isAIThinking` never clears, player does not return to host, or second AI stone is missing: existing assertions must fail.
- Never replace the baseline strategy policy with an experimental AI as a workaround.

## Regression invariants
- Exactly one legal AI stone after the human's initial stone.
- No ghost move after restart/cancellation.
- No protected-source mutation in this submission.

## Device / OS coverage
- CI: macOS XcodeGen + iOS simulator build/full XCTest on exact integration commit.
- Devices: iPhone 7 iOS 15.8.3 and modern iPhone iOS 26 with a real human-vs-AI turn and force-quit/relaunch check; only Governor/Owner can certify device acceptance.
