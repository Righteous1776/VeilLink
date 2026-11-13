# Test plan — ECLIPSE R6
Completed on the standalone HTML prototype:
- Chromium + Playwright: 390x844 iPhone-like, 320x568 compact, 768x1024 iPad-like viewports.
- Grok-name replacement mock, card click/open/close, next-step replay, historical danger markers, light/dark toggle: passed.
- Horizontal overflow: none; JavaScript runtime errors: none in all three viewports.
- Prototype renders **historical R2 real board** (#72 ply 12, 53 open points, safe #67/#123 vs historic #83) with no synthetic PVS/depth/nodes.

Must run after real SwiftUI integration:
1. Visual check in actual GameLobbyView, full 15x15 board tappable.
2. VoiceOver dynamic-type/reduced-motion and low power state.
3. Navigation, restart, switching seats; cancellation and stale runID drop.
4. Real telemetry depth/nodes/PV valid only when actually emitted.
5. R2/R4 tactical fixture regressions unaffected; learning archives persisted.
6. iOS SDK compile, XCTest and physical iPhone13/iPadAir4 performance tests.
No iOS compile or device test has been performed for this UI proposal.
