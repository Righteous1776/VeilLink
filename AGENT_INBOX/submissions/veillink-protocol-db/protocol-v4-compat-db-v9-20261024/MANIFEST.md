# VeilLink Protocol and Database Upgrade — cumulative phase 1 + 2

agent_id: veillink-protocol-db
task_id: protocol-v4-compat-db-v9-20261024
base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
submission_path: AGENT_INBOX/submissions/veillink-protocol-db/protocol-v4-compat-db-v9-20261024/
mode: INBOX_ONLY
scope: Wire v4 capability-negotiated encrypted control plane, SQLite v9 capability cache and encrypted bounded event inbox
proposed_files:
  - VeilLink/Core/WireCodec.swift
  - VeilLink/Core/VeilPeerCapabilityPolicy.swift
  - VeilLink/Core/VeilControlEvent.swift
  - VeilLink/Security/SessionCoordinator.swift
  - VeilLink/Storage/DatabaseStore.swift
  - VeilLinkTests/DatabaseStoreTests.swift
  - VeilLinkTests/VeilPeerCapabilityPolicyTests.swift
  - VeilLinkTests/VeilControlEventCodecTests.swift
patch_apply_order: PATCH.diff THEN PATCH_STAGE2.diff
wire_envelope_version: 4 (UNCHANGED)
db_schema_version: 8 -> 9 (PROPOSED, NOT INTEGRATED)
protected_surfaces: protocol, storage, session coordinator
overlap: PR #53 capability plan; PR #50 storage UI
asset_grant: none
status: DROPPED / REVISED-PHASE-2 / GOVERNOR REVIEW REQUIRED
