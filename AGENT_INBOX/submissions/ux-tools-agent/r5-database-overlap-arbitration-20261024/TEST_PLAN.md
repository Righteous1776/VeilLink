# TEST PLAN — exact-head R5 integration matrix

## Already performed by this Lane
- Build 59 exact main `8048b5c52b87eeb5d3622582da5728a8c2d64dda`: all five PR #56 patch files replayed sequentially in memory; strict hunk counts and old context match: PASS.
- 9 distinct proposed Swift source/tests touched; five source snapshots cumulative, no GitHub product write.
- Synthetic sqlite3 fixture representing essential v8 keys and messages: run v9 and v10 DDL twice, preserve legacy blob, check schema_migrations 8/9/10, foreign_key_check, integrity_check, and per-recipient cascade: PASS.
- Proposed Python checker independently syntax-checked and passed against an equivalent synthetic Swift DDL fixture (NOT production app).

## Governor-only native compile gates
- `git apply --check` then `git apply` in R1,R2,R3,R4,R5 order, with commit after each gated stage.
- `git diff --check` and XcodeGen; iOS 15 Swift compile; **fix every real compiler diagnostic** on controlled branch, then rerun the whole gate.
- Full XCTest, not just new tests. Mandatory suites: DatabaseStoreTests, VeilPeerCapabilityPolicyTests, VeilControlEventCodecTests, VeilHelloCapabilityTests, existing Wire/Session/backup/transport suite.

## Actual v8 database fixtures (not synthetic)
- Existing data: text messages, incoming/outgoing statuses, attachments, contacts and trust, identity-scoped rows, pinned conversations, old outbound_queue.
- Back up before test; verify DB hash/row counts/blob bytes, restore after failure.
- Upgrade v8→v9→v10, restart app and run idempotently; interrupt before v9 marker, before v10 marker, retry recovery; transaction rollback on invalid SQL.
- `PRAGMA integrity_check` = ok; `foreign_key_check` empty; no old message ciphertext/key mutation; no duplicate migration versions.
- Multiple local identities sharing same remote identity: caches independent, bound to trusted key fingerprint; 30-day expired cache must not authorize transport.
- Two recipients: one ACK does not clear the other; invalid/duplicate receipt harmless; backoff, expiry, 16 recipient / 512 outbound / 256 inbound quotas; cancellation and reconnect.

## Compatibility and adversarial matrix
- R5↔R5 valid separately signed Hello: feature bits usable only after original Hello signature+second proof and pinned trust.
- R5↔R4 valid v4 handshake; new control channel waits for genuine encrypted ACK; no fake chat.
- R5↔R2 no unrecognized ACK high bits: default bits3, upgrade to 7 only on verified bit2 support.
- R5↔original v4 only legacy chat/media and existing ACK; unknown extension fields ignored.
- Tamper signed Hello nonce/ephemeral/identity: reject original signature. Tamper optional bits/signature: secure v4 fallback, no enhanced rights.
- Strip optional feature extension: no advanced grants, no bypass; redacted diagnostic recommended.
- Replay a prior Hello extension: rejected due ephemeral/nonce binding.
- BLE old iPhone 7 iOS 15 real MTU fragmentation, reassembly timeout, 2 walls weak-link; Wi-Fi/LAN/relay compatibility where available; airplane/no cellular base chat.

## Final gates
- All iOS CI + XCTest PASS on exact proposed merge SHA, old/new device matrix PASS, real v8 restore PASS.
- Review backup portability and downgrading to an older installed app before deciding release.
- Main merge and IPA signing/release **not authorized by this Inbox proposal**; separate Governor/owner promotion action required.
