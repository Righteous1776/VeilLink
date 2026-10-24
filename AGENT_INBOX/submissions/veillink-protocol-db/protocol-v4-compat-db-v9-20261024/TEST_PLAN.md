# TEST_PLAN — cumulative Wire v4 extension / DB v9

1. Patch sequence: fresh checkout exact main -> `git apply --check PATCH.diff` -> apply -> `git apply --check PATCH_STAGE2.diff` -> apply -> `git diff --check`; reject any patch context mismatch.
2. Legacy v4 peer must accept extended ACK by ignoring unknown JSON fields, without receiving WireKind 10. A new peer gets `unsupportedLink` before trusted capability bit 1 is observed.
3. `VeilPeerCapabilityPolicyTests`: schema 1 accepted bits 0/1/2/3; schema mismatch, bits 4, negative, malformed optional fields rejected without breaking ACK.
4. `VeilControlEventCodecTests`: v4 envelope and v1 control roundtrip, >24 KiB reject, invalid event ID/topic/schema reject.
5. `DatabaseStoreTests`: authenticated local-peer isolation, public key mismatch, duplicate control event rejection, encrypted store readback, bounded inbox 256/event sender, foreign key cascade, repeat v8->v9 migration.
6. Full XCTest and XcodeGen macOS build; BLE handshake/reconnect old iPhone 7/iOS15 to current iPhone, LAN and relay authorization, replay/tampered AAD, disabled bit, noisy transport, attack/corruption, backup restore.
7. Governor merge gates: compare PR #53, preserve version/build, no release workflow mutations, real physical devices, no leak of control payload in diagnostics.

## Evidence status
Exact source context and all unified diff hunk header counts checked for stage 2. Native Xcode/XCTest, real-device tests and iOS CI have not been run on the proposed product source. A passing Inbox Gate only checks staging governance.
