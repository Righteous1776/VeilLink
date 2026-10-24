# VeilLink Protocol/Database R4 — Governor Staging

agent_id: veillink-protocol-db
task_id: protocol-v4-compat-db-v9-20261024
base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
submission_path: AGENT_INBOX/submissions/veillink-protocol-db/protocol-v4-compat-db-v9-20261024/
mode: INBOX_ONLY
status: DROPPED / R4 / GOVERNOR REVIEW REQUIRED
patch_apply_order: PATCH.diff THEN PATCH_STAGE2.diff THEN PATCH_STAGE3.diff THEN PATCH_STAGE4.diff
wire_envelope_version: 4 (unchanged)
wire_optional_control_kinds: 10 (event), 11 (receipt)
wire_feature_bits: bit0 ACK extension; bit1 control event; bit2 encrypted reliable receipt
database_migrations: v8 -> v9 -> v10 (additive; none integrated)
protected_surfaces: WireCodec, SessionCoordinator, DatabaseStore, database migrations
proposed_files: VeilLink/Core/WireCodec.swift; VeilLink/Core/VeilPeerCapabilityPolicy.swift; VeilLink/Core/VeilControlEvent.swift; VeilLink/Security/SessionCoordinator.swift; VeilLink/Storage/DatabaseStore.swift; VeilLinkTests/DatabaseStoreTests.swift; VeilLinkTests/VeilPeerCapabilityPolicyTests.swift; VeilLinkTests/VeilControlEventCodecTests.swift
overlap: PR #53 TrollStore capabilities and DB v9 planning; PR #57 independent runtime gate
native_ios_ci: NOT_RUN
physical_device_test: NOT_RUN
asset_grant: none
