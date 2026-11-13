# [AGENT-DROP] iPhone 7-first Veilopoly portrait + landscape layout

Owner instruction: 2026-11-13. Objective: use screen area fully, prevent compulsory landscape, allow financial monitoring while waiting for AI/another player.

## Proposed UI-only changes

1. Remove the explicit landscape geometry request from both solo/fullScreenCover and live-room presentation in `LandscapePresentation.swift`. Respect the host-supported orientation mask instead. Do NOT modify main host Info.plist or force landscape to work if host refuses it.
2. Replace portrait "请横向握持设备" fallback with `VeilopolyPortraitWorkspace`, top board ≤50% safe-area height, bottom workspace ≥50%. The same SpriteKit scene and GameSessionModel remain mounted; no second GameSessionModel or gameplay reset. Full 40-cell aspect-fit board.
3. Expanded portrait: bottom in-place full-width scrollable action drawer, own title-row collapse affordance; downward drag only on title handle to avoid stealing nested ScrollView gestures. No floating panel, no persistent top-right exit capsule. Explicit menu/exit in lower toolbar.
4. Collapsed portrait: in-place 2-column, scrollable dashboard with user-selectable `我的现金/模拟股票/银行利息/地产/贷款/连接状态` cards, local AppStorage persistence. Values read from authoritative GameState; use `viewingSeat` (local peer or first human) instead of misleading current AI/auction actor. Stock quote and bank rate are **existing** values; do not simulate new market ticks while engine is inactive.
5. Collapsed footer: 64pt die icon; ≥0.55s deliberate long press reopens drawer. VoiceOver custom `展开操作面板` action. A tap on icon does NOT roll dice, ensuring no accidental reducer move.
6. Stock/bank shortcuts open existing **read-only** `VeilopolyAssetBrowser` in the chosen section (new optional initialSection initializer). This works during another player's or AI turn; does not submit a trade. Existing actual order buttons and phase gating are untouched.
7. Landscape: replace wide ~2-button top-right capsule with single 44pt `Menu` (More, assets, Exit), preserving access and reducing overlap. Existing movable landscape drawer remains as secondary layout.
8. Add pure Swift `VeilopolyPortraitLayout.allocate` and `PortraitLayoutTests` to exercise iPhone7, SE2 and iPad portrait frames. All paths remain UI/tests only.

## Explicitly NOT delivered in this UI patch
- Real off-turn stock buying/selling, loan opening, asset construction, transfers or pre-empting another seat. The current `GameSessionModel.perform` constructs a `Move` for `actor`, while `VeilopolyEngine.apply` checks expected actor and phase; re-enabling a disabled button is both misleading and unsafe.
- New market clocks or financial model changes. No Engine/AI/Net, ACK gate, canonical Astra asset, Wire/identity, save migration or host rules changed.
- Portrait live-device performance / orientation build validation: NOT_RUN. Separate design and integration plan in OFF_TURN_FINANCE.md.

## Governor integration proposal
Apply prior PR #184's UI P0/P1 candidate before rebasing these overlapping UI.swift changes; do not wholesale overwrite either source. Owner/Governor approves exact merge order and iOS15 device gates. PRs remain draft.
