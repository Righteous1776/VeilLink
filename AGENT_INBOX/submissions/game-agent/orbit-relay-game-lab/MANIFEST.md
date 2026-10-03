# MANIFEST

- agent_id: `game-agent`
- task_id: `orbit-relay-game-lab`
- mode: `INBOX_ONLY`
- base_main_sha: `c81f266e0032a1d0868cb25ddc26b690ddea4e43`
- submission_path: `AGENT_INBOX/submissions/game-agent/orbit-relay-game-lab/`
- source_evidence: legacy direct PR #4, head `3fa2307841e7a5c76ee80a7dbd888b88b0911715`
- source_evidence_status: read-only evidence only; not an integration authority
- scope: migrate the additive Local Game Mission + Orbit Relay Game Lab proposal into Agent Inbox without modifying the product tree
- governance: VeilLink Agent Inbox V1 / Governor `VEILLINK-IG-001`

## Proposed product files

1. `VeilLink/Core/LocalGameMissionDirector.swift`
2. `VeilLink/Core/LocalGameMissionEvaluator.swift`
3. `VeilLink/Core/OrbitRelayGame.swift`
4. `VeilLink/UI/LocalGameMissionStrip.swift`
5. `VeilLink/UI/MiniGameViews.swift`
6. `VeilLink/UI/OrbitRelayLabView.swift`
7. `VeilLinkTests/LocalGameMissionTests.swift`
8. `VeilLinkTests/OrbitRelayGameTests.swift`

## Protected surfaces

No proposed changes to version/build values, workflows, release/signing/packaging, transport, storage, identity, wire protocol, database schema, A9/A10 governance, or project configuration.

## Baseline validation

`VeilLink/UI/MiniGameViews.swift` has identical blob SHA `099eae5c3b7cfd190b2e5f22656ef6136668b169` at legacy PR #4 base `2851b6d6f48ca5030dd5fddba9985e4f4baafade` and current base `c81f266e0032a1d0868cb25ddc26b690ddea4e43`. The other seven proposed files are additive new files. Therefore this submission's patch is rebased to the exact current Inbox-enabled main baseline without carrying old branch history.
