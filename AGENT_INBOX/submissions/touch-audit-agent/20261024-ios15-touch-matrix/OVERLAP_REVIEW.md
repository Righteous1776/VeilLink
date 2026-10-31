# Governor overlap notice — 2026-10-24

## Shared draft branch and collision

The GitHub branch `agent-drop/touch-gesture-audit-20261024` now contains **two independent Inbox submissions**:

1. `AGENT_INBOX/submissions/touch-reliability-agent/20261024-gesture-hit-test-audit/` — 9 source files, compact 22-hunk candidate patch, associated with Draft PR #65.
2. `AGENT_INBOX/submissions/touch-audit-agent/20261024-ios15-touch-matrix/` — 9 source files, independent 9-hunk candidate patch, also in PR #65.

**Both are merely Inbox proposals. No product source has been edited on this branch.** The two PATCH.diff files are alternatives for overlapping files, NOT sequential patches. Applying both verbatim would fail or reintroduce bugs.

## Source overlap (seven files)

- `VeilLink/UI/VeilReleaseActivationView.swift`: reliability-agent preserves swipe using simultaneous horizontal-only behavior; touch-audit-agent temporarily removes swipe entirely. Prefer preserving existing functionality if iOS15 scrolling can be proved reliable.
- `VeilLink/UI/ToolCenterView.swift`: both propose held-PTT interruption cleanup; reconcile actual radio transmitter states.
- `VeilLink/UI/MiniGameViews.swift`: reliability-agent proposes UIKit tap-only recognizer; touch-audit-agent proposes threshold guard for existing zero-distance drag. Prefer tap-only recognizer after confirming nonzero-sized UIKit representable hit bounds and parent-scroll coexistence on iOS15.
- `VeilLink/ArcadeRealtime/PlatformerView.swift`: both latch jump and release on lifecycle interruption; take one implementation.
- `VeilLink/UI/TacticalV2/TacticalLandscapeShellV2.swift`: both suggest map minimumDistance=0; accept only if route drag semantics remain correct.
- `VeilLink/UI/SignalDiveLabView.swift`, `VeilLink/UI/BlackoutDistrictLabView.swift`: both add held control lifecycle cleanup; take one.

## Nonoverlapping candidate surfaces

- Reliability-agent unique: `AfterglowConvoyLabView.swift`, `AshHarborLabView.swift`; include only if scene lifecycle commands are idempotent.
- Touch-audit-agent unique: `FullScreenImageViewer.swift` (single vs double tap arbitration), `VeilAppleMaterialEngine.swift` (decorative border hit testing). Defer image tap gesture if pinch/dismiss conflicts cannot be verified on iOS15.
- PR #64 separately covers global particle root gesture, with no overlap in filenames here.

## Integration decision

A Governor-controlled branch may select one per-file fix, with manual conflict review, regression tests, Xcode compilation and iPhone7 iOS15 physical touch verification. **Do not** chain the two PATCH.diff files, auto-merge Draft PR #65 or start IPA workflow.

## Quality gates before adoption

- Verify UIViewRepresentable tap surface gets board-sized frames in `ZStack` on iOS15; if not, force explicit matching frame and unit/UI-test hit bounds.
- Ensure no accidental game command on finger movement and no invisible view swallowing ScrollView pans on off-turn boards.
- Validate parent simultaneous swipe only changes pages for genuine horizontal swipes, not when adjusting a Slider or using system back.
- Verify `scenePhase` and `onDisappear` repeated stop calls do not reset game state or keychain/data.
