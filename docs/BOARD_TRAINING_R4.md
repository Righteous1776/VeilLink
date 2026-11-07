# BOARD-TRAINING R4 — Real tactics, tiny on-device model

## Source and governance
- Owner instruction: continue genuine training, 80% Gomoku / 20% Xiangqi. Branch stacked on **PR #170 / R3**, not merged main. The R2 overlap on retained negative feedback is explicitly arbitrated through Issue #6 R4 addendum. Do not cherry-pick PR #169 wholesale.
- All training input: originally provided `.vltrain.json` exports; **5,141** complete Gomoku native games had **276** distinct complete move sequences; human Gomoku 81 games, human Xiangqi 8 games. No invented master labels, actual chess match results, or production win-rate statistics.
- No raw user gameplay histories, source private archives, opaque model binaries or prebuilt releases are committed to GitHub.

## Gomoku: R4 safety-curriculum and retained training
1. The R4 supervised counterfork dataset was derived from **2,484** unique, replayed, nonforced real-board positions. Every hypothetical legal candidate was labeled using *exact* opponent next-ply fork-cell counts, not by pretending an imagined move was played. 49,716 candidate comparisons. 1,980 train/504 heldout by board hash.
2. **Previous basic root-static selection:** 406/504 holdout positions had zero opponent forks left after the selected candidate.
3. **R4 learned reranker:** 437/504 holdout positions had zero opponent forks left. These are **same-candidate-set, one-step tactical results**, NOT full native match win rates. Of 504 cases, 437 even contained a fully safe action.
4. Model is a linear ridge-ranked policy; the 14 symmetric positional features were algebraically collapsed to 7 unique features. Numeric parity of 2,195 real feature-vector cases checked (max absolute floating discrepancy ~4.44e-16). Coefficients remain embedded as human-readable source literals (no model file or runtime dependency).
5. To protect against model-ranking failure, R4 adds a separately verifiable bounded-exact counterfork rule. It runs after immediate win and immediate block, detects opponent fork-in-one via actual contiguous five-cell windows; when full defenses exist, keep those defenses PLUS any forcing move with at least TWO distinct next-turn immediate five wins. This protects offensive initiative; if no full defense or forced double-win attack exists, keep all candidates rather than pretending a proof of safety.
6. R4 learned defensive bonus is bounded to [-48000,+48000] and only computed for a detected fork threat. Ordinary positions use the existing native bot and R3 model unchanged.
7. Independent, compiled **Swift 6.2.1 x86_64 Linux -O** scorer checked **250 authentic boards, 2,445 baseline/virtual-block positions** against an independent NumPy rules implementation; **0 mismatches**. Separate attack+defence Swift parity validated 4,640 decisions against independent rules (0 mismatches, plus positive forcing-counterattack fixture). First scan elapsed ~0.023s per full 2,445 tests (~9.5 microseconds/call Linux); 10x batch ~0.206s. This is **NOT iPhone 7 benchmark evidence**.
8. Actual in-product GomokuBot XCTest checks the known intersecting-threat escape under LEGACY-COMPACT search budget. A second synthetic two-player fork fixture checks that forcing offensive counterattacks are preserved rather than filtered out.

## Xiangqi: trained R3 policy, more efficient execution
1. Retains exact 21-feature supervised R3 numeric coefficients derived from 371 authentic positions and 12,692 legal candidates. It is move-order imitation, not chess expert or engine improvement proof.
2. Removes an array-of-21 `Double` allocation plus vector-of-21 model weights on **each legal move**. Equivalent scalar score inlined in `XiangqiBot`. Offline 12,692 move parity check found 0 integer score mismatches. XCTest asserts four independent initial-board scores.
3. Swift 6.2.1 x86_64 Linux -O arithmetic microbenchmark, 600,000 synthetic moves: 0.0407s array implementation vs 0.00510s scalar implementation (about 8x for **only this scoring function**). Not evidence of whole XiangqiBot 8x acceleration on iPhone 7.
4. R3 feature `soldier_over_river` was named imprecisely in the training corpus. The R4 optimization intentionally keeps that indicator **unchanged** to preserve parity, pending a separately trained/corrected policy; do not silently switch semantics of a trained input.

## Persistent learning and releases
- R4 additionally brings the separately approved R2 fix to `AdaptiveBoardLearning.snapshot()`: negative AI outcome reward remains negative instead of `max(0,raw)` erasing failure evidence. No DB schema changes. XCTest verifies negative feedback persists through reload for **both** Gomoku and Xiangqi.
- Source branch updates are not evidence of installed IPA. No remote API, model downloads, packaging, signing, `workflow_dispatch`, `main` merge or firmware changes were performed by this lane.
- Xcode iOS 15 simulator build, XCTest and paired/side-swapped native match A/B must complete before accepting model strength claims. The actual iPhone 7 (A10/iOS 15.8.3) must be profiled for execution time and heap/memory **before release**.
- V28 `.vltrain` import currently **replaces the destination archive**, not safe-merge. Never overwrite newer user training archives with offline data without backup/merge gate.

## Acceptance gates
[ ] iOS simulator build and XCTest pass on stacked branch
[ ] at least 200 paired native games with identical openings, randomized A/B assignment and side reversal; record W/D/L, wall-clock and memory
[ ] mandatory five-in-row win/block unaffected; zero illegal moves or fake outcomes
[ ] iPhone 7 profile: reasonable latency and no crashes/OOM
[ ] explicit Integration Governor decision merging R2/R3/R4 concepts; no blind stacking into main

**Status at authoring:** R2 PR #169 and R3 PR #170 passed GitHub iOS CI but remained draft/unmerged; R4 CI was not yet confirmed.