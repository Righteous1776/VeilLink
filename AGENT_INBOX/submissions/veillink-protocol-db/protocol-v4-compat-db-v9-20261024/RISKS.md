# R3 Protected Surface / Risk Register

P0: New wire kind 10 plus db v9/v10 are protected. Do not merge product code or start release from the Inbox branch.
P1: Legacy Wire v4 peers cannot decode new kind 10. Capability gating is mandatory; handshake signatures and crypto v4 stay unchanged.
P1: Inbound control journal is bounded to 256 entries/peer. This is **not** a durable exactly-once business execution proof once IDs age out. Every feature-level consumer needs idempotency.
P1: New v10 outbox is encrypted and recipient-scoped but currently lacks transport draining, real control ACK emission/processing and reconnect scheduling; cannot claim reliable delivery until those are integrated and device-tested.
P1: Control receipt API relies on trusted authenticated caller; every future inbound receipt handler must check sender identity, public key, event ID and anti-replay before invoking it. Never mark delivered on local send alone.
P1: `enqueueDurableControlEvent` validates capacity prior to an independent writeBatch call; concurrent enqueues could overshoot 512-event soft limit. Integration should move quota enforcement into the same transaction or serialize producer admission. This is a known preproduction limitation.
P2: 7-day expiry is a bounded policy, not infinite offline persistence; product UX must disclose expiration/undelivered state after receipt wiring.
P2: v10 encrypted payload uses the existing Keychain storage key. Backup/key mismatch and protected-data lock tests are mandatory.
P2: Tombstones and old message dedup are unchanged. Migration is additive and needs a rollback snapshot, not a destructive downgrade.
OVERLAP: PR #53 includes future DB9 capability plan. PR #57 TrollStore gate must not become a transport/identity authority. Resolve semantics by Governor.
STATUS: REVIEW_REQUIRED; iOS native/XCTest/physical device run outstanding.
