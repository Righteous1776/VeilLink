# PROPOSAL — PR #53 / #56 and R1–R5 integration decision

## Verified facts

main = `8048b5c52b87eeb5d3622582da5728a8c2d64dda`, VeilLink 26.13 Build 59, Wire v4, SQLite v8.

PR #53 is a Draft Inbox drop. Its COMPATIBILITY_PLAN.md suggests future v9 peer capabilities table with local/peer identity, protocol floor/ceiling, feature bits, observed_at and expires_at. Its actual PATCH.diff does **not** change wire or schema. Its code contribution is TrollStore runtime detection and Settings UI. Markers are not a cryptographic trust root.

PR #56 is a Draft Inbox drop with five sequential product diffs, **none applied to main**. Its R1 v9 contains a more security-specific peer_capabilities with local_identity_id, peer_identity_id, public_key_sha256, capability_schema_version, feature_bits and observed_at. R2 adds control_event_inbox in v9; R3 adds control_outbound_events plus independent control_outbound_targets and migration marker v10. R4 adds authenticated receipts/retry; R5 adds independently signed optional Hello metadata.

## Recommendation to Integration Governor (NOT self-applied)

**Select the PR #56 v9/v10 schema as the sole implementation candidate.** Treat PR #53's v9 schema as a superseded design idea. Do NOT independently run a second v9 migration or introduce another peer_capabilities definition.

### Field-level arbitration

| PR #53 proposed field | PR #56 implementation | Decision |
|---|---|---|
| local_identity_id + peer_identity_id | same composite primary key | accept PR #56 |
| feature_bits | feature_bits CHECK 0..1048575 | accept with schema-based validation |
| protocol_floor / protocol_ceiling | no persisted fields | DEFER; wire envelope remains v4, signed optional capability schema separate |
| observed_at | observed_at REAL | accept |
| expires_at | derived read-time TTL = observed_at + 30 days | retain derived TTL; do not add duplicate column in v9 |
| key binding | PR #56 public_key_sha256 BLOB(32), plus trusted-contact lookup | accept as security improvement |
| installation channel | never persisted as authority | keep TrollStore detection UI-only; no trust coupling |

If permanent per-peer protocol bounds or explicit expiry storage are later required, propose **a distinct v11 migration** after R5 is proven; do not redefine v9 once shipped.

### Single ordered integration plan (Governor only)

1. Snapshot current `main`, tag an internal recovery reference without publishing a release, back up a representative v8 database, and fix the integration branch base SHA at 8048b5c52b87eeb5d3622582da5728a8c2d64dda.
2. Create a dedicated Governor-controlled integration branch (not either draft Inbox branch).
3. Apply PR #56 R1 `PATCH.diff`; perform exact `git apply --check` / `git diff --check`.
4. Apply R2 `PATCH_STAGE2.diff`; verify v9 now contains both `peer_capabilities` and `control_event_inbox`, one migration marker v9.
5. Apply R3 `PATCH_STAGE3.diff`; verify normalized ciphertext-once event and independently queued recipient rows, marker v10 and foreign keys.
6. Apply R4 `PATCH_STAGE4.diff`; verify authenticated kind11 receipt, retry, disconnect/reconnect, per-recipient GC and the bounded queue quotas.
7. Apply R5 `PATCH_STAGE5.diff`; verify old Hello/v4 signed payload and HKDF transcript unchanged and optional second Ed25519 proof. R5 optional feature negotiation must never supersede identity trust.
8. Merge **only PR #53's runtime/UI subset** through Governor-controlled manual integration; do not copy its v9 sketch into SQL. Review SettingsView overlap with PR #50 independently.
9. Run proposed `scripts/verify-r5-sqlite-contract.py` (structure-only). Then run full native iOS 15 simulator compile, project preflight and full XCTest. Diagnose compiler diagnostics on the exact integration HEAD, not by speculative edits to upstream drops.
10. Restore actual v8 exports/backups in sandboxed app storage; test sequential/duplicate/interrupted v8→v9→v10 upgrade; verify old chats, media, pinned state, contacts, keys, outbox, WAL and SQL FK/integrity.
11. Run encrypted BLE/LAN peer matrix: old original v4, R2, R4 and R5 to R5. Validate genuine signed Hello / real ACK behavior and fragmentation at iPhone 7 MTU.
12. **Only after Governor acceptance and clean evidence** merge protected integration branch to main; version/release and IPA sign/upload require separate Governor/owner release authorization, not this Lane.

## Observed progress / limits

Strict in-memory application validated **all 5 patch stages** against exact Build 59 main with correct old/new hunk counts and matching source context (9 distinct proposed Swift files including tests).

A synthetic SQLite check of the PR #56 DDL passed repeated v9/v10 application, legacy blob preservation, FK integrity and cascade deletion. This **does not prove true v8 snapshot migration, Swift compilation, XCTest or communication interoperability**.

This drop includes an additive Python preflight patch. It reads the actual integrated migration functions from DatabaseStore.swift and exercises their embedded SQL in a synthetic in-memory fixture. It is intentionally not auto-registered into CI because this Lane cannot modify workflows.

## Hard release gates

STOP on any compiler error, failed XCTest, lost legacy row, migration marker inconsistency, FK violation, identity fingerprint mismatch, unsigned feature enablement, R2 bit7 compatibility break, BLE Hello fragmentation failure, old-app data read regression, release SHA mismatch or uncontrolled source deletion.

Do NOT merge either draft Inbox PR directly: their actual contents are proposals rather than the compiled product sources.
