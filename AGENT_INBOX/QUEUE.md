# Agent Inbox Queue

This index is maintained by the Integration Governor.

Agents must not edit queue state directly.

| Submission | Agent | Task | Base main | Status | Batch | Notes |
|---|---|---|---|---|---|---|
| `AGENT_INBOX/submissions/VL-MAINT-EDGE-001/swift6-deeptelemetry-notification-sendability-001/` | `VL-MAINT-EDGE-001` | Swift 6 DeepTelemetry Notification sendability | `c81f266e0032a1d0868cb25ddc26b690ddea4e43` | `APPLIED` | `2026-10-03` | Narrow callback repair applied in `7825877`; macOS strict-concurrency CI remains required before `VERIFIED`. |
| `AGENT_INBOX/submissions/game-agent/orbit-relay-game-lab/` | `game-agent` | Local Game Mission Contracts + Orbit Relay Game Lab | `c81f266e0032a1d0868cb25ddc26b690ddea4e43` | `DEFERRED` | `2026-10-03` | Raw one/two-frame UI and synchronous bot search were not accepted; replaced in this batch by separately reviewed real-time SpriteKit games. |
| `AGENT_INBOX/submissions/VL-MAINT-EDGE-001/swift6-appearance-shared-mainactor-002/` | `VL-MAINT-EDGE-001` | Swift 6 Appearance singleton MainActor isolation | `c81f266e0032a1d0868cb25ddc26b690ddea4e43` | `APPLIED` | `2026-10-03` | Narrow singleton isolation applied in `7825877`; full Apple SDK build remains required before `VERIFIED`. |

Allowed states:

`DROPPED` · `TRIAGED` · `ACCEPTED` · `DEFERRED` · `REJECTED` · `BATCHED` · `APPLIED` · `VERIFIED` · `ARCHIVED`

## Current rule

`TRIAGED` means the submission is structurally valid and has passed Governor intake review.

It does **not** mean the proposal has been accepted for product application.

Only an explicit Integration Governor batch decision may advance a submission to `ACCEPTED` or `BATCHED`.
