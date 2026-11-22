# Source-based proposal — replace JavaScriptCore Gomoku engine with native compiled Swift

## Evidence in current main
- `VeilLink/Resources/GomokuEngineV2/engine.js`: PVS, VCF, **simplified VCT**, Zobrist transposition table, iterative deepening, precomputed 3^9 pattern table. Freestyle-specific patches.
- `VeilLink/Resources/GomokuEngineV2/PROVENANCE.md`: origin `https://github.com/zv38/gomoku-engine`; upstream pinned commit `0d8d6d960ab5d5f89a7219b8b7fe327ebbda4440`, author workbuddy 2026, MIT elected. Source described research-quality/experimental and OFF by default.
- `VeilOfflineGomokuEngine.swift` invokes JavaScriptCore and currently emits only a final move/score/nodes. It does not consume historical learning/formation weights.
- `LocalAIGameController` chooses external OR native, while `GomokuBot` already contains mandatory win/block, R4/R6/R8 native tactics and learning.

## Owner direction
There should be **ONE built-in native Gomoku decision kernel**. PVS/VCF/VCT are search algorithms, not AI model weights; migrate and improve code inside native Swift while preserving learned statistics and shape adaptation. Remove the independent JavaScriptCore engine, its obsolete toggle and bundled engine.js **only after** tests prove feature parity and safety.

## Completed in separate, owner-delivered offline artifact
- 498-line standalone Swift module `GomokuNativePVSCore.swift`, SHA-256 `5ef02d1128d584046475b014a4f47589377dd19123765d8241b164a19fec1b39`.
- Features: freestlye 15x15, own win/opponent block, double-win tactical proof, root opponent fork exclusion, bounded VCF, iterative-deepening PVS, deterministic Zobrist and bounded TT, timeout fallback, authentic progress events (completed depth/node count/PV).
- Swift 6.2.1 Linux `-swift-version 6 -warnings-as-errors -O` built and executed.
- Private replay of 212 actual historical R2 fork-risk positions: first candidate engine passed 203/212; nine VCF suggestions skipped native safety, corrected to 212/212 with mandatory VCF root veto.
- 212 board positions × four rotations: 848/848 safe-choice regressions. NOT 848 independent games or proof of stronger overall playing.
- Four named tactical smoke tests passed, invalid board inputs rejected.
- Standalone `PATCH.diff` in owner ZIP (adds only the new source file) passed `git apply --check`.
- No iOS build, XCTest, production wiring, model-weight training or playing win-rate verification occurred.

## Core architectural target
```
GomokuState (single source of board truth)
   -> mandatory native R4/R6/R8 tactical proof
   -> native PVS/VCF/VCT candidate and PV search
   -> shared evaluation + learned preferences + native TT
   -> final root tactical safety validation
   -> move + truthful Thinking Studio telemetry
```

Keep internal modules if useful; do not keep two independent final move arbiters.

## Integration windows / retirement gates
1. Audit code/LICENSE/provenance, merge R2 safety gate once and resolve #186/#187 overlaps.
2. Stage native source in dedicated integration branch from user-delivered ZIP, preserve upstream MIT copyright.
3. Integrate native search *only after* GomokuBot mandatory tactics, with learning/formation preserved. Do not compare different scoring-unit numeric values.
4. Port and fully verify VCT against **all relevant defensive responses**, and test JS pattern table parity; upstream VCT can produce heuristic non-proven wins.
5. Add search event emission from genuine iterations; JS currently has no streaming interface.
6. Run original 212 + symmetry + random seed tests, real iOS Swift/XCTest and equal-time matched playing strength/thermal benchmarks.
7. Only then remove `VeilOfflineGomokuEngine.swift`, `engine.js`, JS folder in `project.yml`, and obsolete external engine toggle. KEEP license attribution and legacy settings migration.
8. Never remove users' training files or alter backup/import semantics during engine migration.

## Validation status
**Research prototype complete; code integration and release incomplete.** No direct product-tree write or IPA authorized for this Inbox agent.
