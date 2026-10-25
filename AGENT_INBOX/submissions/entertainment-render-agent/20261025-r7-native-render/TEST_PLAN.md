# R7 TEST PLAN

**Executed:** Linux SwiftPM 128/128 XCTest; 100 seeds × 4 districts × 16 beats × 7 sample times exact reference parity; snapshot freshness, invalid time, fixed frame ring; Release build; Apple source syntax parse; patch applies with no whitespace errors.

**Missing:** macOS XcodeGen/iOS SDK typecheck, simulator XCTest+SwiftUI snapshots, physical iPhone7 15.8.3 tap/safe-area/dark/light, iPad, Core Animation/Metal tracing, thermal & battery tests.

**Governor:** first resolve PR #79 R5 dependency, reconcile #83 (superseded), P0 #64–66, then apply new source on isolated branch.
