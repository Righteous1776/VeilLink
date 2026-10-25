# R7 RISKS

- R7 and previous R6 PR #83 target same proposed product filenames: ONLY ONE may be promoted; prefer newer R7 after full review.
- iOS SwiftUI/SpriteKit and @MainActor bridging syntax was parsed on Linux but requires actual macOS type checking.
- Apple low-power + thermal behavior unmeasured; preferredFramesPerSecond=30 is requested not observed; frame callback cadence is not GPU performance.
- Fixed 280ms stale watchdog blanks notes during dropped HUD cycles; safer than displaying incorrect note, but must test in-app lifecycle.
- Current game has no audio-sample-accurate synchronization; host clock alignment is only logical scheduling.
- Main transport, encryption, storage, legal consent and iOS15 screen-wide gesture P0 are frozen. No release or IPA.
