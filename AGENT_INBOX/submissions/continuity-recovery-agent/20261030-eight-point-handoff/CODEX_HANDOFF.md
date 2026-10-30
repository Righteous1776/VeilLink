# Codex takeover evidence

As of Friday 2026-10-30 latest main `403b3dc474746d3925ad52fa4169225905bac7fc` and GitHub PR index (up to #91) were inspected. There is no new pushed Codex PR for the eight requested fixes. Existing `codex/maintenance-takeover` and `codex/tactical-solo` branch names are older work and cannot be assumed to contain the unavailable local uncommitted changes. Therefore this submission creates independent reviewed R1 changes from latest main instead of cherry-picking an unseen Codex workspace.

All eight target areas are inventoried. Do not claim full completion from the recovered proposal. Existing public versions/CI status unchanged (27.0 Build62, 763 XCTest previously passed); this R1 candidate does not inherit that CI proof.

Exact target files:
- Files: OnboardingView.swift, SettingsView.swift, AppModel.swift, VeilOfflineHTMLReaderView.swift, VeilBackupPreflightView.swift, VeilFileIntegrityToolView.swift, ConversationViews.swift, GameLobbyView.swift
- Learned bot: AdaptiveBoardLearning.swift, LocalAIGameController.swift, GomokuBot.swift, XiangqiBot.swift, GameLobbyView.swift
- A10: VeilKernelRuntimeSelector.swift, A10UltraOmegaShadow.swift, SettingsView.swift, OwnerConsoleView.swift
- UX: ToolCenterView.swift, GameLobbyView.swift
- Galgame: #80/#85 missing verified assets, no main engine binary.
- Tactical: already shipped `guandu_large_map_v2_48x27.json`, `TacticalScenarioBundleV2`, `TacticalLandscapeCanvasV2`, `TacticalLandscapeShellV2` and WEGO; solo lobby points at small `LocalAIGameView(.tactical)`.
