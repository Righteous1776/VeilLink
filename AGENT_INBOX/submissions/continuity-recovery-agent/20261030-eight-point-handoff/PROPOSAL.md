# Eight-Point Build62 Hotfix — current verified scope

## Codex recovery
No PR or pushed Codex changes for these exact eight items after Build62 main could be found as of 2026-10-30. Other older Codex drafts exist; do not blindly replay their obsolete product paths. This is an original continuation from main 403b3dc.

## R1 staged source/patch
1. **Files:** one coordinated `VeilFilesIngress` read boundary. iOS security scope + NSFileCoordinator, validation and owned temporary copies for flows crossing importer sheet dismissal. Proposes integration across training package, restore (Settings+first launch), HTML, ZIP preflight, image import and hash. Temp copied backup limited to 200 MiB, imported picture 80 MiB, HTML 512 KiB. Never deletes original provider file. File provider/macOS/iOS real testing is still required.
2. **Learning separation:** new in-memory sequence engine has distinct Gomoku/Xiangqi episode lists, counts and clear APIs, without the old 1600/40/512KiB database truncation rules. **NOT yet a persistent two-database migration or full per-game export path.** Existing merged legacy journal must remain untouched until transactional migration and device tests.
3. **阵法预判:** predictive engine looks at exact historic move sequences, gives a concrete next-action candidate through a legal-move callback; successful AI episodes help and lost/interrupted episodes penalize. **NOT connected to existing GomokuBot/XiangqiBot or live UI yet**, so the current compiled bot remains ranking-based.
4. **A10-only:** new SwiftUI pane and Owner Console view consume `a10Ultra.lastRuntimeSample` with mode-session + <=30s freshness checks. Never display stale A9 as A10. When new A10 sample unavailable, show explicit "等待新样本" rather than blank or bogus A9.
5. **Toolbox:** remove V27 feature hub, file-integrity and link-sampling technical entries from ordinary tools and add a read-only background status pane. The underlying engines remain; future Governor should provide an explicit authorized Owner access path for on-demand file hash and diagnostics (no background private Files scanning).
6. **GameLobby:** restore direct R7 rhythm, Lattice Clash, Story Lab links; use existing UI types, no duplicate implementations.
7. **Galgame:** restore honest recovery entry but no playable Monogatari until actual verified 2.8.0 vendor bytes + R5 host return. See MONOGATARI_RECOVERY.md.
8. **Guandu:** restore standalone 48×27 TacticalV2 campaign entrance with local two-sided WEGO, deterministic map, fog and map rendering; replaces tiny solo tactical lobby entry only. Existing multiplayer legacy compatibility untouched. **New solo scene is proposed, not Apple-compiled nor gameplay-tested**.

## Critical sequencing
P0 Files/legacy database and migration safety first. Independent training databases, loss-driven live bot policy and owner governance wiring next. Only after iOS15/physical iPhone7 build and UI/BLE regression Governor may promote the batch. Do not interpret any R1 candidate as already in IPA.
