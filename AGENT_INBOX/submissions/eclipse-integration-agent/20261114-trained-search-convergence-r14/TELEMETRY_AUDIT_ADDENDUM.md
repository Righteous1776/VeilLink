# R14 telemetry audit addendum — post-PR #215 only (2026-11-14)

**Canonical ECLIPSE merge proposal is GitHub draft PR #215**, branch `inbox/eclipse-governed-convergence-r14-20261114`. Do NOT duplicate its 21-file PVS/trained-model/tactical/UI proposed product patch. This addendum is a targeted review correction to **its own three already-staged product source blobs**, not an independent new kernel.

## Confirmed original-source evidence
- `FILES/Controller/LocalAIGameController.swift` blob `a1b84b2824bb68c14f445d9a55e0f29a86ef5412` invokes `GomokuBot.chooseMove` with `onExploredLine:` but never forwards the already-supported `onSearchTrace:` measured depth/node event callback.
- `FILES/UI/GameLobbyView.swift` blob `877a82d66a33e51ee01176c143fc6a2c26010cf7` passes `liveMetrics: nil` to expanded TRACE.
- `FILES/UI/VeilEclipseIdentityAndTrace.swift` blob `5f54343d13bae6d2a8a4ab9102827a15074ab7cd` hardcodes `liveMetrics: nil` inside the compact identity console.

## Corrective source staged in this separate task
- `PATCH_AFTER_PR215_TELEMETRY.diff`: **only** these 3 target files, 13 total hunks, approx 9.7 KB.
- `FILES/TELEMETRY/{LocalAIGameController_R14_Measured.swift, GameLobbyView_R14_Measured.swift, VeilEclipseIdentityAndTrace_R14_Measured.swift}`: complete proposed post-fix sources.
- `TESTS/EclipseR14MeasuredTelemetryTests.swift`: 6 proposed XCTest methods, **not yet executed**.

### Structural verification (executed)
All 13 hunks were replayed IN MEMORY against the three exact original staged blobs from #215. Every old-file line matched, and all three resulting source files were compared **byte-for-byte** with the corrected full file staged in this branch. **3/3 PASS, 13/13 hunks.** This does not establish Apple Swift6 compilation, Xcode/XCTest success or real-device correctness.

### Safety and event contract
The native `onSearchTrace` now sends event values only to a MainActor-owned `VeilEclipseTraceSessionGate`. Ticket binds session ID, moveCount, monotonically increased generation, and 15×15 board fingerprint. The gate refuses stale/foreign events, impossible or decreasing counters, demo/recorded origins, and >8Hz updates. It outputs *only* `VeilEclipseTracePolicy.LiveMetrics` containing measured completedDepth/visitedNodes; no PV, considered cells, threat paths, freeform reasoning or post-hoc example can flow into UI through this contract. End/restart/cancel/developer-teaching invalidates the gate; real last metrics may remain after finish for review.

### Deferred
Apple SDK Swift6 typechecking, Xcode/XCTest, complete checkout git apply --check after #215 product patch, actual live search telemetry, actor cancellation interleavings and performance on device. The authoring stage does **not** mean main was updated. This task's older `PATCH.diff` / `FILES/MERGED` predate #215 and should be treated as **superseded duplicate history**, not applied.

Integration Governor action: take the small `PATCH_AFTER_PR215_TELEMETRY.diff` correction as an append-only suggestion to canonical #215, not as a competing search engine. Rebase/redo the 13-hunk check if #215 source SHA changes.
