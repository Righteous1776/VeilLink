# Grok bot R2 gates
- [x] Full upstream README and behavioral-engine module review: pose/eyes/tricks/math/character architecture examined, but zero source/artwork transferred.
- [x] Single PR #160 patch updated: original Canvas blob renderer with 32 dynamically computed points, eye state machine and spring-like transition; tests cover off gate/frame pacing/background/Reduce Motion/response.
- [ ] SwiftUI Canvas iOS15+ Xcode compile / full XCTest, NOT_RUN.
- [ ] Owner authorization, persistent switch OFF default, nine human-vs-computer game screens, no board hit interception.
- [ ] Video record normal/AI-thinking/win/loss/draw transitions, compare visual timing and eye readability on both iPhone7 and iPhone13.
- [ ] Battery/thermal/profiler: 30fps normal 15fps Low Power, inactive/ReduceMotion paused, accessibility and dark/light themes.
- [ ] Governor apply and reconcile with PR #159 current-match persistence and #128 player-side controls.
- [ ] Release/licensing checks: upstream code/assets not included; label reviewed before external distribution.

- [x] Generated binary magic GIF89a; original 24 frames, 110ms, loop=0; optimized 112x112 GIF 89204 bytes.
- [x] Code patch proposes GIF media playback via bundled ImageIO/UIImageView with original Canvas fallback. No unauthorized binary GitHub upload.
- [ ] Actual bundled GIF bytes, XcodeGen resource copying, iOS15 compile, UIKit pause/resume and memory profiler: NOT_RUN until Governor asset authorization.
