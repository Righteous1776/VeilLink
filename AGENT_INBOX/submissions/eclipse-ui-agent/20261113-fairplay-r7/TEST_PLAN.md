# ECLIPSE R7 — checks

Completed LOCALLY against owner source package:
- Swift 6.2.1: Policy source compiled with warnings-as-errors and optimized. 13 assertions passed: active coordinate redaction, finite/valid counts, live-only metrics are 2 coordinate-free integers, no historical-example metrics, completed replay only, replay never in live board, last-board parity, duplicate/out-of-range/wrong-side rejection, no moves after five, actual recorded order.
- SwiftUI source parser (not type checker) PASS.
- Browser visual simulation: Chromium+Playwright 320×568, 390×844, 768×1024. No active coordinate overlay, finish-only replay, scrub/next, no horizontal overflow, no page errors.
- Full owner PATCH.diff passes git apply --check to known current-main *synthetic snippets only*.

NOT run and must NOT be claimed:
- Complete current-main git apply --check, real SwiftUI typechecking under Apple SDK, iOS simulator build, XCTest, real iPhone/iPad accessibility and gesture tests, R5 event connection, signing/IPA.
Test program and HTML test driver are included in owner ZIP. Synthetic demo moves are valid invented example only, not real user training games.
