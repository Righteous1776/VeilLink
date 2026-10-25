# Governor integration order

1. Keep main and old signed/unsigned releases untouched. Resolve P0 global gesture / pre-consent / data continuity (#64/#65/#66).
2. Acquire R4 archive separately, verify SHA-256, compare R2/R3 candidates and PR #73/#75. Prefer one canonical version of each engine type.
3. Import admission gate candidate, maintained engines and E191 core into an isolated source integration branch. Do not auto-activate the App entry; feature gate fails closed by default.
4. iOS XcodeGen + XCTest, UI tap testing iPhone7 iOS 15.8.3 and newer device, old JSON user-state recovery and chat/BLE regressions.
5. Only after passing all gates, opt-in GameLobby navigation; actual release/IPA requires separate owner/governor approval.
