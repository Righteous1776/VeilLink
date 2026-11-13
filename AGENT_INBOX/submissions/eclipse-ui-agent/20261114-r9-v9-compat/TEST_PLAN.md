# R9 test plan and results

Executed locally:
- Swift 6.2.1 strict -swift-version 6 -warnings-as-errors -O: 35 session/telemetry/tier checks PASS.
- Swift 6.2.1 strict: 18 fair-play/replay checks PASS. Total 53/53.
- SwiftUI source -frontend -parse -swift-version 5 PASS, NOT Apple SDK typecheck.
- Browser Chromium/Playwright 320x568, 390x844, 768x1024 PASS: five VeilLink themes and seven proposed V9 labels, active no hints, postgame separate read-only replay, no JS exceptions, no horizontal overflow.
- Full owner patch passes git apply --check on a synthetic baseline reconstructed from exact current-main snippets, NOT on full repository checkout.

Required before integration:
- Governor resolve #199 vs #203 vs #193/#196 conflicts in controller and game view.
- Full exact-main git apply --check, actual Xcode build, XCTest, VoiceOver/Reduce Motion, iPhone/iPad gesture and thermal tests.
- After native search producer exists, wire event generation with matching session/turn/boardFingerprint; confirm cancellation/restart drops late events.
- Verify 7 tier behavior only after #199 merges. Never claim 2×/4×/6× win-rate gains.
- No gameplay engine changes or signed IPA in this proposal.
