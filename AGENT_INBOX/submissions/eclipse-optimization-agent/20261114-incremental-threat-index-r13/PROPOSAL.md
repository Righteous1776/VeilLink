# R13: trade repeated geometric scans for deeper useful search
## Finding
Codex trained ECLIPSE #209 (1,848,616 D4-deduplicated **board+candidate** training records, not games) uses the same 48 fitted Swift trees in the selected kernel. Its mandatory safety and VCF/PVS search repeatedly enumerates immediate five-cell wins and next-turn fork threats. At many nodes the 15x15 geometry is almost unchanged; 572 five-cell windows can be incrementally tracked.

## Exact implementation
- `EclipseIncrementalThreatIndexR13` precomputes 572 five-cell windows, their per-cell reverse adjacency and two per-side completion counters.
- Each legal stone placement and precise undo touches only the local five-cell windows; `winsImmediately` becomes O(1) per queried cell.
- `forkSquares` enumerates exact TWO DISTINCT next-turn five-completion squares with cached counts; it also accounts for EXISTING immediate-five completion points that old three-stones/two-holes logic could overlook. No phantom proof from duplicate overlapping windows.
- Complete pinned Codex R10 native kernel overlay in `FILES/VeilGomokuUnifiedSearchR13.swift` adds `Limits.r13IncrementalThreatIndexEnabled = false` and optional calls inside Searcher.place/unplace, immediateWins and forkCells. A failed update turns off optimization and falls back to original scans. All trained-tree ranking, PVS search budgets, root mandatory safety, returned rule labels, history and existing four tiers remain unmodified.
- This is reusable alongside V9 #199 and R12 leaf extension #212, but do not mechanically stack multiple kernel overlays. Governor must consolidate changes and validate the combined budget.
- There is **no new data fitting**, no model-weights change, no stored-game/schema change, and no evidence of a 16x whole-engine speedup.

## Results
Independent brute-force move-placement reference compared against real incremental state for 850 deterministic placement/undo steps (14,691 assertions), 156 exact opponent-fork comparisons and both colors. PASS.
An additional *paired* Linux -O microbenchmark on 575 quiet synthetic 25-stone positions performed 5,750 hypothetical root placements, exact opponent fork checks and undos. Old R5 geometric full scan vs indexed cache (including initialization/update) gave identical 2,045 fork-count totals, 320.4 vs 20.4ms (15.72x) and 341.1 vs 19.0ms (17.98x). These numbers are only about this isolated tactical scan and are not iOS timing/Elo/skill uplift.
