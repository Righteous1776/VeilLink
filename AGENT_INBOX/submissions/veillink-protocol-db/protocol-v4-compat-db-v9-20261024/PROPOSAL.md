# VeilLink protocol + database upgrade proposal (2026-10-24)

**Base:** `8048b5c52b87eeb5d3622582da5728a8c2d64dda`. This is a full Inbox patch proposal, not an applied release.

## Protocol compatibility
Wire envelope still has version 4, identical signed Hello payload, identical X25519/ChaChaPoly encryption and unchanged replay/identity checks. ACK remains authenticated; two optional JSON fields (`capabilitySchema=1`, `capabilityBits=1`) announce extension support. Legacy Swift Codable decoders ignore these extra fields; new decoders tolerate missing or malformed extension fields. No extra frame is sent; ordinary ACK is still delivered. Unknown feature bits do not grant capabilities. Feature bit 0 only advertises that the peer supports the ACK metadata extension; it is **not** an unlock for LAN, relay, groups, trust, or compute governor.

## SQLite v9
Add an additive `peer_capabilities` table with composite local/peer identity key; SHA-256 fingerprint of the trusted peer's identity public key; version, bits, and timestamp. Read/write verify the existing trusted key and TTL 30 days. No message/attachment/queue mutation. New table + index + schema_migrations 9 marker share one SQLite transaction. Repeat migration is idempotent. Old v8 backup restores should migrate on open. Backup package format remains unchanged.

## Integration instructions
1. Governor reviews Issue #6 and intersects PR #53 planned v9 compatibility work; no automated merging of overlapping designs.
2. Apply `PATCH.diff` to a dedicated integration branch after refreshing main; verify no version/build/workflow changes.
3. Execute XcodeGen, iOS Simulator build/XCTest, SQLite fresh/v8 upgrade/idempotence/restore, and old/new device cross-compat tests on BLE and approved LAN/relay.
4. Governor authorizes protected-surface merge only after passing gates. No IPA or release action here.

## Exclusions
No Wire v5 mandatory version bump, no key rotation, no cryptographic algorithm replacement, no destructive migration and no weight/brain model import.
