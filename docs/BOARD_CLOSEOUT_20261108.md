# VeilLink Board AI Closeout — compact screen, fully user-controlled search, verified tactical stack

**Owner request (2026-11-08):** stop forcing reduced chess search due to iPhone 7, keep an optional user control, shorten the overly long Gomoku/Human training UI, and integrate completed chess development. Owner asked to close the loop; promotion to main is conditional on a complete CI and overlap/compatibility review.

## Exact source lineage — one integrated chain

- Main basis: `2c5b5161027edff097b27fe3323d30f6ca3e430e`.
- R3 PR #170: native Gomoku self-play replay, variety, learned score in production Bot.
- R4 PR #172 (stacked on R3): precise defense gate, scorer and R2 negative-outcome feedback carry-forward, low-allocation Xiangqi scoring.
- R5 PR #173 (stacked on R4): default-unchanged diagnostic selector for paired native R3/R4 games.
- R6 PR #174 (stacked on R5): true trained seven-coefficient Gomoku policy with existing hard rule gate, diagnostic opt-out.
- R8 PR #175 (stacked on R6): exact forcing win-in-two tactical gate, 8 paired native match screening.
- R8 CI fix PR #177 (stacked on R8): split obsolete R4-only defense assertion from correct R8 forcing attack. Its full iOS simulator CI #42391956393 PASS.
- This PR: **only** board screen, controller search preference, deterministic budget tests and docs, stacked directly on #177. No reimport of private user/friend chess records.
- R2 PR #169 overlaps with R4 `AdaptiveBoardLearning.swift`; R4 already transports its negative-reward persistence fix. It must not be separately merged after that without SHA/diff reconciliation.

## Compact UI (screenshot-driven)
Old `LocalAIGameView` put its enormous training card **before** the board; visible screen was several pages of configuration before any playable board.
New display order:
1. Compact status, side selection and three status metrics;
2. Single-line difficulty menu + explicit `深度搜索` toggle;
3. **Playable chessboard immediately**, for both Gomoku and Xiangqi;
4. Result when match ends;
5. **Collapsed by default** `棋手训练与高级设置` DisclosureGroup, with expandable all existing controls: saved-learning summary, PVS/VCF opt-in, formation, selfplay, personal coach, training import/export and clear confirmation.

All features remain reachable. Training reset still requires confirmation; training exports and staged import permissions unchanged; no data clearing or migration. Existing UI shell/theme is retained. Default collapsed state resets naturally on navigation.

## Search autonomy is not device-class discrimination
- New UserDefaults key `VeilLink.Board.UnrestrictedSearch.v1` stores **explicit user choice**. Missing key => `true` (**deep search enabled by default** on ALL supported devices).
- `LocalAIGameController.boardSearchProfile(deviceLabel:unrestricted:)`: if enabled returns `HIGH-PERFORMANCE`, bypassing `IPHONE7`, `SE1`, and `LEGACY` budget branches **only for the Gomoku/Xiangqi game engines**; if user disables it returns the actual device label and original budget.
- Both `GomokuBotBudget.forDifficulty` and `XiangqiBotBudget.forDifficulty` use that profile. Difficulty selection remains independent (`轻松` through `宗师`). Max search still respects explicit node/time-budget and Task cancellation: user enabling deep search is permission to search, not infinite work.
- Opt-in external PVS/VCF engine remains a separate existing choice, with its previous fallback and formation compatibility unchanged; no silent engine rewrite. At highest tier the enabled external engine can ask for depth 8 rather than 7. Native full budget is independent of device label.
- Unit tests simulate `LEGACY-COMPACT` explicitly; enabled budget must be strictly deeper, wider, and longer than the user's opt-out budget, for **both** games.
- This change does not pretend deep search was actually benchmarked on old hardware. On older phones latency, temperature and battery use may increase; user retains the accessible disable control.

## Strength evidence, not marketing
- R5 full native matched games: R3 vs R4 6:6, no established superiority.
- R6 vs R4: R6 2, R4 5, one unfinished; R6's 466/544 strict source-game-disjoint one-ply fork ranking is NOT win rate.
- R8 vs R6: 4:4 in eight simulator full games, 456 legal moves, mean ~35.62ms per move; no statistically established win-rate improvement.
- R8 local rule parity 1,220/1,220 source-derived cases; 394 real-source missed forced tactical opportunities used to derive a compact exact rule, but no broad game-strength claim.
- Friend-derived imitation scores 440/544 vs R6 frozen 466/544 in strict independent defensive candidate test; NOT promoted, private original games omitted from public repository.
- R2/R3/R4 source feature improvements are meaningful engineering, but require 200+ completed paired games and on-device tests for a precise quantified strength claim.

## Required closeout checklist
- [x] Narrow live-lane grant on Issue #6.
- [x] Source-level UI rearrangement, collapsed training disclosure, user-controlled persisted search and two dedicated unit tests.
- [x] R3/R4/R5 and R8 CI-fix parent tested independently.
- [ ] This exact commit iOS simulator build, XCTest all checks and artifact evidence.
- [ ] Confirm PR changed-file scope and single-stack merge plan.
- [ ] Adopt reviewed stack into main only after integration CI green. If any gate fails, preserve protected main and report exact failing suite.
- [ ] Physical-device performance/thermal and full ≥200 game comparison are additional validation—not silently claimed by simulator CI.
- [ ] Main release/IPA signing and distribution are separate authorization-gated steps; do not automatically dispatch.

**Safety note:** This branch changes no communication transport, protocol, identity, DB schema, signing, packaging, release/version, asset binaries, or saved chess data. The chess engine selection remains rule-gated and cancellation-aware.
