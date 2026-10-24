# R3 TEST PLAN — compatibility + durable multi-recipient outbox

### Static and unit
1. On a clean clone pinned at `8048b5c52b87eeb5d3622582da5728a8c2d64dda`: `git apply --check PATCH.diff`, apply, `git apply --check PATCH_STAGE2.diff`, apply, `git apply --check PATCH_STAGE3.diff`, apply. `git diff --check`.
2. `VeilPeerCapabilityPolicyTests`: backward ACK decode, schema mismatch, enabled bits 0..3, unknown bit rejection.
3. `VeilControlEventCodecTests`: canonical event IDs, schema bounds, topic sanitation, encrypted Wire4 kind 10 roundtrip.
4. `DatabaseStoreTests`: trusted first-contact boundary, identity scoped encrypted inbound, duplicate suppression, database integrity; new R3 tests with two trusted recipients, identical re-enqueue, conflicting event UUID payload reject, forged peer acknowledgment reject, peer A acknowledgment preserving peer B outbox, accepted-send backoff, final recipient garbage collection, untrusted recipient atomic rejection.
5. v8 fixture -> v9 -> v10 repeated startup, FK cascade, failure rollback, 7-day expiry, 512-event quota, key mismatch/locked Keychain, encrypted backup v2 export/restore with old user data.

### Device and CI
- full iOS 15 Simulator compile/XCTest; install ordinary signed iPhone 7 and modern iPhone; BLE v4 old/new bidirectional text, attachment resume and control capability negotiation.
- Test control events only between peers that advertised bit 1. Absent bit -> no unknown kind 10 sent.
- Send queue is NOT currently wired. Verify no accidental UI promise or unsolicited control traffic until a follow-on receipt actor is implemented.
- Test on BLE, LAN and Internet Relay separately; do not use installation channel (including TrollStore) to bypass the BLE-first trust rule.

### Executed evidence
- Unified diff context/hunk counts checked against exact stage source in this session for stage 1, 2 and 3.
- Python sqlite3 in-memory simulation **PASS**: v9/v10 repeated, preserved legacy data, one event with two recipient rows, independent ack + event GC, FK rejection of unknown peer, trust deletion cascading target rows, integrity_check=ok.
- Native Xcode, XCTest, real-device transport and production recovery: **NOT RUN**; required for promotion.
