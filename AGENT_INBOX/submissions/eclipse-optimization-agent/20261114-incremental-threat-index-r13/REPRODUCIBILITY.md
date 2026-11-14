# Exact R13 reproduce and preimage
Source hash, `FILES/EclipseIncrementalThreatIndexR13.swift`: d0f364a6235b052e5c77539821e1f14e86afa734623b708fec05750066728635. SHA of full pinned Codex model: f89f234fcf2db59c52db70f1d2352576e727fd3c070fbb055ae59e10c391abfe (unchanged).

```bash
swiftc -O -swift-version 6 -warnings-as-errors \
  FILES/EclipseIncrementalThreatIndexR13.swift FILES/TESTS/ThreatIndexProperty.swift -o /tmp/eclipse_r13_prop
/tmp/eclipse_r13_prop
# R13_EXACT_PROPERTY_PASS checks=14691 iterations=850 forkComparisons=156
```

In the Owner ZIP also use `FILES/TESTS/IndependentRuleReference.swift` + `ForkIndexBench.swift` to reproduce 575-board/5750-update opponent-fork scan. Run twice after warmup; observed 15.72x/17.98x. `ThreatIndexBench.swift` separately compares entire immediate-win candidate scan and is roughly 1.14-1.44x including per-board cache initialization; do not conflate with fork scan. `FILES/TESTS/SimpleFixtures.swift` verifies expected exact two-sided four completion endpoints and reversible updates.

`FILES/VeilGomokuUnifiedSearchR13.swift` is the complete option-gated Codex kernel overlay; `PATCH_AFTER_CODEX_PR209.diff` contains the fully anchored differences against Codex native blob 950a43db5ce6ce0ceb9292c656c30f6e87dd9542. It needs Codex PR #209 selected and a Governor integration branch; it is **not** a main-ready patch. Full Xcode, coupled model compile and future game benchmark not run.
