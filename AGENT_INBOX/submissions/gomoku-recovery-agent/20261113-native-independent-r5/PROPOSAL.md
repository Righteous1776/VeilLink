# VeilLink Native Intelligence — R5 independent implementation

## Goal

One native Swift Gomoku decision engine. Incorporate known public-domain algorithmic ideas (principal-variation search, forcing-four proof, Zobrist hashing, transposition table, iterative deepening, tactical root defense), not third-party software expression. Existing VeilLink R4/R6/R8 tactical gates and learning remain authoritative. Do not erase original MIT notices while any old licensed code is shipped.

## Implemented (actual source delivered in FILES + PATCH.diff)

- `VeilGomokuUnifiedSearch.swift` pure Foundation/Swift, explicit 15x15 board, deterministic hashing, bounded PVS search, exact geometric root fork checks, two independent five-completion forced wins, limited *sound* forcing-four proof with opponent immediate winning replies checked, static line-window evaluation, deterministic fallback, and genuine completed-depth/PV/node-count events.
- `VeilGomokuUnifiedBridge.swift` converts immutable current `GomokuState` to search position and passes current learning/formation root biases. It never imports/mutates user training or writes storage. The caller must pass roots that survived incumbent native win/block/R4/R8 gates.
- Does NOT claim a proven general VCT solver. VCT and shared search tree can be added later only if every relevant opponent defense is verified. There is NO JS runtime/API/network dependency in these two new source files.
- PVS/VCF are executable algorithms, not model weights; model files are unchanged. This is an independent rewrite, not a transliteration of existing engine.js.

## Actual measured local results

- `swiftc 6.2.1 -swift-version 6 -warnings-as-errors -O` compile succeeds for standalone search and for the bridge against matching interface stubs; strict compiler is Linux, **not iOS SDK**.
- Deterministic center, own-five, unique opponent-five block, own-win-over-block, emitted stage consistency and invalid-input checks all pass.
- On **212 historic fork-risk positions**, all 8 dihedral board symmetries (rotations/reflections) selected a root within the original R4-style safe-set: 1696/1696 passes. Symmetries are correlated, do not imply 1696 independent games.
- 30 midgame historical state samples, depth limit 5 and 160ms deadline: 30/30 legal choices, average 82ms, average completed depth 3.47; CPU Linux benchmark, NOT a real-device timing guarantee.
- One important correction during implementation: a position had only one valid forcing counterattack (#8), despite three active opponent fork opportunities. Added verified own-double-win check before filtering risk, yielding full 1696/1696.

## Precise integration order

1. Governor reviews R2 PR #186 R4/R8 safety gate and R3 PR #187 thinking telemetry overlaps. Keep one authoritative move decision path.
2. Add the two new files from `PATCH.diff` to a separate integration branch and compile with Xcode/iOS SDK.
3. In `GomokuBot.chooseMove`, keep preexisting immediate own-win, opponent-five block, R8 forced win and R4 safeCandidates, plus the current learning/formation ranked roots. **After** creating `rankedRoots`, call `VeilGomokuUnifiedBridge.chooseMove` with `permittedRoots: rankedRoots.map { $0.0 }`; on timeout/failure, fall back to old native search. Do not allow PVS/VCF to override the tactical gates.
4. Route the controller into the unified native decision; retain UserDefaults compatibility while removing the old external-engine UI label/toggle in a separate reviewed cutover. Retire previous JavaScriptCore logic only after passing tests.
5. Connect actual `Trace` events to Thinking Studio on MainActor using cancellable session-generation IDs. Never report invented thinking code/ETA, and throttle UI update frequency.
6. Run iOS CI, XCTest (including historical fork scenarios), equal-time engine match tournaments, persisted-history migration validation, and device battery/thermal profiling.
7. **Only after verified parity**, remove `VeilOfflineGomokuEngine.swift`, old `engine.js` folder reference in `project.yml`, `GomokuEngineV2` bundle and stale UI toggle. Preserve relevant former MIT notice while any of its code remains present; otherwise stop shipping the obsolete dependency. Do not rewrite repository git history.

## Provenance/rights

This R5 authored code uses standard algorithmic descriptions; no code was copied from the old JS source or R4 Swift prototype. Its independently developed code can use ZeoStudio/VeilLink project identity. A source-level audit remains part of the cutover gate; removing third-party code does not permit erasing its notice from copies still containing that code.

## Status

**R5 search + bridge = implemented and locally tested.** Product integration, iOS verification, legacy deletion, and real stronger-than-baseline win rate remain open. Never claim build 100%.
