# Source / Evidence Lock — ECLIPSE R14

GitHub main: `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`.

- PR #209 exact trained source `VeilGomokuUnifiedSearch.swift` blob `950a43db5ce6ce0ceb9292c656c30f6e87dd9542`; frozen 48-tree model `EclipseTrainedOrdering.swift` blob `4e73cc1910820324487d9350194cfb5562a8439f`. Source reported frozen model SHA-256 `f89f234fcf2db59c52db70f1d2352576e727fd3c070fbb055ae59e10c391abfe`.
- PR #213 overlay baseline #209 exact source, patch `FILES/Native/R12_KERNEL_OVERLAY.diff`; full agent overlay verified identical after 2 hunks; `EclipseHorizonQuiescenceR12.swift` blob `0eb6e94e37052a19cc2b96bc1a82463f6fadfc22`.
- PR #214 `PATCH_AFTER_CODEX_PR209.diff`; full agent overlay verified identical after 6 hunks; `EclipseIncrementalThreatIndexR13.swift` blob `a8241383c28422ac75542caaa7b5f684c01c39bb`. Both PRs use independent source versions, so R14 rebases their non-overlapping changes and merges Limits flag declarations.
- PR #208 canonical ECLIPSE visual/history source copied exactly, not applied as second parallel UI engine. R14 connects optional `onExploredLine` from native root/negamax and incumbent fallback to exact-match TraceStore.
- PR #199 proposed uncalibrated 7-tier multiplier labels; PR #206 independent all-defender VCT; PR #207 shadow strategy; PR #210 countertrap oracle; PR #211 alternate memo + leaf; PR #212 competing horizon — all reviewed for collisions and deliberately held.
- The frozen model, R12 helper and R13 index in the new Inbox are **byte-identical** to their source PRs (GitHub blob SHA equality).
- Final `PATCH.diff` (294,010 UTF-8 characters) has 21 unique destinations, 46 hunks. All 4 existing-file changes applied in-memory on current main with exact context, byte-exact outputs. All 17 add-file chunks verified byte-exact against staged source.
- None of these findings proves merged Xcode build, final playing strength or app release.

Actual staged source paths: `FILES/Native`, `FILES/Controller`, `FILES/UI`, `FILES/Tests`; full product replacement instructions in `PATCH.diff`.
