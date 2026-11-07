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


## R4 acceptance
- [x] Local ffprobe verified both user MP4 and silent app-ready MP4: 921 frames at 30fps, 30.700s, 514x512.
- [x] SHA-256 verified: original 411ae1ee2a979cae4edf9b56b0676420174c88e87461fcd8264409d17111e7fe; video-only 462dea06791e79e7410ec25a69ded8abae6244ed751f2099be8d72778290e788.
- [x] PR patch includes MP4 first, GIF second, original Canvas third; preserves all nine entrypoints and independent Owner toggle.
- [ ] Apple SDK Swift compile/XCTest, resource bundle test, 2+ full loop cycles, background/resume/mute/iOS15.8.3 stress: NOT_RUN.
- [ ] Verify original 30.7s first/last seam on device; looping is functional but the visual join depends on the source footage.

## R5 rounded-card validation
- [x] Proposed patch preserves original video source, full AVPlayerLooper, 9 game entrypoints and Owner switch.
- [x] Rounded clipping both in SwiftUI and on AVPlayerLayer UIView; strokeBorder subtle; added XCTest size-scaling values 42→12.6, 76→22.8, 112→26pt.
- [ ] Swift compiler/XCTest on iOS15.8.3/modern device; normal/dark mode rounded corners against status card; test 42, 58, 64, 76 pt sized avatars; check GPU clipping cost.
- [ ] Confirm white video background remains visible ONLY inside rounded frame, no corner leak, no stretching, no clipping of entire character or touch interference.
- [ ] MP4 asset must be staged under a valid grant or integration before claiming app playback works; GitHub PR still contains no MP4.
