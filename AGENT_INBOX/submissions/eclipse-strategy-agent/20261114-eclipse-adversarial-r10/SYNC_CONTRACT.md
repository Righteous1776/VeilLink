# Single-clock ECLIPSE/Gomoku handshake
Dependencies: main `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`; native R5 PR #193; seven-tier V9 PR #199; UI telemetry R9 PR #204. The Governor owns order and must reconcile #196 R5 conflict.

1. Incumbent GomokuState + own-win/block + R8 proof + R4 fork-safety authorizes `safeRoots`; existing learning/formation only provides bounded root preferences.
2. V9 difficulty/mode establishes a single monotonic turn deadline (FULL Master 950ms, new 2x/4x/6x 1900/3800/5700ms; ECONOMY solely by user choice).
3. `VeilEclipseComputeContractR10.allocate` splits optional stages 20% V9 forcing proof / 65% R5 PVS / 15% R10 shadow plan, without double spending. Mandatory safety scans are never skipped due to optional budget.
4. R10 receives only validated `GomokuState` cells, `safeRoots`, observed opponent move history, learning-provided predicted reply candidates and bounded preferences. No neural runtime, new save schema, internet, or A10 authority.
5. Before representative equal-time matches are proven, R10 **may not override** R5/V9's chosen move. Failing/expired R10 results are ignored, never backfilled as fake progress.
6. R9 gate accepts only `measuredNative` depth/nodes under exact match session+turn+board fingerprint; no raw PV, trap map, candidate/reply arrays or thought text to live board. Actual postgame move journal is separate.
7. Controller revalidates candidate against `GomokuState.apply`; generation/turn ticket invalidated on new game, undo, resignation or cancellation.

Advisory integration code and complete source patch are in the owner ZIP, not this review-only Inbox branch.
