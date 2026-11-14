# R12: improve Codex's 48-tree trained ECLIPSE search at tactical horizons

## Genuine Codex baseline
At commit `d93e579` PR #209, Codex's frozen source-trained 48-tree / 1,348-node policy was fit on 1,848,616 D4-deduplicated board/action candidate examples (10,730 distinct training D4 boards). No raw data, binaries or model weights are copied here. On 500 paired trained-vs-untrained games it scored 57.25% at 1,000 nodes, 55.25% at 5,000 nodes and 59.5% on the 50ms target; deep paired interval crosses 50%. The other 420 games calibrate four original difficulty labels. All 920 are actual completed matches, not training games. No general Elo/superhuman claim.

## Independent new review
Replayed Codex's 920 published JSONL match records (including six-ply presets). All 28,737 actual engine decisions satisfy turn/index legality; 915 selected exact immediate wins, 4,534 selected unique mandatory blocks, with no misses of either category. There were 915 positions with two or more opponent completion cells where a block alone cannot save the position. This confirms ROOT tactical rules are working well; we should NOT sell another one-ply root fix as a strength breakthrough.

## New implementation
At `VeilGomokuUnifiedSearch.Searcher.negamax`, the frozen Codex implementation returned `staticValue` immediately when depth==0. That is a horizon limitation: it can miss side-to-move winning completions and unique forced blocks just beyond the search depth. R12 introduces an independent 572-window exact tactical classifier:
- side-to-move immediate five is recognized as a tactical win;
- two DISTINCT opponent immediate-five completions are recognized as a forced loss unless the mover can win first;
- a unique opponent five-completion square triggers a **one-ply compulsory defense extension** followed by a quiet heuristic score; the block itself is not misreported as a win;
- quiet leaves continue using Codex's original static evaluator unchanged.
The option `Limits.r12HorizonQuiescence` defaults FALSE until Governor-controlled integration benchmarks authorize it. The learned 48 trees, fitted numeric score, history, TT/VCF, mandatory root gates and search ordering are not replaced; only a bounded leaf horizon is extended.

## Evidence and limits
The new helper compiled with Linux Swift 6.2.1 using `-swift-version 6 -warnings-as-errors -O`, and 1,607 assertions passed, including independent brute-force winning-cell equivalence, 32 symmetry tests, 500 seeded probes and three positions extracted from actual Codex held-out evaluation logs. After those evaluation logs informed R12 design, they are **diagnostic regressions, not pristine post-R12 holdout**. No full kernel build or game-vs-game tournament was run. This is a testable candidate, not demonstrated playing-strength gain.

## Application order
Governor selects one R5 kernel, accepts Codex PR #209 six-file trained model on integration branch, then applies R12 overlay `PATCH.diff` to its exact preimage. Enable flag only in an A/B arena experiment; after iOS CI, actual equal-budget matches and safe power benchmarks, consider rollout. Maintain original four difficulty raw names; coordinate any extra 2x/4x/6x tiers with V9 #199. Never merge directly to main.
