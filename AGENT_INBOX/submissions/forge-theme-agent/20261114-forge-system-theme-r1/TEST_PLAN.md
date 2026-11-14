# FORGE / Acceptance & Test Plan

## Before acceptance
- Pin `main` at af3d823546c288169d19cb3033a6111977d28bd7; verify `git apply --check PATCH.diff` on isolated branch; rebase carefully if main moved.
- Confirm source changes restricted to AppearanceTheme.swift, AppTheme.swift, NearbyView.swift, AgentStatusView.swift, plus three new files. No project.yml/workflow/release/signing change.
- Check exhaustive selection switches, theme persistence and default fallback; test old saved theme IDs and switching back from FORGE, plus Light/Dark/Auto.

## Build & XCTest
- XcodeGen iOS simulator build, full VeilLinkTests/UIKit smoke, iPhoneOS Release compile on exact SHA.
- Run `VeilForgeMotionCoreTests`: deterministic 12Hz rotor detents, parked/stopped/infinite values, BLE health 0..100 clamping and actual-score segment mapping.

## UI and behavior
- Visual matrix: iPhone compact/iPad regular; day/night, typography sizes, accessibility contrast, Settings theme preview, chat list/composer, Settings, games, Nearby, Agent.
- RF: actually turn scan on/off, rotate only while scanning and foreground, never show bogus peers. Restore on app foreground; test reduced motion/low power and older compositor.
- LAN: verify real counts in STATUS rail with 0 and connected peers; never mislabel throughput.
- CPU: loading/generating moves, ready parked, unavailable/error visually distinctive; retain truthful backend label and original non-FORGE glyph.
- Link H: five sample scores (0, 1, 50, 75, 100) correctly yield 0,1,4,6,8 bars; verify no hidden text/logs exposed.
- Verify no touch interception during chat keyboard, Slider/ScrollView, pair/accept, game board, and back swipe.
- Apply #229 global particle deletion during a Governor-approved batch before claiming fully particle-free whole-app UX. Test no root particle overlay regardless of active theme.

## Execution status (2026-11-14, R1 continuation)
- Exact-source seven-path patch replay against `af3d823546c288169d19cb3033a6111977d28bd7`: **PASS 7/7**, including three proposed new files.
- Unified-diff structure (29 hunks) and hunk line-count checks: **PASS**.
- Theme registration and day/night palette checks: **PASS**, alongside a static audit that all `VeilTheme.*` color tokens used by the new instrumentation are declared.
- Fixed a real draft compile blocker: `VeilTheme.metalTop/metalBottom` were not exposed. The Forge plate now reads existing `VeilAppearanceController.shared.palette.metalTop/metalBottom`.
- Isolated Foundation-only `VeilForgeMotionCore.swift` compiled with Swift on Linux: **PASS**; **17 deterministic value checks PASS** for detent stepping, parked motor, invalid time values, BLE health clamping. This is NOT an iOS application build or XCTest run.
- Added a new **proposed iOS XCTest** asserting `.forge` appears as a sixth switchable theme, retains the raw-value storage identity, and preserves existing Veil Original/Instrument themes; **NOT_RUN**.
- Apple's Xcode, simulator, end-to-end theme picker, real BLE/CPU/gesture checks, full XCTest and IPA: **NOT_RUN** (Linux environment cannot provide them).

## R2 checks (screenshot iteration)
- Proposed patch: **9 product paths / 38 hunks / all exact-source context replay PASS** against recorded base commit; changes in actual PR remain only the five FORGE Inbox documents.
- Probe selection: FORGE's theme chooser preview and theme specification appear only for `.forge`; all original themes and experimental Plainline remain available.
- Gesture regression required on real devices: enter FORGE, swipe up/down over Nearby panel, Game Lobby card, Gomoku board, chat bubble and composer; no `VeilSpatialPress` zero-distance drag handler should run. Recheck clickable buttons for native touch response.
- Decorative idle motion: FORGE dynamic glow must not rotate; its stepper RF and CPU rotors only update while their actual subsystem is working, in foreground, and motion policy permits. Switch from legacy theme while a glow is active and check reset.
- Compare supplied screenshot composition to FORGE: orange emphasis, ECLIPSE dark console contrast, graphite panel hierarchy, nested training control readability, 42pt theme specimen.
- Test small iPhone portrait, dark mode, light mode, Dynamic Type and VoiceOver so extra module headers do not overlap buttons or keyboard.
- Xcode full iOS compile, simulator XCTest, BLE test, physical device FPS and screenshots: **NOT_RUN**. Static patch replay does not prove SwiftUI compilation or frame-time improvement.
