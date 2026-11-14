# ECLIPSE R9 implementation handoff

## Latest other-agent evidence
Draft PR #199 proposes 7 Gomoku tiers: original 4 + 棋圣(2×), 传奇(4×), 天元(6×) and a bounded forcing-four search. Its PR explicitly states multipliers are SEARCH TIME budgets, not Elo/winrate, and no product merge or iOS test has occurred. Main remains eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0.

## Actual local R9 changes (owner ZIP)
1. Preserve VeilLink native theme primitives: VeilAppearanceController, VeilTheme, .veilCard, original board palette; no separate ECLIPSE skin.
2. Display controller.boardDifficulty.title and controller.boardSearchMode.title; strip '· 2×/4×/6×' from small avatar badge, and show disclosure in TRACE.
3. Add a source-complete Foundation-only Swift telemetry session gate (staged in FILES here). It rejects old sessionID, turn, generation and boardFingerprint, recorded/demo data, impossible counters, reversed counters and stale clock. Public UI gets only depth/node totals at ≤8 Hz.
4. Harden R8 fair-play policy: recordedEngine no longer accepted as live; raw strategic explanation never reaches public UI. Active game never exposes candidates/PV/heatmap or dangerous squares.
5. Postgame only: separate read-only board reconstructs and verifies actually committed moves; never uses predicted variations.
6. Preview HTML now switches 5 original themes and 7 proposed difficulty labels; separate postgame replay canvas. Browser verified 320/390/768 widths.

## Code status
The owner ZIP includes all 3 Swift source files, the complete proposed 32.7KB 5-target product diff, tests, HTML and screenshot. This Github PR deliberately includes the **new telemetry gate source** and advisory add-file diff, not the full product diff. The other four targets remain owner-package review candidates until Governor conflict arbitration.

No current-main engine emits the required native telemetry; show '—' instead of invented nodes/depth. No iOS/Xcode build, no new playing strength, no release.
