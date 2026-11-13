# VeilLink / Thinking Studio R3

## Source-confirmed problem
In main SHA eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0, LocalAIGameController chooses external PVS/VCF OR native GomokuBot; the external candidate only passes a legal placement check, not native R4/R8 force-block safety. Native already has immediate win/block, R8 double-threat forced win, R4 fork defense, historical learning, and bounded multi-ply opponent search. VeilOfflineGomokuEngine returns a single move and final score/nodes, not streaming depth/PV, and never reads the native learning snapshot. GameLobbyView displays a spinner without search proof.

## Required behavior (two nonnegotiables)
1. **Unify decision authority**, not just branding: native rules and exact tactical gates are mandatory, external PVS/VCF provides one or more candidates, shared root comparison is on one native-normalized score scale. Never directly combine incomparable JS/native scores. Candidate-level fusion first, shared transposition/search tree later.
2. **Show genuine computational evidence**, not AI-theater: scored candidate roots, measured nodes/depth, real PV if exposed, safety-veto reasons, history influence. JS depths currently unavailable; report this explicitly. No simulated code rain, fake ETA or fabricated progress percentages.

## Work packages
- **R3A, safety + candidate fusion**: Governor reconcile PR #186 R2 tactical-gate patch; consume PVS candidate as a root suggestion only. Native mandatory immediate win/block/fork/forced-win rules still govern. Use one overall time budget shared across both backends; avoid doubling latency. If no independent safe move exists, do not claim a safe defense.
- **R3B, native telemetry**: pass optional Sendable progress callback to GomokuBot root loop to record true evaluated root count, nodes and bestIndex. Dispatch to MainActor with generation/session ID. At most 5–10 UI updates per second. Keep the board unobscured, Reduce Motion and VoiceOver supported.
- **R3C, external instrumentation**: modify bundled JS engine source and JSC boundary to emit actual iterative-deepening / VCF/VCT results and principal variations, following engine licenses and respecting cancellation. Current JS chooseMove is blocking: no real-time progress without this work.
- **R4, deeper fusion**: unify search-tree and move evaluation / transposition proof objects; run equal-budget matches and real opponent tests. The native R8 forced-win teacher must not be displaced by weaker heuristic search.
- **R4 UI**: optional expandable Thinking Studio inspector, candidate heatmap/line paths, tactical reason timeline, completed-move replay. Only render data provided by authoritative source, not fake internal mental state.

## User-facing prototype available separately
A standalone HTML prototype was generated from 3 true R2 training cases: historical AI move 83 was not in R4 safe alternatives [67,123], another move 203 was unsafe versus [109,173], and move 130 was safe within [85,130,160]. This is OFFLINE HISTORICAL REPLAY, never a claim that live engine tracing is implemented.

## Validation baseline
Two verified V29 exports have 185 records, 156 distinct move sequences. R2 found 212 preventable fork positions and trained a teacher-imitation policy; that is not a measured AI win-rate increase. The history lacks engine origin per move; cannot blame specific PVS or native run from export alone.

## This PR's precise scope
This PR stages the requirements and a small truth-in-advertising UI label patch only; the full fusion/telemetry is NOT implemented, compiled or merged. It is submitted before implementation to avoid conflict with R2 and other UI game lanes.
