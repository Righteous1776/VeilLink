# ECLIPSE R10: Strategy beyond the next move

## Grounded integration
V29 main (eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0) has only incumbent Gomoku R4/R6/R8. PR #193 is actual native R5 PVS/VCF kernel and learning bridge, but is still a review candidate. PR #199 V9 is a seven-tier, bounded forcing-four proof proposal. PR #204 ECLIPSE R9 is a no-hints UI/telemetry proposal. None of these is an integrated trained ECLIPSE neural model. Full R10 strategy source is in the separately delivered, SHA-pinned owner ZIP listed in MANIFEST.

## Implemented R10 candidate
- New standalone Swift 6 `VeilEclipseStrategicPlannerR10`: 15x15 freestyle position validation including side-to-move parity/no existing five, deterministic adversarial negamax/alpha-beta, iterative deepening, bounded exact-state FNV-64 cache, node/time caps, exact own-win and single forced-block gates, and tactical replies that survive beam width pruning.
- **Plan/Counterplan**: scores candidate plans under adversarial human replies; records the worst-case private search variation; classifies initiative, counterplay and consolidation from heuristic outcomes. Recent observed human moves and existing learned predicted reply candidates influence search *ordering*, never prove future behavior or force an opponent blunder.
- Legal-root containment: only roots already verified by incumbent R4/R8/V9 gates are permitted. Partial root iterations are discarded; hard timeout returns a legally vetted fallback with depth 0, never a false forced win.
- Proposed new `VeilEclipseComputeContractR10.swift` is in FILES and in complete owner ZIP. Shared V9 full-mode budget Master/2x/4x/6x is 950/1900/3800/5700ms; default optional stage split V9 forced-proof 20%, R5 native PVS 65%, R10 *shadow* planning 15%. Mandatory exact own-win/opponent-win/R4/R8 checks remain outside the optional split.
- No-live-hints: R10 private variations, candidate rankings, opponent predictions and coordinates must not reach a live match UI. R9 accepts only verified native depth/node aggregates, session/turn fingerprint and 8Hz throttle. Postgame replay is actual committed moves only.

## Evidence
Swift 6.2.1 Linux `-swift-version 6 -warnings-as-errors -O` PASS; 59 local planner checks + 18 compute-allocation checks PASS, including 16 board symmetries, 32 seeded legal-root midgames, response-to-bait fixture, bounded-budget fallback, hard-block and self-win. These are *not* win-rate/Elo tests. No 6x skill or superhuman strength claim.

## Formal decision
Integration Governor must reconcile #193/#196 R5 alternatives and #199/#204 overlaps, compile full source with actual iOS SDK, run safety properties, then test equal-time color-swapped head-to-head and physical devices before allowing R10 to override the R5 choice. Until then it is shadow-only.
