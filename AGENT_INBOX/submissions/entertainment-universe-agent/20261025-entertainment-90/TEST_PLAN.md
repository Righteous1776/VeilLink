# TEST PLAN — candidate evidence and missing gates

## Verified outside this GitHub draft (in local ZIP)

- Linux Swift 6.2.1 Foundation-only typecheck: PASS.
- SwiftPM: 26 XCTest cases, 0 failed (10 E01, 8 E04/E06, 8 E11).
- Focus: deterministic replay, JSON round trip, malformed choices, editor undo/redo, max-size guards, 50 seeds x 3 floors with always-passable path, three-floor completion.
- Add-only full product patch: git apply --check PASS in isolated scratch repository.
- iOS SwiftUI files: syntax parse only. No Apple SDK available locally.

## Not verified

- macOS XcodeGen project, iOS build and iOS XCTest.
- iPhone7 iOS15.8.3 hardware, signing, first-consent flow, touch gesture conflicts.
- Real-device power/thermal and accessibility audit.
- Production App entry point, database persistence, multiplayer transport.

## GitHub draft limitation

This GitHub PR does not include candidate Swift source or the full 118483-byte product PATCH.diff. Its PATCH.diff is intentionally empty; the complete verified patch is in the externally delivered local ZIP, SHA-256 recorded in MANIFEST. Do not mark feature integration complete.
