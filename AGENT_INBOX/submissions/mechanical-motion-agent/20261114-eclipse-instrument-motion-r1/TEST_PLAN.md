# Test Plan / R1

## Static validation already performed
- Pin source to `af3d823546c288169d19cb3033a6111977d28bd7` and verify each source-edit anchor is unique.
- Generate exact-context five-file unified diff; hunk count verification PASS.
- Confirm old Nearby `RadarStatusView` and `repeatForever` have been removed from the proposed version. (The **current main** is intentionally unchanged.)
- Confirm no modifications to project.yml, workflow, signing, legal, database, identity, transport, release, or settings.

## Required pre-integration gates
1. `git apply --check PATCH.diff` from recorded base (or rebase patch if main advances).
2. Run Swift core tests `VeilMechanicalMotionCoreTests` and XcodeGen iOS simulator build, full XCTest/UI smoke and unsigned device Release compile on exact integration SHA. Do not claim these tests passed based on static inspection.
3. Nearby: start/stop BLE scanning; actuator moves only while scanner runs and PARKS on stop. Actual nearby count updates, including 0 and multiple peers.
4. Pair/recover: ensure touch/pair/recovery buttons, scroll, back gesture, and input focus remain fully usable.
5. Peer card: confirm the 8-step gauge accurately follows actual linkSnapshot.healthScore 0, 1, 50, 75, 100; no fabricated percent or bandwidth.
6. Agent status: unloaded/unavailable/ready static, loading/generating moving. Cooling static. No AI payloads or private search candidates leak into UI.
7. Reduce Motion and Low Power Mode: no continuous frame advancement. App background/inactive: no TimelineView motor work. Legacy compositor: existing VeilMotionPolicy limits respected.
8. iPhone portrait narrow content, iPad regular layout, Plainline/Instrument/Apple Soft day-night/Islet palettes: inspect clipping and contrast for 54pt CPU and 86pt RF instruments.
9. Integrate global particle removal #229 first or alongside after Governor arbitration; verify no app-wide overlay remains.

## Status
- In-memory exact-anchor substitution PASS.
- Unified-diff five-file line-count verification PASS.
- No Apple Xcode / iOS simulator / XCTest / IPA / real radio validation has run.
