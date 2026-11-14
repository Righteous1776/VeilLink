# VeilLink Agent Inbox Manifest

agent_id: ui-particle-removal-agent
task_id: 20261114-remove-global-particles-r1
base_main_sha: af3d823546c288169d19cb3033a6111977d28bd7
mode: INBOX_ONLY
status: DROPPED
asset_grant: none; no binaries
scope: remove app-wide decorative particle overlay, its event token and unused render policy/tests; preserve scoped game/feature effects

## Proposed product files
- `VeilLink/App/VeilLinkApp.swift`
- `VeilLink/UI/VeilAdaptiveParticleLayer.swift`
- `VeilLink/Core/VeilParticlePerformancePolicy.swift`
- `VeilLinkTests/VeilParticlePerformancePolicyTests.swift`

## Submitted artifacts
- MANIFEST.md
- PROPOSAL.md
- PATCH.diff
- TEST_PLAN.md
- RISKS.md

No product, workflow, version, main, release or signing files have been directly mutated.
