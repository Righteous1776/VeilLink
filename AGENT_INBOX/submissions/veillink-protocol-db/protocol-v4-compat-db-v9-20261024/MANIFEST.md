# VeilLink Wire + Database Architecture — Cumulative R3

agent_id: veillink-protocol-db
task_id: protocol-v4-compat-db-v9-20261024
base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
submission_path: AGENT_INBOX/submissions/veillink-protocol-db/protocol-v4-compat-db-v9-20261024/
mode: INBOX_ONLY
scope: authenticated control channel + encrypted inbound journal + normalized per-recipient durable outbound journal
wire_envelope_version: 4 (UNCHANGED)
database_schema_migrations: v8 -> v9 -> v10 (PROPOSED)
patch_apply_order: PATCH.diff THEN PATCH_STAGE2.diff THEN PATCH_STAGE3.diff
patch3_proposed_files: VeilLink/Storage/DatabaseStore.swift; VeilLinkTests/DatabaseStoreTests.swift
patch1_and_2_files: VeilLink/Core/WireCodec.swift; VeilLink/Core/VeilPeerCapabilityPolicy.swift; VeilLink/Core/VeilControlEvent.swift; VeilLink/Security/SessionCoordinator.swift; VeilLink/Storage/DatabaseStore.swift; VeilLinkTests/DatabaseStoreTests.swift; VeilLinkTests/VeilPeerCapabilityPolicyTests.swift; VeilLinkTests/VeilControlEventCodecTests.swift
protected_surfaces: wire protocol; authenticated session; SQLite schema and migration; local data safety
overlap: PR #53 TrollStore/DB9 proposal; PR #57 runtime readiness gate (must remain independent of identity/transport trust)
status: DROPPED / R3 / GOVERNOR REVIEW REQUIRED
