# R7 / Wave 1 Reproducible Evidence

- Linux Swift 6.2.1: `swift test -j 2` => **128 XCTest PASS / 0 failed** (fresh in this submission session, after documentation edits).
- Linux Swift 6.2.1: `swift build -c release` => **PASS** (fresh).
- R7 full 13-file candidate patch: `git apply --check --whitespace=error-all` against clean git fixture => **PASS**, and exact file content parity after apply => **PASS**.
- R4 E191 + R5 + R7 Wave 1 *20-file advisory combined* patch: same check => **PASS**, exact file parity => **PASS**.
- R7 source listing: 13/13 Swift file contents in GitHub `FILES/`; original two smoke test files retained. GitHub verifies inbox folder/text scope only, not iOS runtime.
- Apple `xcodebuild` / XcodeGen iOS15 SDK typecheck => **PENDING** (no macOS/iOS SDK here).
- Simulator launch/screenshot and SpriteKit/SwiftUI types => **PENDING**.
- iPhone7 iOS15.8.3 physical 20min touch, appearance, pause/resume, thermal and power => **PENDING** (no connected device).
- Existing BLE, privacy/DB and communication regression => **PENDING** (depends on Governor controlled integration).

Device acceptance matrix is `IPHONE7_RENDER_QA_MATRIX.md`. Never treat logic test green as measured GPU FPS or proof of fixed distortion.
