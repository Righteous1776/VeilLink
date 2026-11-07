# VeilLink Board R8 — Genuine-data forced win-in-two tactical teacher

## Goal and integration boundary
User requires lasting intelligence in the *actual* GomokuBot (80% of effort) and XiangqiBot (20%), staying extremely small and usable on iPhone 7 A10/iOS 15.8.3. R8 is a **stacked draft branch on R6 PR #174**, not part of production main. This lane does not change build versions, database schema, wire protocol, signing or releases.

## Real source data vs rule-derived labels
- Input: legally replayed authentic owner-provided training exports; **13,144** distinct real-source Gomoku board states, not 13,144 separate games. Of 5,141 completed native self-play games, only 276 complete sequences were unique.
- The independent five-cell-window teacher identifies moves that cause **two DISTINCT next-turn immediate five-in-row completions** for the moving player.
- Where neither player already has an immediate five, **394 real board states** admit such a forcing move. Breakdown: **346 native self-play** states, **48 personal human-versus-bot** states.
- In those states, **105 recorded subsequent actions did not select a forced-two-win move**: 91 native self-play, 14 human-versus-bot. This is evidence of *a missed forced tactic*, NOT proof these historical games were lost or that each observed move was a bot move. The human-versus-bot history may contain human actions and is not interpreted as model behavior.
- The 394 forced moves and their next-turn winning endpoints were recomputed directly from board rules. Generated legal alternative moves are **teacher labels, not observed user or master moves**.
- Public GitHub contains only derived aggregate counts, synthetic CI fixtures and straightforward source. Private actual move sequences/raw board archives remain in the user's local downloadable bundle only.

## R8 native source design
- `GomokuCounterForkR4.immediateTwoTurnWinCandidate`: **one scan over contiguous five-cell windows**. A square is a forcing move iff at least two different five-windows containing three own stones and exactly two empty squares share that square but have different other endpoints.
- The algorithm stores one `Int16` reply per cell (225 × 2 bytes) and a `Bool` legal-candidate mask (225 bytes); deterministic smallest verified candidate index returned. No chess-network calls, model files, async tasks or recursion.
- `GomokuBot.chooseMove` first checks own immediate five, then opponent immediate five to block, **then invokes R8**. This order is mandatory. If R8 finds a double direct win and no opposing immediate win exists, root has a rule-proved win next turn even if opponent blocks one endpoint. Search's deadline cannot discard the proven win.
- Model R6 remains intact; this R8 tactical gate supplements trained policy. `diagnosticR8ForcedWin: Bool = true` is default enabled and can be set false **only for controlled A/B**. Existing R3/R4/R6 matched tournament XCTest explicitly disables the new gate to preserve experiment integrity.

## Independent compiled-Swift verification
- Python rule teacher and a separate **Swift 6.2.1 optimized executable** were tested on 1,220 exact real board-state fixtures: **394 positive cases and 826 negative controls; 1,220/1,220 identical smallest forcing candidate IDs (0 mismatches)**.
- Compiled Linux Swift test wall-clock ~27ms total, including JSONL parsing (not iPhone 7 performance). No device-side inference of model parameters is needed for the forced-win proof.
- Actual native CI includes synthetic crossing formation positive tests on `GomokuState`, 0ms-budget forced-win priority and 8 genuine R8-versus-R6 native full-game attempts (four openings, two assignments of starting side). W/D/L and unfinished games are separate; illegal moves fail; eight games cannot establish Elo.

## R7 strict game-isolated retraining finding
- Prior R6 had per-board D4 symmetry holdout yet leaked prior full-game trajectories. R7 linked 342 unique full recorded traces into 255 symmetry-related source components and split all threatened boards into train 1,429 / validation 511 / test 544.
- Holdout candidate selection (full game/symmetry component disjoint): old static 440/544, R4 actual 444/544, R7 new trained weights 465/544, R6 production-branch trained weights 466/544.
- R7 is **not adopted**: it selects exactly the same candidate as R6 on 542/544 boards and is inferior in one. Of the 74 test boards with no safe move among candidate shortlist, a full scan of ALL 225 board cells found **no completely safe move**. This indicates the remaining fork risk is not a shortlist omission; solve via tactical counterattacks and multistep search.

## Release and performance hard gates
- R8/parent R6 simulator build and XCTest green; collect actual `R8_PAIRED_NATIVE_AB` data from CI log (do not invent results).
- ≥200 complete, opening-matched, both-seat native A/B games, with confidence intervals and opponents sufficiently different to reduce paired-engine bias.
- True iPhone7 hardware average/p95 wall clock, memory peak, long-run stability and retained learning data migration. Simulator or Linux benchmarks are not device evidence.
- No main merge, release, IPA build/dispatch, signing, private history export, or removal of old saves.
- Existing v28 import is destructive replacement, not merge; do not import derived training data blindly.

**Honest state:** R8 teacher and source implementation are complete on integration draft; independent tactical parity passes. Full native head-to-head and old-phone/device release criteria are pending.