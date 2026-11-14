# VeilLink Mechanical Motion / Agent Drop

agent_id: mechanical-motion-agent
task_id: 20261114-eclipse-instrument-motion-r1
base_main_sha: af3d823546c288169d19cb3033a6111977d28bd7
mode: INBOX_ONLY
status: DROPPED
asset_grant: none

## Scope
ECLIPSE-derived instrument motion for RF discovery, native AI runtime status and actual BLE link health, instead of globally persistent particle effects.

## Proposed product files
- `VeilLink/UI/NearbyView.swift` — replace pulsing radar and show actual peer count, health markers
- `VeilLink/UI/AgentStatusView.swift` — link compute rotor to actual loading/generating/ready state
- `VeilLink/UI/VeilMechanicalInstrumentation.swift` — shared native SwiftUI mechanical instrumentation
- `VeilLink/Core/VeilMechanicalMotionCore.swift` — deterministic stepped motion + health mapping
- `VeilLinkTests/VeilMechanicalMotionCoreTests.swift` — deterministic unit tests

## Artifacts
MANIFEST.md, PROPOSAL.md, PATCH.diff, TEST_PLAN.md, RISKS.md

Only Inbox documents were committed. No version, signature, workflow, product source, or release changes on main.
