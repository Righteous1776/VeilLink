# R13 overlap and risks
- Codex model/trained kernel #209 is still a Draft INBOX proposal, not in V29 main. Its two fit-policy tree model/bridge are NOT copied or retrained by R13.
- R12 #211/#212 modifies the SAME Codex search kernel; R13 post-Codex patch and R12 overlays are not directly stackable. Governor must rebase/reconcile by source diff/compile, not overwrite proposals.
- R11 #210 has a separate exact fork gate; avoid duplicating expensive root scans or conflicting proof labels. V9 #199 controls proposed additional 2x/4x/6x tiers; base Codex #209 validates four only.
- Incremental cache synchronization could diverge on unexpected placement/undo paths; integration overlay has fail-to-scan fallback. Full engine fuzz/CI is a gate.
- Geometric fork definition counts independent immediate-five completions; a fork threat is NOT a general VCT or forced victory when the opponent has its own immediately winning counterattack.
- Original native `forkCells` does not account for pre-existing winning completions; R13 is semantically more complete. OFF/ON parity is only expected on quiet positions, while any other change needs independent tactical review.
- Isolated Linux microbench 15–18x is not a whole-engine speedup and says nothing alone about win rate. Tests use synthetic positions, not the complete Codex 920-game holdout; evaluated matches cannot be reused as untouched holdout.
- Swift Array storage / copy-on-write, Int16 counters, power/performance on iOS and stale GameState must be tested. Avoid cross-task global caches/extra memory pressure and app cancellation issues.
- No product main, release, signing, workflow_dispatch, version, database, model weights or user data mutated.
