# SwiftUI handoff — exact route
Current-main files:
- `VeilLink/UI/GameLobbyView.swift`: `LocalAIGameView`, Grok block near L363-379, status card near L497-541; extra UI toggle near L644-657.
- `VeilLink/UI/VeilOpponentAvatarView.swift`: asset/autoreader specific to Grok, not to be relabeled blindly.
- `VeilLink/Agent/Games/LocalAIGameController.swift`: `isAIThinking`, `lastDecisionMode`, `lastDecisionMilliseconds` available now.
- Proposed `VeilGomokuUnifiedSearch.Trace`: `phase`, `completedDepth`, `nodes`, `rootCandidates`, `selectedIndex`, `score`, `variation`, `rule` when native R5 actually integrates.

Suggested SwiftUI pseudocode:
```swift
if game == .gomoku {
    VeilEclipseIdentityCard(
        title: "ECLIPSE",
        phase: controller.isAIThinking ? "正在计算…" : "等待落子",
        elapsed: controller.lastDecisionMilliseconds,
        onOpenTrace: { showsEclipseTrace = true }
    )
} else if VeilOpponentAvatarPolicy.shouldRender(
    enabled: grokBotEnabled, hasComputerOpponent: true
) {
    // Keep existing Grok bot block entirely unchanged.
}
```
The contents above are design pseudocode, not production-ready build code; create and test final components in a Governor-authorized integration branch.

Layout: 76–86pt card, 56–64pt avatar, status title and subtitle, accessible button >44pt, limited animation; no board hit-target overlays unless in verified read-only replay mode.

Telemetry: optional depth/nodes/PV instead of 0 or guessed progress; cap 8Hz; runID + positionHash guard, no fake Top-3/per-candidate score until engine reports it.
