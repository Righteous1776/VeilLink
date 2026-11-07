# iOS15 acceptance matrix

- `git apply --check` against 501ef814a0a9bea41419fe2d9f48315371b30320; XcodeGen and full iOS15 XCTest. Confirm UIGestureRecognizerDelegate Swift6 MainActor conformance.
- On iPhone 7 iOS15.8.3 and modern iPhone, raw touch OFF must yield 0 passive recorders after cold start/background/foreground/theme change.
- Toggle ON => exactly 1 recorder/window; OFF => 0. Repeat 30 cycles and open new windows; no duplicates.
- Compare raw touch OFF/ON: Slider, Stepper, game drag, chess tap, text selection, back-swipe, ScrollView, image pinch, PTT, game jump+move; no input starvation.
- Simulate cancellation by app switch or modal; opt-in cancellation count logged but no key/message content or coordinates.
- Semantic/black-box events remain available with raw touch OFF.
- No IPA workflows/signing nor old iPhone7 data resets without owner permission.
