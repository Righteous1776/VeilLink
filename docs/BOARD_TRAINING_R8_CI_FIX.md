# R8 CI test isolation fix — 2026-11-08

Scope: TESTS ONLY. No changes to `GomokuBot`, `GomokuState`, trained coefficients or runtime semantics. Temporary Governor lane recorded in Issue #6.

## Why CI #42390547876 failed
The legacy R4 regression `testR4ActualNativeBotUsesForcedForkEscapeUnderLegacyBudget` expected a defensive root move `112`, but after R8 added the forcing-win-in-two gate, the actual bot chose `3`. This is an intentional behavior change, not proof of an illegal action. In the synthetic fixture, Guest's stones `0,2,4,6,8` plus move `3` make two DISTINCT direct five-in-row wins on next turn: squares `1` and `5`. Blocking either leaves the other. Old R4 root `112` is still the valid neutralization of Host's competing fork; the R8 candidate `3` is forcing attack.

## Exact test fix
1. Legacy R4-only test now explicitly passes `diagnosticR8ForcedWin: false` when calling the actual `GomokuBot.chooseMove`. It must still choose `112` and fully remove the Host fork under original budget.
2. Added independent **R8-on** regression to the same synthetic fixture. Assert actual native root `3`, rule teacher double-win true; run **two complete forced-outcome continuations** via `GomokuState.apply`:
   - Guest 3, Host blocks 1, Guest wins at 5;
   - Guest 3, Host blocks 5, Guest wins at 1.
3. All other tactical, A/B, legal and time-budget tests remain unchanged. The 2026-11-08 private friend chess records are not in the PR.

## Gates
- iOS Xcode simulator build and XCTest must pass with this stacked test-only PR;
- R8 vs R6 full native A/B and iPhone 7 A10 wall-clock + heap still required before any `main` merge;
- Do NOT override existing trained R6 weights with the new friend-style shadow ranker: independent strict tactical test shows 466/544 R6 vs 440/544 friend imitation, no native strength evidence.

**No release, signing, IPA or direct main modifications.**
