# Risks / overlap / acceptance boundaries

- Primary dependency: PR #64. It removes global root simultaneous DragGesture. This submission does NOT duplicate/modify that file. Apply both in a controlled Governor integration, avoiding silent acceptance.
- UIKit board-tap bridge is more reliable for tap vs pan arbitration than a zero-distance SwiftUI drag; but it is not device-verified. A transparent UIViewRepresentable could have layout/hit-test quirks on iOS 15. Xcode build and physical board tapping/scrolling MUST precede integration.
- Tactical minimumDistance 0 can shift selection to touch-down; test route gesture semantics and accidental drags. If map gameplay semantics break, defer this one hunk independently.
- PTT side-effect safety: endTransmit is called only when touch latch was held on receive/recipient changes, but onDisappear uses existing state-based endTransmit. Core radio engine itself untouched.
- Rapid scene/lifecycle changes can cause repeated stop/reset calls; verify these commands are idempotent and do not alter saved game progression.
- SwiftUI parent simultaneous gesture may still observe vertical drags, but it changes page only for horizontally dominant motions.
- No physical iPhone7 test, CI or XCTest run in this environment. All changes are staging-only with no release or product-source writes.
- More suspected risks not patched: Islet scrim, modal HUD obstructions, viewer tap recognizer arbitration, decorative overlays. Record rather than invent a fix.
