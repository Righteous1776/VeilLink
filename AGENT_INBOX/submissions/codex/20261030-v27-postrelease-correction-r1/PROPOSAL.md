# Proposal — correct V27 routing, learning, imports, A10 telemetry and battlefield

## Outcome

Apply `PATCH.diff` on an isolated Governor integration branch. This candidate does not change version/build and must not start an IPA workflow.

## User-visible corrections

### Apple Files import

All existing pickers remain Apple's system Files picker. Selection now accepts the system item, coordinates iCloud/third-party provider download while the security-scoped grant is active, copies it to an app-owned temporary staging folder, validates the expected extension where applicable, and deletes the staged copy after use. Covered entry points:

- settings backup restore;
- onboarding backup restore;
- board-learning package import;
- offline HTML import;
- ZIP backup preflight;
- image attachment import;
- arbitrary file integrity inspection.

### Board learning

- Gomoku and Xiangqi use separate V2 files, summaries, clear actions and exports.
- The old shared V1 store is migrated non-destructively by `g:` / `x:` position prefix and recorded game kind.
- Removes the fixed 1,600-position, 40-game and 512 KiB pruning limits. Data remains local and grows until the user clears it or the filesystem refuses a write.
- Keeps full move sequences. Repeated AI replies in lost or abandoned lines receive a root-score penalty; successful lines receive reinforcement.
- Predicts the player's next reply after each candidate AI move. Gomoku prioritizes that reply in its adversarial reply search; Xiangqi replays it into the evaluated score, rather than using learning only for move ordering.
- Decision UI adds “阵法预判” when sequence evidence is active.
- Exports are named separately as `VeilLink-GomokuLearning-…` and `VeilLink-XiangqiLearning-…`.

### A10 presentation and automation

- Settings and Owner Console observe `VeilKernelRuntimeSelector` and `A10UltraOmegaShadowCoordinator` directly.
- A10-independent/A10-only modes display the live Ultra decision, budget, backend and sample ID. Frozen A9 values are not shown as current A10 data.
- Agent status, quick action and control-center labels follow the active governance runtime.
- The old `/a9 status` command remains compatible; the visible command becomes `/governance status`.
- SQLite integrity is sampled automatically at launch/foreground and at most once per six hours; failures enter Deep Telemetry. User surfaces show status instead of asking the user to run governance diagnostics.

### Information architecture

- Removes the omnibus “V27 功能库” and link diagnostic entry from the visible Tool Center.
- Keeps practical user tools direct: productivity, offline QR, offline HTML and backup preflight.
- Moves Rhythm R6, Lattice Clash and native Story Lab into Game Lobby.
- Mission Control/RareLab/AetherLab are no longer exposed as user chores through Tool Center.

### 三国兵器 battlefield

- Single-player Game Lobby now opens the existing original V2 `guandu_large_map_v2_48x27.json`, not the legacy 7×9 `TacticalState` board.
- Adds offline deterministic WEGO turns: the player commands Cao formations and a local Yuan policy advances one formation toward the nearest Cao force each turn.
- Reuses the existing fog-of-war, supply field, A* route planner, sector index and virtualized landscape renderer.
- On narrow phones the 48×27 map remains full width; the command panel opens as a system sheet instead of consuming 276 points beside the map.
- The visible online negotiation fallback no longer renders the small board. Legacy parsing code remains only for historical/protocol continuity.

## Governor apply order

1. Apply patch to a clean branch at the recorded baseline.
2. Run XcodeGen and compile the iOS 15 target.
3. Run the full XCTest suite.
4. Run the import and P0 touch/device matrix in `TEST_PLAN.md`.
5. Review the A9/A10 presentation adapter as a protected governance surface.
6. Do not merge or release until all P0 gates pass.
