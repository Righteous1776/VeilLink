# Touch regression gates

- Validate patch against exact SHA 501ef814a0a9bea41419fe2d9f48315371b30320 and inspect every patch hunk. Only Governor integration branch may apply product source.
- iPhone 7 iOS 15.8.3 + modern iPhone: dark/light/system switching, cold relaunch, navigation, sliders, pan, drag handles, text input, sheets, dynamic accessibility text and VoiceOver.
- First-run pages 0–3: scroll long cards, Back/Continue buttons; page4 legal acknowledgments/IME/signature. No dead tap zone after appearance toggle.
- PTT: hold-release, switch screen while held, app background, loss of recipients, incoming audio and re-entry. Verify audio really ends, pressed resets; scroll while PTT untouched.
- Gomoku/Xiangqi: taps within intersection, drag >10pt, scroll surrounding layout, local turn vs remote turn and no accidental moves. Zero-distance DragGesture may still compete with scrolling; investigate if regression persists.
- Platformer: one jump per touch-down, repeated onChanged, background/pause/resume/reentry; releaseJump not called incorrectly after a second hold.
- Tactical V2: stationary selection, preview drag, button zoom, overlays, rapid long press. Ensure map hit testing doesn't affect sidebar.
- Image viewer: single tap chrome, double tap zoom (no extra single event), pinch pan and swipe-dismiss, iOS15 fallback.
- Signal Dive and Blackout District: simulate gesture cancellation via Home/background/NavigationView removal while joystick or repair is active; verify stop methods and input restart.
- Glass material: border taps and toggles, legacy compositor touch propagation. Compensate for overlays only; no view hierarchy global disabling.
- Full iOS simulator build/XCTest only after Governor accepted, then real-device confirmation. No IPA workflow on this incident without owner authorization.
