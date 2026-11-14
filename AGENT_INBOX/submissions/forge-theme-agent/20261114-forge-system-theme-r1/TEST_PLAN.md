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

## Execution status
- Exact source anchor edits and generated unified diff hunk counts PASS.
- Apple Xcode/real-device/BLE/UI screenshot and full XCTest NOT_RUN.
