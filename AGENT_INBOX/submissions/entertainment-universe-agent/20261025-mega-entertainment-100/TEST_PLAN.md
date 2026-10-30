# Test Plan

## Verified in external R3 archive (NOT this GitHub PR)

- Linux Swift 6.2.1 source typecheck.
- SwiftPM: 35/35 XCTest green, no failures.
- E091: 100 safe-spawn seeds, chunk seams, deterministic climate, action failure rollback, capped resources and JSON replay snapshots.
- E101: finite-vector validation, time bounds, thrust fuel limits, orbital drift tolerance, safe termination, determinism and 512-frame telemetry cap.
- E121: building budgets, road BFS, disconnected production, connected food/water/power, factory gating, morale/pollution, 400-day state stability, Codable snapshot.
- Standalone SwiftUI lab parsed as syntax only. It was NOT typechecked with iOS SDK.
- Full new-source add-only diff passes git apply --check against an empty scratch Git repository.

## Mandatory unverified gates

- Integrate exact GitHub-source candidates onto a clean Governor branch; verify target membership in XcodeGen.
- Exact-head macOS/iOS15 simulator build and XCTest (including existing app 560+ regressions).
- Physical iPhone7 iOS15.8.3 consent/signing/appearance/touch path and comparison iPhone13.
- App snapshot migration/import/recovery, 60-FPS target where achievable, actual memory and energy profiling; do not claim performance before measuring.
- Keep normal messaging features fully operable when entertainment subsystems are off.
- Any local two-device sync remains DESIGN ONLY until protected BLE/Wire review.
