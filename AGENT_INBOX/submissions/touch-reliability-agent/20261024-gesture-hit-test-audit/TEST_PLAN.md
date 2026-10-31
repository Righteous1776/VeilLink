# Touch interaction verification matrix

- **Static gate:** git apply --check on 501ef814a0a9bea41419fe2d9f48315371b30320, XcodeGen, Swift6 preflight, complete XCTest. Review SwiftUI/UIKit representable integration on iOS15 deployment target. Tests not run in this submission.
- **Cross-mode devices:** physical iPhone7 iOS15.8.3; iPhone13 Pro new iOS; dark/light switching, reduced motion, low power, force effects, App background and foreground.
- **Onboarding:** vertical scroll on pages 0–3 while swipe listener attached; deliberate horizontal page flips; initial hidden transition must not intercept touch; legal page must be gesture-free and IME keyboard signing functional.
- **PTT:** hold, slide outside, cancel, navigate away, lose recipients, receive inbound voice while pressed, background mid-hold; must not continue transmitting or visually remain pressed.
- **Board:** Gomoku and Xiangqi single taps at edges and valid cells, off-turn input, fast vertical list scroll starting over board, long hold, diagonal swipe; only intentional taps result in moves; no double processing; parent scrolling still works. UI accessibility retained on board containers.
- **Platformer:** hold jump with finger jitter, pause while holding, app background while holding, return/re-enter, dash, simultaneous left/right and jump; exactly one jump request per hold.
- **Tactical:** tap unmoving finger on friendly unit; drag route; tap near north decoration; verify minimumDistance 0 does not prematurely commit selection or mis-queue orders.
- **Realtime games:** move/steer/repair/shield while swiping home/app switch, pop page or show guide; on return controls should be neutral and state coherent.
- **Scope safety:** no build number change, no BLE/storage/crypto regression, no time-consuming IPA/release workflow until later user approval.
