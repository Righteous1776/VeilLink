# Governance, integration and technical risks

- Draft PR #64 includes root particle changes; this R1 patch does not touch those files. Governor must combine/order the changes.
- Onboarding left/right swiping is deliberately removed pending a scoped recognizer; button-based navigation remains. UX trade-off requires acceptance.
- SwiftUI onDisappear/scenePhase and gesture onEnded may both fire; stop/release methods must be idempotent. Verify in hardware/CI.
- FullScreenImageViewer ExclusiveGesture with simultaneous pan/magnify may have OS-version interaction conflicts. Leave draft until iOS15 build/test.
- Tactical minimumDistance:0 may consume an initial tap before existing route updates, check on device.
- Gomoku and Xiangqi zero-distance gestures still compete with parent scrolling. Threshold guard prevents mistaken moves, not proven complete arbitration; defer architecture replacement.
- Decor stroke hit-test opt-out should not modify appearance or core data.
- No macOS Xcode/physical device validation here, no release, no workflow_dispatch, no protected surface mutation.
