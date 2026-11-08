# BOARD R6 — Symmetry-independent, calibrated seven-coefficient Gomoku policy

## Intent and exact operating boundary
The owner requires *actual lasting model training* in VeilLink's native chess bot with 80% focus on Gomoku, 20% Xiangqi, and reasonable iPhone 7 A10 resource usage. R6 is an explicit learned-parameter experiment stacked on R5 (which is stacked on R4/R3); it remains draft until paired native A/B and real-device performance pass.

## Authentic data / labels
- Source: legally replayed Gomoku `.vltrain.json` private owner archives. The larger self-play corpus contains 5,141 completed games but only 276 unique full move histories; do not present replays as unique competition.
- Position labels: 2,484 authentic threatened nonforced board states, with **49,716 alternative legal candidate moves evaluated under the actual five-in-row rule**. Those alternative moves were *never claimed to be actual historical moves*.
- Four rotation and four reflection symmetry transforms are grouped together *with side-to-move* before splitting. Same board/hash and D4-equivalent board cannot occur in more than one of the train, validation, test partitions.
- Split: 1,458 training positions (29,180 candidate observations); 514 validation positions; 512 test positions. Adjacent turns from a historical game may still occur in different groups: not game-history-disjoint, so do not overclaim human generalization.
- Train a regularized seven-feature logistic ranker: own3, opp3, own2, opp2, friendly neighbors, enemy neighbors, centrality. Validation-only sweep of regularization and score scale (bounded to ±48,000) selects LogisticRegression C=0.001, multiplier 50,000.
- Source-frozen coefficients: [-0.18624635441331192, 2.436068599785504, -0.08112815287397228, 0.011122914052612674, -0.07881161372911973, 0.043103434011307236, -0.3282513964995388], intercept -1.5430639353126714.
- **Train/validation/test data leakage audit:** R4 had 19 symmetry-equivalent holdout boards out of 504. R6 fixes this using the canonical symmetry-family partition. Independent audit and parameter validation recorded on Issue #6 and PR #173.

## Exact 512-board candidate-ranking proxy (not match win rate!)
| Policy | Complete neutralization | Remaining fork cells (mean) |
|---|---:|---:|
| Untuned static candidate rank | 404 / 512 | 0.33984 |
| Actual R4 trained *score alone*, 15k and ±48k | 409 / 512 | 0.31641 |
| **New R6 trained *score alone***, 50k and ±48k | **443 / 512** | **0.21484** |

The separate R4 *exact rule gate* may already exclude unsafe moves whenever any safe move exists, so these standalone policy improvements do not automatically imply native engine victory. The true end-to-end R6-vs-R4 comparison, with both engines using the SAME exact gate, is the required decision threshold.

**Python/Swift score parity:** 10,248 held-out candidate feature vectors, 10,248 equal **integer** scores, 0 differences under exact coeff/limit. Rust, CoreML, weights.bin, API and extra model files unnecessary: seven `Double` coefficients and one bias are compiled into Swift.

## Real source integration
- `GomokuCounterForkR4.swift` retains frozen R4 `trainedDefensiveBonus` and adds `trainedR6DefensiveBonus` on a single shared, allocation-light 7-feature scanner. `GomokuBot.chooseMove` invokes the new parameter on its normal root search path *when threat detection is active*, leaving own immediate wins and mandatory instant blocks and rule-based forced counterattack unchanged.
- A diagnostic parameter `diagnosticUseR6Defense: Bool = true` lets XCTest use the old R4 learned score **without changing** the rest of `GomokuBot`, search budget, opening or tactical rule gate. Default behavior on this R6 branch is R6.
- Native paired XCTest: four identical central openings × two reversed starting sides = eight genuine R4-vs-R6 full-match attempts, replayed by `GomokuBot.chooseMove` and `GomokuState.apply`. Counts legitimate wins/draws/unfinished separately; logs mean elapsed ms and periodic same-board counterfactual decision differences. A loss does not fail the test; illegal moves do.
- The test is an engineering smoke, not a statistically meaningful Elo sample. Promote only after >200 matched, side-swapped complete matches, score-confidence and opponent diversity.

## Xiangqi 20% lane and low-end constraints
- Previous R4 replaced 21-element ephemeral arrays per candidate with equivalent scalar arithmetic. 12,692 original authentic-position legal candidate integer scores match prior R3 exactly. Do not claim the whole engine is 8× faster from the scoring-only Linux microbenchmark.
- R5 Xiangqi soldier-river feature ablation used 9,222 train legal alternatives and 3,470 heldout, covering 98 independent positions. Old vs geographically corrected top-1 = **27/98 vs 27/98**. AUC .763094 vs .763049. No sufficient evidence for replacement; R6 leaves Xiangqi coefficients unchanged.
- iPhone 7 (A10, iOS 15.8.3) hardware latency/memory tests NOT RUN; Swift 6.2.1 Linux score parity and iOS simulator compile do not substitute.
- No user private archives in GitHub, no live schema changes, no new network dependency, no background worker, no release, no signing, no workflow dispatch and no `main` merge.

## Gates before main
[ ] R6 simulator build + XCTest and recorded `R6_PAIRED_NATIVE_AB` results pass
[ ] R5 `R5_PAIRED_NATIVE_AB` baseline logs validated
[ ] ≥200 matched, side-swapped, completion-valid actual native games and Elo confidence
[ ] Zero legality/forced-win/block regressions
[ ] Physical A10 iPhone 7 timing, p95, memory peak and persistence
[ ] Governor arbitration of stacked R3/R4/R5/R6, avoiding duplicated R2 changes

Status: TRAINED, PARITY CHECKED, WIRED INTO NATIVE SOURCE ON STACKED DRAFT, NOT MERGED OR RELEASED.