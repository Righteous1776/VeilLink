# [AGENT-DROP] Wave 1 source review (NOT a product integration)

- `toolcenter_group: 娱乐`
- `depends_on: Wave 0 (#64–#66); R4 E191 runtime only; R5 PR #79; R7 PR #86`
- `device_focus: iPhone 7 iOS 15.8.3 GPU / 280ms watchdog / 15ms skew / 12Hz HUD / 30fps target`
- Current main verified at `501ef814a0a9bea41419fe2d9f48315371b30320`.

## Integration candidate

`WAVE1_R5_R6_R7_GOVERNOR_CANDIDATE.diff` is a **proposed** additive 20-file patch; it is not applied to product code.

Input provenance:
- R4 E191 rule engine: local R7 SwiftPM baseline; no E192 feature-gate change, owner decision remains open.
- R5 conductor + E192 station engine + original iOS smoke test: PR #79; no duplicate filename with R7.
- R6 geometry, timeline, frame pacer + R7 revised SpriteKit scene/UI/cache/frame stats + tests: PR #86. R7 supersedes R6 PR #83 for these files.
- Supplemental rule, conductor, station XCTest sources from the same R7 SwiftPM baseline. These are unit tests, not iOS images.

## Mandatory sequence

1. **Wave 0 iPhone 7 P0**: legal-first-sign, touch, data continuity pass and Governor `[MERGE-EVENT]`.
2. Governor chooses R4 gate solution (8 vs 9 candidate IDs), no implicit merge of R4 #78.
3. Freeze fresh main, verify all source SHA-256, and use `git apply --check --whitespace=error-all` on isolated branch.
4. Build iOS15 via XcodeGen, compile SwiftUI/SpriteKit and XCTest. Reconcile imports and any iOS-only diagnostics failures.
5. Exercise device viewport, touch, 20min thermal, foreground/resume, dark/light switch, 280ms watchdog and clock skew.
6. Owner/Governor authorizes release separately; **never call IPA workflow in this lane**.

## Proven evidence

- Linux Swift 6.2.1 `swift test -j 2` **128/128 PASS** (re-executed on 2026-10-25); source documentation changes are comment-only.
- `git apply --check --whitespace=error-all` on clean isolated git fixture for both proposed patches: PASS.
- iOS SDK compile: PENDING (no local macOS SDK).
- Real iPhone 7 / measured FPS / GPU / energy: PENDING (no connected phone).

No ToolCenterView or GameLobbyView hunk is included. The Governor owns final navigation arbitration.
