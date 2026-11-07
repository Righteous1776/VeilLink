# VeilLink Protocol + Database R5 — Governor Inbox Submission

agent_id: veillink-protocol-db
task_id: protocol-v4-compat-db-v9-20261024
base_main_sha: 8048b5c52b87eeb5d3622582da5728a8c2d64dda
submission_path: AGENT_INBOX/submissions/veillink-protocol-db/protocol-v4-compat-db-v9-20261024/
mode: INBOX_ONLY
status: DROPPED / CUMULATIVE R5 / GOVERNOR REVIEW REQUIRED
patch_apply_order: PATCH.diff THEN PATCH_STAGE2.diff THEN PATCH_STAGE3.diff THEN PATCH_STAGE4.diff THEN PATCH_STAGE5.diff
product_protocol_envelope: Wire v4 (UNCHANGED)
new_optional_hello_extension: schema 1; featureBits 0..7; detached Ed25519 identity signature over session-bound extension transcript
legacy_chat_ack_extension: backward-compatible capability bits; R2-compatible masked fallback
database_target: v8 -> v9 -> v10 (previous stages unchanged)
proposed_files: VeilLink/Security/SessionCoordinator.swift; VeilLink/Storage/DatabaseStore.swift; VeilLink/Core/WireCodec.swift; VeilLink/Core/VeilControlEvent.swift; VeilLink/Core/VeilPeerCapabilityPolicy.swift; VeilLinkTests/DatabaseStoreTests.swift; VeilLinkTests/VeilControlEventCodecTests.swift; VeilLinkTests/VeilPeerCapabilityPolicyTests.swift; VeilLinkTests/VeilHelloCapabilityTests.swift
protected_surfaces: identity signatures; session handshake; authenticated control transport; SQLite schema and migration
new_files_this_stage: VeilLinkTests/VeilHelloCapabilityTests.swift
overlap: PR #53 TrollStore capability plan; PR #57 runtime readiness policy; Governor arbitration mandatory
asset_grant: none
physical_ios_build_and_test: NOT RUN
