# VeilLink Protocol and Database Foundation — R3

**Base**: `8048b5c52b87eeb5d3622582da5728a8c2d64dda`; proposed-only, source not changed in main.

## Why it must be architectural
The current application requires Wire v4, uses three main chat payload categories (text/image/voice), imposes a 16 KiB text message bound and has a one-to-one conversation/outbound queue design. Merely raising version numbers or limits cannot deliver groups, multi-peer sync, agent events or resilient large-object transfer.

## Apply cumulative patches in order
1. `PATCH.diff`: authenticated optional capability bits in v4 ACK (safe old-peer fallback) + additive SQLite schema v9 peer capability cache.
2. `PATCH_STAGE2.diff`: optional encrypted `controlEvent` kind 10 with a typed, bounded codec, separate AAD/replay, encrypted inbound `control_event_inbox` and safe callback. Capability bit 1 is mandatory before sending new kind.
3. **`PATCH_STAGE3.diff`: schema v10 normalized durable control-event outbox.** `control_outbound_events` holds one encrypted event payload per local identity/event ID; `control_outbound_targets` keeps each recipient's retry/attempt schedule and acknowledgement state. All new rows are under transactions and trusted-recipient requirements. Acknowledging one peer cannot remove other peers' pending delivery. The last acknowledged recipient garbage-collects the event. A conflicting reuse of the same event ID with different content is rejected; identical re-enqueue is idempotent.
4. The v10 migration creates two tables and two indexes plus the migration marker atomically. Does not rewrite messages, ordinary outbound_queue, attachments, conversations, contacts or storage key. V8 backups remain eligible for existing restore and migration sequence, subject to native regression verification.

## Hard constraints
**Phase 3 is a data-plane foundation only, NOT an active E2E delivery protocol.** `SessionCoordinator` currently does not drain the new queue or emit/consume authenticated per-event ACK. Do not report control reliability as fully implemented. A later dedicated stage must wire accepted transport sends to `recordDurableControlSendAttempt`, authenticated receipt to `acknowledgeDurableControlEvent`, reconnect resend, expiry, and proper receipt-of-duplicate behavior. Existing Wire v4/crypto/handshake remains untouched.

## Future TrollStore readiness
Coordinate separately with PR #53 (installation evidence/UI) and PR #57 (conservative optional readiness gates). Optional runtime enhancements must not influence E2EE identity, per-peer trust, wire capability proofs, schema migration or backup. Common app binary must remain installable on ordinary iOS 15 devices.

## Integrate only after
Governor freezes and rechecks current main, resolves PR #53 overlap, verifies exact stage-by-stage `git apply`, builds/XCTests on macOS, runs old/new device matrix, validates backup/restore and only then promotes a controlled integration branch.
