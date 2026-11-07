# VeilLink BOARD R5 — actual native A/B paired test

**Governance:** Integration Governor live-lane grant in Issue #6. The R5 draft is stacked on R4 draft PR #172; it is not merged into main and does not create a release or IPA.

## Why this test exists

Previous R2/R3/R4 datasets demonstrated legal position replay, supervised policy training and one-ply tactical feature improvements, but did **not** prove the final native bot is a stronger match player. R5 adds an **actual production `GomokuBot.chooseMove` matched-opponent head-to-head** rather than another independent proxy.

## Exact control design
- Engine, `GomokuState` rules, R3 weights, formation default, learning snapshot and root/reply search budget are **identical** between both contestants. An optional default-true `diagnosticCounterForkR4` parameter only disables the R4 fork safety gate and R4 defensive bonus in control moves.
- A/B test fixture: **six exact opening placements** [112,111,113,97,127,98] x **both assignments of R4 to first/second player** = 12 native games.
- Deterministic bounded search budget: radius 2, root 8, reply 4, continuation 0, 38ms per move, no model downloads/CPU-intensive training on the user's device.
- All moves applied to the actual `GomokuState`; illegal moves or no-response states cause unit-test failure.
- W/D/L outcome is counted **only when the engine reports a winner or actual draw**. Move-cutoff games are reported as `unfinished`, not transformed into wins or draws.
- Test logs `R5_PAIRED_NATIVE_AB` aggregate: R4 wins, R3 wins, draws, unfinished, total legal plies and mean wall-clock ms per decision.

## Why this is not yet a strength certificate
Twelve games are an engineering smoke test, not a statistically precise estimate of win rate. A decisive strength assertion needs at least 200 matched side-swapped completed games with multiple difficulty budgets plus confidence intervals, and preferably opponent variety. `GomokuBot` may include shared positional inductive biases, so same-engine self-play alone cannot establish strength against human players or unrelated strong engines.

## Xiangqi 20% lane
The R4 allocation-free evaluation of 21 learned numeric features retained full 12,692 candidate parity from 371 authentic archived states. The offline arithmetic speedup (~8x score-only on Linux) must NOT be extrapolated to complete Xiangqi search or iPhone 7. Further Xiangqi policy promotion requires actual engine A/B and a corrected soldier-river feature **retrained from data**, never silently altering existing trained coefficients.

## Low-end device release gates
- iOS 15 simulator build and unit tests.
- Actual iPhone 7 (A10, 2GB class memory) testing for average and p95 move latency, model memory, shutdown/restart history persistence, background interruptions, OOM/crash-free games.
- Verify mandatory immediate win/block, no illegal actions, entire game completion, no user data replacement.
- Do not auto-start signing/IPA workflows or merge main before Governor-approved gates.

**Current R5 code status:** branch staged; paired XCTest is a real native source-level test and records its own real results only after CI executes. The R5 engine flag defaults **true** and does not change production behavior. No claims of win rate are made until CI execution returns a result.