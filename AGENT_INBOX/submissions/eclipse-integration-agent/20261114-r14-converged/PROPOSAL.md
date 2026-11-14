# R14 Integration proposal — one real ECLIPSE, not a stack of competing bots

## Chosen baseline
Codex R10 PR #209 is the current best-controlled trained-search candidate. Frozen trained ranking uses **1,848,616 D4-unique board/action candidate rows**, NOT games: 48 trees, 1348 nodes. Its own reported complete matched matches: 500 trained/control games (1000-node 57.25%, 5000-node/forcing 55.25%, 50ms target 59.5% trained points); another 420 completed native tier-calibration games with four current persisted tier labels. These are not proof of 6x Elo. Its published 920 match records were used to analyze R12/R13 and are no longer a clean new holdout for the combined system.

## Single product decision order
```
GomokuState + training/match history
  -> SAME GomokuBot mandatory own-five / opponent immediate five
  -> SAME native R8 own-double-five counterplay and R4 fork-safe root filter
  -> R6 learned/formation guidance + frozen Codex R10 48-tree move ordering
  -> ONE VeilGomokuUnifiedSearch native PVS/forcing-four arbiter
       optional R12 exact leaf quiescence (OFF)
       optional R13 reversible incremental threat windows (OFF)
       optional, real onExploredLine([root, reply, continuation], measuredNodes)
  -> GomokuBot existing legal postcondition + single move
  -> LocalAIGameController journal + R12 search trace token
  -> ECLIPSE original-theme identity / black terminal / opt-in true board paths
```

A previously stored `VeilLink.Gomoku.V2.Enabled` legacy preference is retained for migration, but the proposed controller NO LONGER routes a chess decision to JavaScriptCore. The old JS resources and copyright records remain cold until the Xcode/equal-budget acceptance gates confirm that they can be safely removed; do not strip licenses from remaining vendored files. The old user-facing PVS/VCF toggle is replaced with noninteractive “ECLIPSE 原生搜索” status. This retains the original 5 VeilLink appearances, no custom neon visual skin, and the R12 optional per-board visualization under existing advanced settings.

## Video/search visualization boundary
Native trained PVS now emits live explored line callbacks from actual place calls in the native root and negamax (up to 3 plies); fallback GomokuBot also emits real root/reply/continuation events. ECLIPSE TraceStore validates each sequence against a locked position and session UUID before drawing thin lines / transparent dashed ghost stones. It is **OFF by default**, cleared on cancellation/end and shown only while the AI is searching. Spatial search observation can reveal meaningful tactics; do not claim perfect fair-play privacy. Real PVS completed depth/nodes TRACE metrics are not yet wired to a live published display (the visual code panel remains clearly decorative). No fake move paths.

## Other agent research / de-dup decision
| PR | Disposition | Rationale |
|---|---|---|
| #209 | **Selected, integrated into candidate** | Published 920 complete generated matches and measured trained gain with immutable model |
| #213 | **Integrated OFF-by-default** | One bounded exact horizon-leaf evaluator, 1607 tested assertions and arena-derived fixtures |
| #214 | **Integrated OFF-by-default** | Separate incremental 572-window threat index; own property tests, isolated microbench only |
| #208 | **Selected UI/history** | One original VeilLink theme / one every-match archive / one real thought trace |
| #193/#196 | Superseded by Codex integrated source | Alternate R5 native implementation not run in parallel |
| #199 | Held | Seven budget labels 2×/4×/6× were not yet calibrated against #209 trained four levels |
| #206 | Held | Independent VCT proof useful, but needs arbiter/integration tests and avoiding duplicate threat scans |
| #207 | Held | Separate shadow planner overlaps PVS; full product source not in its public PR |
| #210 | Held | Extra R11 root countertrap oracle overlaps existing R4 + Codex R10 safe-root scans |
| #211 | Held | Ordering memo & alternate leaf extension conflict with chosen #213 leaf. No fresh merged-game benefit yet |
| #212 | Superseded for this merger by #213 | Same horizon concept; select only one implementation |
| #186/#187/#190 and old UI #197–#204 | Reference / no duplicate apply | Existing R4 safety and R12 visualizer encompass actionable contributions |

No changes to the trained weight values, learned sample count, storage schema, BLE/protocol, iOS build version or release state.

## Current state
**The 21-file product patch is integrated as SOURCE and staged for Governor review, not integrated into main or a compiled iPhone build.** Promotion requires the gates in TEST_PLAN.md.
