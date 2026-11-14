# R10 Risks / overlap

1. **Storage protected surface:** adds independent ApplicationSupport JSON per match; Governor must validate data durability, crash behavior, file protection and backups before product merge. A filesystem write can still fail (disk full, protection), so the controller exposes explicit archive warnings; never promise guaranteed persistence in those cases.
2. **Controller/UI conflicts:** overlaps drafts #193/#196 native PVS, #199 V9 seven-tier forcing search, #203 R8 themed identity, #204 R9 telemetry. Governor arbitrates. Do NOT apply competing controller patches blindly.
3. **Active-game advice leak:** board streaks are strictly synthetic non-spatial decorative motion, with no semantic colors, threat/candidate coords, actual line graph, or clickable squares. They must not be merged with R6's superseded tactical heatmap idea.
4. **No false thinking:** high-density animation grows with elapsed seconds; this is a visual motif, not proof of more calculations. Do not add `Task.sleep` delays to extend animation and do not expose fabricated PVS depth/nodes.
5. **Current-match migration:** already lost overwritten match histories cannot be recovered. App can only archive existing current game and new games after R10 installation.
6. **Performance:** `Canvas` up to 24fps with 72–170 short streaks (low-power 12fps ≤80) should be benchmarked on target device; the existing real game board and its drag/tap hit targets remain authoritative.
7. **Fair-play vs history:** archived spatial replays locked while current game is active. This is intentionally stricter than generic history browser UX; Owner can change it through separate reviewed fair-play design.
8. **Incomplete archive on kill:** per-move snapshots remain `playing` until a completion/interruption marker is saved. Restore should reconcile a final board to actual result, never overwrite conflicting finalized entries.
9. **Visual style:** R10 must use `VeilAppearanceController`, `VeilTheme`, `.veilCard()`, original board geometry and theme-aware dark/light. Never revert to bespoke blue-cyan ECLIPSE branding.
10. **Tests:** Linux Foundation compile and SwiftUI syntax parse do NOT establish Apple SDK typecheck or iOS build. Synthetic git preflight does NOT establish full-main applicability. No release or IPA authority.

11. **Crash-window / continuity:** JSON bounds and clock rollback are now handled. A crash between deleting the latest-match journal and finalizing an interrupted historical entry can leave a saved historical match temporarily labeled playing; a future orphan-status reconciliation should be reviewed before shipping.

## R11 additional risks / other-lane overlap
- This PR #208 is the SINGLE UI/history visualizer artifact; no second UI proposal branch created. See `R11_REFERENCE_AND_DEDUP.md` for other Agent PR #199/#206/#207/#209/#210 and older UI #203/#204 dependency/conflict ledger.
- Decorative animated `vis.*` strings must **never be presented as actual internal AI reasoning/code**. Real measured fields are separate and currently unavailable in deployed main.
- Black rectangular terminal is embedded in original .veilCard; avoid replacing the VeilLink theme or hiding the 15×15 board under dense UI.
- R10 board abstract field and R11 console are intentionally cosmetic and take no search-point/PV information. They must not become covert hints.
- Two separate animation Timelines may increase GPU use: normal ≤24Hz, low power ≤9Hz console; Reduce Motion pauses updates. Apple-device energy/thermal validation outstanding.
- Complete combined product PATCH.diff is still not applied to full repository/Xcode; proposal only under governance.

## R12 actual-search UI risks
- Earlier R7/R8 forbade revealing search point coordinates during active human play. Owner now explicitly requests real path visualization. Narrow exception: ONLY while native AI is calculating and human cannot act; clear immediately after AI move, cancellation, match change, disabled toggle, or stale session; no active-human replay.
- This R12 patch overlaps another Agent's GomokuBot/LocalAIGameController patches (#193/#196/#199/#207/#209/#210) and gameplay UI #208 itself. **No cross-agent edits/merge performed**; Governor must choose callback API/ordering and re-run tactical safety.
- The optional JavaScriptCore engine currently cannot report 3ply explored-line callbacks. No true events = no ghost stones. Do not animate fabricated points to fill silence.
- Even correct hypothetical lines could indirectly reveal AI exploration to a watching human. Default OFF, user-controlled; never highlight strength, safest move or probabilities, and never persist active analysis.
- UI now paints translucent virtual stones on grid, so accessibility must clearly distinguish them from real stones; no hit-target interception; watch runtime/thermal.
- Current hunk validation is model-side exact-main preimage checking, not Xcode, XCTest or IPA. No direct product or main changes.
