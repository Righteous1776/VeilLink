# VeilLink Protocol and Database R4 — cumulative engineering proposal

## Objective and actual repository state

Main currently uses strict Wire v4 Hello/envelope, one-to-one chat models and schema v8. This four-stage proposal is **Inbox-only** and does not change the running product. It develops a typed encrypted control lane and genuinely independent per-recipient **transport-persisted receipts**, without altering existing chat protocols.

### Apply in strict order

1. `PATCH.diff`: authenticated JSON ACK optional feature metadata, legacy v4 decoder compatibility and fingerprint/identity scoped SQLite peer capability cache (schema v9).
2. `PATCH_STAGE2.diff`: Wire kind 10, event v1 codec with 24 KiB bounded payload, dedicated authenticated ChaChaPoly context, replay window, encrypted inbound cache; server-only changes to protected surfaces.
3. `PATCH_STAGE3.diff`: normalized encrypted v10 `control_outbound_events` + `control_outbound_targets` journal, each event encrypted **once** at rest with independent targets, 7-day expiration, retry policy, pending API, per-trusted-peer receipt API, no original message/outbox rewrite.
4. `PATCH_STAGE4.diff`: **actual connection to SessionCoordinator**. One API `enqueueReliableControlEvent(_:recipientIdentityIDs:)`; authentication/feature-gated outbound drain, accepted-transport attempt bookkeeping, incoming encrypted kind 11 ACK, authenticated event UUID binding, duplicate-event ACK retry, reconnect/periodic retry polling. The new `receiptRequested` optional encrypted event field provides receiver-side compatibility with earlier control-event clients. Received `controlReceipt` frames can remove **only the authenticated sender peer's** unacknowledged target, never another target.
   - Feature bit2 (numeric 4) is required for outbound durable attempts and is negotiated **fresh per secured session**, not from 30-day cached metadata. Unknown/older clients never receive controlReceipt kind 11.
   - v10 target rows retain `acknowledged_at` while other recipients are pending. Re-enqueuing the same event does not resurrect already-acknowledged target rows; the final ACK garbage-collects the shared event.
   - 512-event capacity checks are enforced within the same SQLite write transaction as the event+target inserts, with FK rollback on overflow.
   - Explicit local identity deletion also removes its encrypted control outbound event rows.
   - BLE control frames are limited to <= 2 KiB encoded event size. Larger feature data must use a future chunked path or a validated alternate transport.

## Compatibility constraints

- No changes to signed Hello v4, v4 HKDF, chat ciphertext, chat ACK semantics, contact trust or Keychain key.
- **Current limitation:** optional capability feature bits arrive with authenticated CHAT acknowledgements. Fresh session-level negotiation is not possible before an outgoing chat ACK; R4 intentionally keeps durable control work pending until then, instead of sending unsolicited or unrecognized control packets to legacy v4 peers. A future dedicated compatibility-safe capability bootstrap is required.
- Receipt acknowledges **encrypted event persistence**, not completed business execution. Feature consumers must authorize topic/actions separately; the bounded inbound cache does NOT confer permanent exactly-once application semantics.
- A trusted remote identity may not send to untrusted recipients, alter another identity's outbox, or use TrollStore installation metadata as a transport/identity authority.

## Future work / handoff

R5: safe v4 capability bootstrap (without false ACK), app-level group membership and authorizations, idempotent state-machine handling with longer-lived dedup tombstones, chunked large-object manifests and per-channel BLE/LAN/relay backpressure tuning.

PR #53 remains the owner of TrollStore marker/UI detection; PR #57 handles conservative runtime readiness. No entitlements, private APIs, release workflows or app build values are changed here.
