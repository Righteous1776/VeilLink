# VeilLink Grok bot toggle — original moving AI-opponent avatar

## Implementation
- New `VeilOpponentAvatarView.swift`: native SwiftUI TimelineView, independent LED-robot geometry, blinking, gaze shifts, rotating halo, damped spring reaction; idle/thinking/win/loss/draw. 30 fps normally/15 fps low power; pauses when scene inactive or system Reduce Motion is requested. `.allowsHitTesting(false)` to protect board touch.
- New Owner Mode card `AI RIVAL AVATAR` with an independent "Grok bot" Toggle, OFF by default, persistent shared @AppStorage. Requires actual `OwnerCapability.visualEffects` for changing, no unauthorized control or token changes. Owner preview animates.
- Include visually distinct opponent in all seven local human-vs-bot games via shared `LocalAIGameView`: Gomoku, Xiangqi, Ludo, tactical legacy, artillery, Light Trail and Magnetic Hockey. Also include `LatticeClashLabView` and `TacticalV2SoloView` separately (9 interfaces).
- No source/asset imported from unlicensed Grok study; label and disclaimer documented. Does not alter game state, AI engines, training archives, messaging/transport, or saves.
- Three XCTest methods verify setting gate, power pacing, stable key/mood text.

## Governance intersections
- Same GameLobbyView.swift as #159 solo saves, #128 side selection, #141 native selfplay export, #129 file staging. Governor must reconcile code; avoid dropping the existing fixes.
- No product tree changes in branch, just PATCH.diff under Inbox. Build/XCTest and device tests still NOT_RUN.
