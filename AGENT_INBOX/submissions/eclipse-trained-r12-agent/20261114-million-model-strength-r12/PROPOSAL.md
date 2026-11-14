# R12: Convert Codex's 1.85M-row fitted ordering into more useful search depth

## Source facts
Exact upstream is Codex PR #209 / commit d93e579. The final fitted policy has 48 hist-boosted trees, 1348 Swift nodes, fitted using 1,848,616 D4-canonical *board+legal-action* examples, plus separate 120343 validation and 220532 test examples. It is not a million human games nor a learned policy trained on the 920 subsequent native arena match logs. The frozen training has strong 500-game under-budget evidence but deep-search paired 95% interval includes 50%. This agent did not retrain the private teacher corpus, nor change a single tree coefficient.

## Fresh analysis on 920 published native game records
Parsed all ten JSONL evaluation subsets from PR209, replayed the 28,737 post-presets actual decisions (no repeated occupied squares), and re-evaluated tactical geometry. A first pass incorrectly flagged a won terminal move as a tactical error: corrected analysis excludes all already-winning moves. On 500 matched trained/baseline games only: 6,844 fitted-model decisions and 6,810 control decisions. Among moves allowing a next-turn independent opponent double-five *and* having at least one nearby two-cell-radius alternative avoiding both immediate opponent five and that near-term fork, the fitted model had **0** such cases vs control **54**. These are diagnostic move events, NOT independent games, human-level wins or an out-of-sample new tournament. Because the same 500 games were previously used to evaluate this model, this examination must not be marketed as newly held-out proof.

## Real proposed enhancements
1. **R12 scorer memo.** Frozen `EclipseTrainedOrdering.score` repeatedly recomputes a 48-tree inference for the same board/side/candidate as PVS iterative deepening revisits positions. Keep a local-only 4096-slot exact-key (Zobrist fingerprint + side + index) direct-mapped memo. Cache only search ordering scores, never win/loss proof, board evaluation or A10 state. No disk/network or persistence. Collision slots are key-compared so ordinary bucket collisions yield misses; rare 64-bit Zobrist collisions could alter heuristic ordering and require fuzz/device review.
2. **R12 leaf threat extension.** Original Codex `negamax` returns `staticValue` at depth 0 even when the next player has an immediate win, unanswerable two five completions, or a compulsory single-square block. Add a bounded optional `EclipseR12LeafThreats` window detector and at most two forced defensive plies at leaves; only exact immediate statuses are assigned mate scores. Other positions remain heuristic / unresolved; time+node caps still terminate the tree.
3. Both enhancements have default-off configuration in `VeilGomokuUnifiedSearch.Limits` and `experimentalR12=false` on the existing bridge. Only Governor's isolated native A/B runner may enable them. Original four persisted difficulty IDs, R4/R6/R8/V9 gates, independent Codex 48-tree source and ECLIPSE live no-hints invariant are unaffected.

## Local verification
- Strict Linux Swift 6.2.1 optimized memo unit test: 4,240 assertions pass, cached deterministic surrogate scores always agree with uncached; 1,915 synthetic repeated queries hit cache out of 2,700 repeated queries (not a real 48-tree speed measurement).
- Exact immediate five-completion proof: 270 assertions pass versus an independent exhaustive placement evaluator, including 80 positions from five Codex evaluation games and D4 reflections.
- Existing R11 external-data regression: five publicly generated Codex losing-trap positions × eight transforms × three predicates = 120 assertions pass. This validates prior R11's algorithm on these samples, not a separate full-game R12 win-rate.
- Advisory patch's all 10 frozen-source preimage hunks verified against PR209 source; live full module compilation and Xcode are NOT_RUN.

## Promotion gates
1. Governor must apply/select PR #209 trained R5 versus PR #193/#196 alternatives; coordinate V9 #199, R11 #210, and ECLIPSE UI #204.
2. Verify exact trained model SHA; apply R12 advisory patch **after** PR209, no direct edit of frozen model nodes.
3. Swift6/Xcode/XCTest and full production caller. Specifically confirm mutating ordered() / negamax tail parameters in integrated source.
4. A/B zero-mode parity: original 500/420 outcomes and model feature parity must not drift when both R12 flags disabled.
5. New equal-time, paired, color-swapped, held-out full games: R12 memo-only vs exact Codex frozen baseline; leaf-only vs baseline; both vs baseline (plus human/strong third-party tests). Monitor completed depth, elapsed p95, node count, tactical solve and winrate CI.
6. Real iPhone13/iPad Air4 thermal, background cancellation and memory. User sign-off before release.
