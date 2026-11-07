# Board training R3 — executable integration record

**Authority:** Owner instructed that actual training alter production bot action selection, with ~80% effort on Gomoku / ~20% on Xiangqi. Governor performed controlled integration on branch `integration/board-training-r3-20261107`, based on `main` `2c5b5161027edff097b27fe3323d30f6ca3e430e`. This is NOT an authorized main release.

## Original evidence and provenance
Original source: three owner-provided app v28 `.vltrain.json` exports. Replayed locally for legality and SHA-checked; never committed raw human histories. Native Gomoku archive has 5,141 replayable completed games but only 276 different complete move sequences. Historical player Gomoku 81 records (39 complete markers), Xiangqi 8 records (3 complete markers). Repeated self-play records are not independent training experiences.

### Gomoku — priority 80%
Replayed actual board states, 4,522 sampled nonforced distinct positions. Created 71,710 candidate-position training rows with exact next-turn double-winning-threat geometric labels. Position-hash-disjoint heldout: 53,125 train / 18,585 test; 46 heldout positions include at least one fork move. A seven-feature logistic model was fit offline on local five-cell windows, local adjacency, centrality; no explicit winningSquares labels fed as features. Heldout fork Top-1: **46/46**; handcrafted heuristic-feature *proxy* 23/46. This is tactical recognition on 46 heldout boards, not native win rate or Elo.

Deployed as bounded 0–2400 **root ranking bonus** inside the existing native `GomokuBot.chooseMove` candidate ordering. Mandatory immediate win and forced block still preempt training. Native adversarial search still resolves the chosen legal move. Native self-play `NativeGomokuSelfPlay` now selects 49 central openings and 4 bounded native search budgets to increase exploration. `AdaptiveBoardLearningStore.recordCompletedNativeBatch` checks every submitted ply against its FNV position hash, player turn, legal stone, actual terminal outcome; duplicates are not counted as new experience, but existing archives remain untouched. UI training progress ignores rejected/duplicate games instead of reporting write failure, and reports counts honestly. Existing per-player learned move evidence continues to affect root scores and survives restarts.

**External PVS/VCF caveat:** when user selects external engine without native training active and no formation preference, PVS/VCF may win selection, and this native R3 model is NOT consulted. Existing UI distinguishes it, not a false active-training label.

### Xiangqi — budget 20%
Replayed 371 distinct historical Xiangqi positions, enumerated 12,692 rule-legal alternative moves. Position-disjoint observed-action imitation fit from 9,222 train / 3,470 test candidate examples. The learned 21-feature scoring model predicts observed action Top-1 on 27/98 heldout boards versus capture/check *heuristic ranking baseline* 15/98; this is not a master/engine oracle or proof of better tactical play.

Installed the learned pattern as bounded ±72 move-order hint in `XiangqiBot.orderedLegalMoves`. Native depth/quiescence, legal move generation, check and mate scores remain authoritative. Existing durable per-game Xiangqi loss/win evidence remains active.

## Hard gates before main
- [ ] XcodeGen + Apple iOS15 simulator/device compile
- [ ] Native Gomoku and Xiangqi XCTest, all legacy tests, state restoration, corruption tests
- [ ] Native paired A/B side-swapped matches: current main vs trained branch across 200 fixed openings and difficulty configurations, including mandatory win/block regressions
- [ ] Xiangqi paired legal/tactical and engine search depth checks; no uncontested win/illegal transitions
- [ ] Real iPhone7 and iPhone13 memory/time budget and 1000-game resume/dedup challenge
- [ ] Owner/Governor promotion authorization; no IPA/release workflow initiated from this branch

## Changed surfaces
Only: `GomokuBot.swift`, `XiangqiBot.swift`, `NativeGomokuSelfPlay.swift`, `AdaptiveBoardLearning.swift`, `LocalAIGameController.swift`; corresponding three XCTest suites; this document.
No protocol, database schema, version, identity, security, A9/A10, workflows, signing, IPA, or main changes.

## Data interpretation / limitations
The fitted models are small distilled generalization features (readable numeric coefficients embedded in source, no binary model assets). They are not a self-updating neural network. Continuous learning still comes from existing on-device `AdaptiveBoardLearningStore`, whose sampled position preferences and move-history evidence are persisted and read back for Bot decision. A larger retrain must repeat offline training, holdout analysis, code review, native A/B gates, and versioned rollout. No skill inflation claim before head-to-head native tests.
