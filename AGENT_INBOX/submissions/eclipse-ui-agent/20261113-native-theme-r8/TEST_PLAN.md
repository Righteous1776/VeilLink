# R8 checks and remaining integration gates

## Verified locally
- Swift 6.2.1 strict policy compile, **15 / 15** executable assertions pass.
- SwiftUI source `-frontend -parse -swift-version 5` accepted. This is syntax-only, not full Apple SDK type check.
- `git apply --check` of owner full 25,655 byte product diff against synthetic exact-main snippets PASS. No full checkout verification.
- Chromium/Playwright via local system Chrome: 320x568, 390x844, 768x1024 all PASS (theme switches × 5, show/hide no-hint TRACE, replay unlocked only postgame, no horizontal overflow, no runtime errors).
- Visual inspection of rendered 390px Instrument night and Apple Soft day screenshots: palette/typography/card corrected; screenshot is HTML approximation, not a real native iPhone screenshot.

## Required but NOT run
- Full exact-main `git apply --check`, iOS SDK SwiftUI typecheck, Xcode build and XCTest.
- Real Device: iPhone, iPad, light/dark/automatic; dynamic type, VoiceOver, accessibility reduced motion, existing board gesture targets.
- Cross-PR controller integration with #193/#196 and old UI R6/R7 drafts #197/#198.
- Verify old user saves/learning history, compare real native palette in all five themes.
- No automatic source promotion or IPA until Governor review.
