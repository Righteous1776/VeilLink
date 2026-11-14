# ECLIPSE R14 integration verification and next-stage acceptance

## Executed this turn
1. Pinned current GitHub `main` exact SHA `eb487a1901c0ffddfb38b80b9fb56f6d7d749ba0`; read governance AGENTS/Inbox/Issue #6, obey INBOX_ONLY.
2. Fetched all relevant Github PRs and exact source code, not only agent descriptions.
3. Reapplied PR #213's exact hunk patch to original PR #209 kernel and verified byte-for-byte equality with its full R12 overlay.
4. Reapplied PR #214's exact patch to original PR #209 kernel and verified byte-for-byte equality with its full R13 overlay. Rebased both independent changes under mutually different default-OFF flags, plus new live examined-line observer.
5. Verified model and helper blob identity against original PRs: same blob SHAs, no retraining.
6. `PATCH.diff` 21 unique destinations / 46 structural hunks all old/new line counts valid.
7. **In-memory line-by-line apply** of all four modified product files to the exact main returned by GitHub: 6 GomokuBot hunks, 15 controller hunks, 6 GameLobbyView hunks, 2 MiniGameViews hunks. Every context matched; every reconstructed file matched staged source **byte-for-byte**.
8. Nine native/XCTest add-files in `PATCH_CORE.diff` and eight UI add-files in `PATCH_UI.diff` matched staged file content **byte-for-byte**.
9. Previous Agent evidence (NOT rerun on merged code): #209 920 game reports and 9024 score parity checks, #213 1607 helper assertions, #214 14691 property assertions, PR #208's prior local UI policy tests.

## Must execute after Governor approves live integration branch
- On a **full clean checkout** from the exact chosen main SHA, run `git apply --check <staged PATCH.diff>`, apply on isolated integration branch and verify every product blob, `git diff --check`.
- Generate/refresh project via project.yml/XcodeGen as per repository documented build steps; build all iOS app/test targets in full Xcode; `xcodebuild test` with available simulator.
- Run staged native XCTest modules from this PR: `EclipseHorizonR12Tests`, `EclipseIncrementalThreatIndexR13Tests`, `EclipseR14UnifiedTests`; confirm Swift6 @Sendable/actor isolation.
- Execute existing native R4/R6/R8 and V9 tactical suites plus 212 private real fork-position fixtures (not uploaded), 1696 symmetry replays and historical save/restore/test replay.
- Capture actual event timing/position mapping in iPhone 13/iPad: R12 live line display works for trained PVS (not just fallback), no delayed or stale callbacks, no tap interception and high framerate/low power fallbacks.
- Test UI theme changes across Veil 原生、Apple Soft、拟物仪器、浮屿 and gated 白描; no custom ECLIPSE theme.
- Run fresh color-swapped matched-opening equal-time/total-budget A/B **not reusing the 920 previously examined games**, and compare baseline #209 vs R14 OFF flags, then R12 on alone, R13 on alone, both on, with score legality, node/time and thermals.
- Validate all history, existing resume match, learning import/export and cold legacy setting migration. Decommission JS/LICENSE/old switch only after proven parity, preserving notices while code remains.
- Only after all pass may Governor merge product into main or initiate release/IPA; never infer 6× Elo or phone speed from isolated tests.

**No Xcode/real device/new head-to-head games executed in this tool environment.** The current drop is source-integrated and patch-preflighted, not release-ready.
