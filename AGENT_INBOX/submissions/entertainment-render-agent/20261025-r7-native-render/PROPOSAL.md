# R7 Rendering Hardening — Full, Auditable Submission

toolcenter_group: 娱乐
depends_on: Wave 0; R4 E191 rules, R5 #79, R7 #86

device_focus: iPhone7 iOS15.8.3 GPU/thermal/touch; 12Hz HUD + 30fps requested SpriteKit.

## Why this replaces the earlier partial R7 drop

The entire **13-file** R7 candidate is now staged under this same Inbox FILES directory. `PATCH.diff` includes ALL 13 paths exactly; two R7 scene/UI files are present rather than ZIP-only. This complete R7 version supersedes R6 proposal PR #83 for overlapping renderer filenames; do not import both.

- Fixed 390×600 virtual SpriteKit `.aspectFit` scene (no uniform nonproportional scaling).
- Bounded deterministic chart cache (16 notes per seed and district).
- 280ms running snapshot stale watchdog; tolerate 15ms positive clock skew; pause deliberately holds state.
- Bounded 240-callback rolling timing metrics (not measured GPU time).
- Four accessible SwiftUI 56pt minimum-height lane buttons OUTSIDE ScrollView; HUD requests 12Hz, SpriteKit requests 30fps.
- Renderer never owns BLE traffic, user keys, messages, network identity or A9/A10 governance.

## Proposed Wave 1 convergence

`WAVE1_COMBINED_CANDIDATE.diff` is an **advisory** 20-source/test-file R4 E191 + R5 + R7 combined patch. It contains each target path once and carries R5 #79 engine/test dependencies; Governor may choose a different subset after source review. It does NOT include ToolCenter navigation, the disputed R4 gate (#78, eight vs nine IDs) or an iOS IPA workflow. The owner decision on #78 is preserved.

The submitted matrix `WAVE1_REVIEW.md` explicitly records Wave 0 P0 as blocking and integration as Governor-only.
