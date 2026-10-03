# Agent Inbox Queue

This index is maintained by the Integration Governor.

Agents must not edit queue state directly.

| Submission | Agent | Task | Base main | Status | Batch | Notes |
|---|---|---|---|---|---|---|
| `AGENT_INBOX/submissions/VL-MAINT-EDGE-001/swift6-deeptelemetry-notification-sendability-001/` | `VL-MAINT-EDGE-001` | Swift 6 DeepTelemetry Notification sendability | `c81f266e0032a1d0868cb25ddc26b690ddea4e43` | `TRIAGED` | — | PR #14; manual Intake PASS + machine Gate PASS; real 8-warning issue confirmed; product patch not authorized |
| `AGENT_INBOX/submissions/game-agent/orbit-relay-game-lab/` | `game-agent` | Local Game Mission Contracts + Orbit Relay Game Lab | `c81f266e0032a1d0868cb25ddc26b690ddea4e43` | `TRIAGED` | — | PR #15; migrated from legacy #4; direct overlap with product-restoration at `MiniGameViews.swift`; product patch not authorized |
| `AGENT_INBOX/submissions/VL-MAINT-EDGE-001/swift6-appearance-shared-mainactor-002/` | `VL-MAINT-EDGE-001` | Swift 6 Appearance singleton MainActor isolation | `c81f266e0032a1d0868cb25ddc26b690ddea4e43` | `TRIAGED` | — | PR #16; warning independently confirmed; one-file proposal; product patch not authorized |

Allowed states:

`DROPPED` · `TRIAGED` · `ACCEPTED` · `DEFERRED` · `REJECTED` · `BATCHED` · `APPLIED` · `VERIFIED` · `ARCHIVED`

## Current rule

`TRIAGED` means the submission is structurally valid and has passed Governor intake review.

It does **not** mean the proposal has been accepted for product application.

Only an explicit Integration Governor batch decision may advance a submission to `ACCEPTED` or `BATCHED`.
