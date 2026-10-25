# R6 test plan and evidence

**Executed:** Swift 6.2.1 Linux: 111 XCTest PASS (90 R5 regression + 21 pure rendering invariant tests), UIKit/SpriteKit candidate **parser only**, bash script shell syntax PASS. `git apply --check --whitespace=error-all` for nine candidate paths in scratch Git PASS.

**Required, not executed:** XcodeGen project membership after import R5, SwiftUI/UIViewRepresentable/SpriteKit Apple-SDK typecheck, full iOS XCTest, iPhone7 iOS15.8.3 screenshot comparison, input positions, dark/light/rotate, background resume, thermal/peak memory, GPU and stutters via Instruments.

**Visual QA:** verify circular notes never become ellipses; no cropped strike line; 44+pt tap controls not covered; letterbox regions inert; 4 representative device classes and Dynamic Type. Profile 10-minute continuous run and record real P95 frametime; document failing screenshots.

Do not claim device performance or a fixed bug before iPhone evidence.
