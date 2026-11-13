# Proposal — post-validate PVS/VCF against mandatory native tactics

## Findings
Two V29.0 export packages contain 185 distinct recorded games (71 human wins, 39 AI wins, 75 unfinished). Their position dictionaries contain respectively 1,611 and 1,140 keys, with 8 overlapping hashes. Importing a single package via `AdaptiveBoardLearningStore.importPackage` replaces the existing DB; do not import both sequentially expecting a merge.

A concrete repeat loss begins `h112 a96 h81 a82 h110 a98 h111 a113 h109 a108 h95`. The repeatedly chosen AI square `83` leaves human fork-in-one points `67` and `123`. Blocking either 67 or 123 eliminates the pair of threats, confirmed by 5 copies of the same losing decision and the exact five-cell-window rule.

The controller code accepts the external engine if `trial.apply` succeeds. It does not enforce `GomokuBot`'s mandatory win, unique win-block, or R4 fork gate on that external move. External PVS also does not consume the human learning snapshot. The exported logs do not include engine-selection telemetry, so they cannot establish which engine made each historical move.

## Patch
`PATCH.diff` adds `GomokuBot.externalMovePassesTacticalGate`: native own win > unique opponent immediate win > R4 fork suppression, retaining double-threat counterattacks. Controller rejects nonconforming external suggestions and delegates to its existing native fallback. No change to protocol, storage, database schema, UI, signing, release, or version.

## Further training work
Investigate `PositionStat.actor` collisions after seat reversal, fix outcome-credit attribution (all plies currently inherit the entire game's ±2 result), add position-transposition/symmetry-aware repetition learning, and design idempotent validated merge imports. This must be reviewed separately as storage/history semantics are protected.

## Proof scope
Offline casebook has 70 examples where a chosen AI move preserved an opponent's preventable fork. 45 occurred in eventual human wins, 21 in eventual AI wins, 4 unfinished. These are tactical candidate diagnostics rather than proofs of whole-game loss; the 5 identical `83` examples are the strongest regression fixture. The remediation patch has NOT passed Apple XCTest.
