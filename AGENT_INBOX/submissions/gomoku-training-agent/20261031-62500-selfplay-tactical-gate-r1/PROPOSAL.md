# Gomoku 62,500 games: anti-regression training / native safety-gate candidate

## Exact action performed

1. Replayed all 28 user-supplied v27.1 Gomoku game histories (28/28 alternating/occupied-cell legal), 700 host moves, 196/672 within-game host knight jumps, matching the previously submitted #110 Bagua raw source.
2. Executed 50,000 color-alternated synthetic 15x15 freestyle self-play matches with NumPy/Numba against an unmodified shared tactical-heuristic opponent. The independent simulator uses immediate-win/forced-block priority, four-direction run scoring, and candidate radius 2. Variable tested: style/knight bonus [0,50,200,800,3200]. No terminal win is used to label unfinished user data.
3. Ran a disjoint 12,500 match validation set, and 16 forced-win plus 16 forced-block synthetic tactical cases (0 failures for this surrogate).
4. Conservative promotion result: **NO positive style coefficient reliably improved results**. Training scores 49.42% (0), 49.165% (50), 48.415% (200), 41.11% (800), 35.55% (3200). Heldout 49.56% (0), 49.76% (50), 48.68% (200), 42.12% (800), 34.92% (3200); the tiny 50 advantage is statistical noise. Result: DO_NOT_PROMOTE knight-only play preference.
5. Source audit discovered `GomokuBot.chooseMove` checks own immediate wins but does not enforce a global forced blocking move **before** learned root shortlist ranking. This is an independent safety gap. Proposed minimal geometry-based forced-block gate, checked before `learning.bonus` and `learning.rootAdjustment`, plus two native XCTest fixtures. No new weights, no gameplay data migration or search-budget expansion.

## Distinguish evidence

The 62,500 matches are in a **new offline surrogate** written for this experiment, not the native Swift engine. Therefore results establish only that blind forced-knight bonuses are risky under this controlled proxy. No Elo improvement for the shipping app, no trained CNN/NNUE/Core ML weights, and no claim of model convergence. Independent validation is not a proof of superiority against an external engine.

## Anti-catastrophic-forgetting / rollforward standard

- Baseline GomokuBot remains immutable; avoid changing reinforcement level/default mode without native paired evaluation.
- Order remains **immediate win > immediate opponent block > multi-ply tactical search > learned opening preference/Bagua style**.
- Gate any future external network by: legal-action masking; candidate tactical hard gate; independent train/validation split by parent-game, not data augmentation; paired color-swapped matches with confidence bounds; at least 5k native-level arena games across difficulties; iOS 15/26 device speed/memory; rollback toggle.
- Learning from 18 unfinished Owner records cannot be considered victory-reinforced data. Prior #110 source data must remain separate and opt-in behind Owner gate.
- Future training path: use Rapfi only as **external research/opponent** if licensing and export permissions allow; do not link GPL-3 engine into VeilLink MIT/Apache-like consumer app automatically. AlphaZero+PyTorch/ONNX candidates need tensor/runtime/rule validation before deployment.

## Deliverable

`PATCH.diff` is advisory and uses the exact main SHA; `FILES/TRAINING_RESULTS_62500.json` preserves measurements/seed protocol. The full runnable Python trainer and heldout validator are now staged as plain-text source under `FILES/Training/` (verified byte-exact Git blob against Owner-local trainer), while binary weights/ZIPs remain forbidden in Inbox. The Owner additionally receives a downloadable local training kit. Apple Xcode CI was **not run** in this Inbox-only lane.
