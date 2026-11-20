# V30 ECLIPSE R17.2 — owner-constrained semantic review

[INTEGRATION-GOVERNOR] Reviewed PR #234 artifacts against V29.2 Build69 head and owner's 2026-11-14 / 2026-11-20 explicit corrections.

## Important outcome
**DO NOT wholesale merge R17_ADVISORY.patch or the 10 FILES/ copies.**
They depend on an R16/PR#220 hybrid, overwrite real Build69 thinking-slider settings and diagnostics,
reintroduce the exact lower "ECLIPSE / 实测仪表" card and the board-impact ripple the owner rejected.

## Accepted and implemented in this isolated branch
- Accurate stopwatch using the existing, upper black ECLIPSE robot console and `actualSearchStartedAt`.
- Periodic low-load updates at 2 Hz while visible, 1 Hz when accessibility reduced motion or Low Power is active, and slower while scene is inactive.
- Replace synthetic fast-moving terminal stream with honest `vis.compute ()`, preserve original orange theme, compact dimensions, no touch interception.
- Keep existing real measured depth/node metadata and its truthful no-metrics fallback.
- Preserve V29.2 Build69 1–10 slider, user-controlled time cutoff, finite node/depth safety, local-game cancel.
- Add script `verify-v30-eclipse-owner-regressions.py`; can run in the final consolidated preflight.

## Rejected/conflicting R17.2 elements
- Lower standalone telemetry dashboard and extra 4-stat panel: explicitly rejected by owner.
- Mechanical board landing ring/pulse: explicitly rejected by owner.
- Time-cap, `EclipseAdvancedOptions` engine copies: R16-era API overwrites Build69 real slider; not compatible without hand-selected migration.
- Any fake node counts, search completion estimates, decorative clock-cycle LEDs: not proof of calculation.
- Global orange/green palette overrides: original theme remains source of truth.

## Pending
Compile and iPhone snapshot acceptance are not yet done. This branch intentionally has
no PR and did not run GitHub Actions; it is not part of any published V30 IPA.
