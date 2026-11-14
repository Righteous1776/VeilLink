# ECLIPSE R14 — one native decision engine, one visualizer, one game archive

## Actually merged source delivered here

This is NOT a summary of other agents: `FILES/MERGED/` includes actual complete UTF-8 Swift for all 18 app-source targets (4 product replacements and 14 new products) plus 3 proposed XCTest files. `PATCH.diff` reconstructs the same 21 product paths against main eb487a19.

Provenance, precise use:
- **#209 Codex training**: frozen `EclipseTrainedOrdering.swift` source copied **byte-identically** (Git blob `4e73cc1910820324487d9350194cfb5562a8439f`). One 48-tree fitted policy is used for **candidate ordering only**, never proof or Elo. The author's measured **500 paired games + 420 four-tier calibration games** are historical results of the unmodified #209 engine, NOT new tests of R14.
- **#213 R12 tactical horizon**: select one bounded all-window depth-zero quiescence implementation `EclipseHorizonQuiescenceR12.swift` plus anchored trained kernel overlay. Flag `r12HorizonQuiescence = false` by default. Do not also add the competing overlapping #211/#212 leaf strategies.
- **#214 R13 threats**: incremental exact 15x15 winning-square/fork threat index `EclipseIncrementalThreatIndexR13.swift`, with reversible placement; its 6 kernel hunks merged against R12 overlay: 5 unique exact replacements, 1 explicit `Limits` conflict resolution. Flag `r13IncrementalThreatIndexEnabled = false` by default until iOS/tournaments.
- **#208 ECLIPSE UI/history**: one copy of original-theme .veilCard/VeilTheme identity & TRACE, real observed search root→reply→continuation lines, opt-in advanced-setting visualization default OFF, strict session tokens, black decorative code console clearly labeled non-genuine, postgame-only actual-move replay, per-match JSON archive independent of latest resume slot.

## One unified move path
```
LocalAIGameController.selectAIMove
  -> GomokuBot mandatory own-five, opponent-five, R8 proof, R4/R6 safety
  -> verified allowed roots with original learned/history/formation bonuses
  -> VeilGomokuUnifiedBridge normalized safe-root priorities
  -> VeilGomokuUnifiedSearch trained PVS + VCF (single budget)
      optional R12 leaf extension OFF; optional R13 threat index OFF
  -> legal move validated again by controller
  -> real SearchTraceStore branch 1–3 plies (only if user opts in)
  -> sanitized measured depth/nodes on ECLIPSE TRACE
  -> archived committed move per session, postgame replay
```

Critical conflict resolution: #209's controller and #208 share 15 integration hunks. 14 applied exactly; the lone AI-selection conflict was rewritten into ONE native decision call. Legacy `VeilOfflineGomokuEngine` is no longer invoked by R14's Gomoku controller. Existing old JS resource and third-party legal notice stay bundled until Governor verifies full feature parity and can safely retire them. Never hide a still-applicable code license.

Optional root/reply/continuation observation is @Sendable and does not affect score or node-budget limits. Searcher throttles branch reporting to no more than ~20Hz, uses actual board-place events, and supports legitimate deepening to 3 plies of the same root. UI trace gate rejects stale session/turn/cancelled messages. On the AI selection path, internal PV and candidate coordinates do not reach public status labels. They reach only an explicitly enabled temporary board Canvas, which is removed on completion.

R14 GameLobbyView preserves VeilLink's native skins (Veil 原生, Apple Soft, 拟物仪器, 浮屿, optional 白描) and replaces the misleading external PVS toggle with noninteractive 'ECLIPSE · 原生训练引擎'. Existing stored external-toggle value is retained for compatibility but ignored by native decision; no destructive user-settings migration.

## What was intentionally *not* merged
- #193/#196 separate R5 kernel: same job as #209, duplicate Arbiter. Keep #209 chosen.
- #199 V9 seven difficulty tiers: #209 has four levels with actually measured training matches. No basis to imply 2x/4x/6x stronger play; defer separate tier migration.
- #206 alternate all-defender VCT and #210 countertrap oracle: potentially useful but not yet proven nonduplicative with existing R4/R8/#209 scans; separate governor shadow comparison first.
- #207 strategic planner: shadow-only, not part of current tournament-proven engine.
- #211/#212 horizon leaves: duplicated by selected #213; avoid two simultaneous depth-zero classifiers.
- Older UI #197/#198/#203/#204: superseded by canonical #208, no duplicate identity cards.

## Guarantees and limits
No hidden reasoning is reconstructed: the black code screen is cosmetic and says so; measured depth/nodes and actual search branches are recorded as real events. Spatial traces may incidentally reveal strategy even when not ranked: feature defaults OFF and should not exist in competitive fair-play mode.

R14 is a **validated source-level integration proposal**, not a merged/running iOS App, no IPA and no newly measured win rate.
