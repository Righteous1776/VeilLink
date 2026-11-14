# Native Gomoku R5 — Integration Proposal

## Implementation already delivered to Owner
A newly authored **Swift** unified search kernel implements exact immediate-win/block, opponent-fork filtering, forcing-four proof search, iterative-deepening principal-variation search, bounded deterministic Zobrist transposition table, timeout fallback, and genuine depth/node/PV trace events. It has no runtime dependency on JavaScriptCore. Separate source bridge accepts existing GomokuState, GomokuBotBudget, verified R4-safe root candidates and bounded R3/R6/history/formation root scoring. Native tactical gates remain mandatory and trained bonuses cannot override them.

The **complete** 38.7 KB advisory product patch in the owner package proposes: (1) add two Swift source files; (2) attach optional unified kernel after existing mandatory GomokuBot tactical checks, with native legacy fallback; (3) replace controller's external JS OR-choice with one GomokuBot decision path, fresh opt-in preference and session-safe @Sendable telemetry; (4) relabel the in-game toggle as VeilLink native search and display authentic real-time analysis events. The old JS source is **not deleted yet**; upon patch application it is unused by this decision path and retained strictly for validation/rollback.

## Verification already run locally
Swift 6.2.1 Linux strict build, 6 native smoke assertions, 4 bridge behavior assertions including mandatory block overriding inappropriate training preference, 212 real historical fork-risk positions × 8 symmetries = 1696/1696 tactical safety checks. These are **not 1696 independent games and not a strength/win-rate claim**. The owner's full product patch passed git apply --check only against a synthetic baseline assembled from verified current-main snippets, **not against a full checkout**.

## Before promotion
- Integration Governor reconcile #186, #187, #190; do NOT cherry-pick overlapping edits blindly.
- Obtain full owner ZIP, verify checksums in MANIFEST and inspect every source file for independent implementation/third-party provenance.
- Test git apply --check against exact full main; build/test iOS using real Xcode, Swift 5.9/Swift 6 strict concurrency; iPhone/iPad. Validate timing, power, cancellation, saved matches and training.
- Implement full proof-grade VCT and evaluate quality on matched-budget games.
- Only after all gates pass: retire VeilOfflineGomokuEngine.swift, GomokuEngineV2 JS resources, project.yml resource reference and obsolete preference. Preserve upstream copyright/license notices while any vendored or adapted code remains.

**Status: prototype + local integration patch completed. Not merged. Not an IPA.**
