# VeilLink R5 — secure signed-Hello capability bootstrap without synthetic chat traffic

## Background: actual current main

The product on main still requires a Wire v4 Hello and stores ordinary one-to-one messages using SQLite schema v8. The staged R1..R4 Inbox proposal in this directory upgrades the app through v9 and v10 control-event queues and receipts, but **the R4 control lane required a normal chat ACK to discover capability bits**. This makes agent events/group preparation artificially dependent on human chat traffic.

## Cumulative patch order

1. `PATCH.diff` — v4 chat ACK capability extension + trusted-peer, identity-key-bound SQLite v9 cache.
2. `PATCH_STAGE2.diff` — authenticated and schema-limited control-event kind 10, encrypted bounded inbound inbox.
3. `PATCH_STAGE3.diff` — SQLite v10 durable, normalized per-recipient control outbox, event ciphertext encrypted once, independently acknowledged/queued target state.
4. `PATCH_STAGE4.diff` — optional wire kind 11 E2EE receipts, per-target ACK/GC and reconnect/retry integration; fresh-session bit2 gate, duplicate ACK recovery, 512-quota transactional admission.
5. **`PATCH_STAGE5.diff` — signed, optional Hello v4 capability bootstrap**, plus legacy ACK downgrade handling and focused XCTest cases.

## The R5 handshake

- Retain `HelloPacket.protocolVersion = 4`, all mandatory fields, its original signed `VeilLink/Hello/v4` payload, and the existing v4 Curve25519 session transcript/HKDF. No wire version jump or secret/key rotation.
- Add optional `capabilitySchema`, `capabilityBits`, `capabilitySignature` to the Codable Hello JSON. Old Swift Codable peers ignore unknown keys. No additional packet kinds are sent during bootstrap.
- Create a **second identity Ed25519 signature** over `VeilLink/HelloCapabilities/v1|` plus original signed v4 payload, original v4 signature, and deterministic schema/bit values. This cryptographically binds the extension to ephemeral agreement key, nonce and identity, avoiding unauthenticated Hello metadata.
- Validate the legacy v4 Hello signature first. If extension signature is absent, invalid, unknown-schema or has unsupported feature bits, accept the valid **legacy secure handshake**, but advertise **no enhanced features** on the basis of that extension.
- Fresh verified signed Hello feature bits are assigned to the *current session context*; control send still requires a trusted matching contact key. The persistent peer capability cache is advisory only and must not authorize transport.
- For a legacy R4 peer without Hello extension, permit genuine encrypted chat ACK capabilities later as fallback. ACK must not overwrite a valid current-session signed Hello advertisement.

## Important R2 peer backward compatibility fix

R2 decoders reject unknown feature bits rather than masking them. Therefore, before proof that the remote client supports bit2, R5 advertises just bits `3` in its optional chat ACK. If a verified current-session peer declares bit2, R5 may advertise bits `7`. This prevents an R2 peer from rejecting all optional ACK capabilities after the R5 upgrade.

## Real behavior and boundaries

- R5↔R5 peers have the necessary capability negotiation input **during signed Hello** and can drain already-queued reliable control events immediately after explicit trust is established, without any invisible chat message.
- R5↔R4 peers fall back to authenticated, genuine chat ACK capability proof for the new reliable control lane; if neither user sends chat, queued work stays pending rather than bypassing compatibility.
- R5↔legacy v4 peers maintain original secure Hello/chat paths, without new kind 10/11 frames.
- This still does **not** provide full group membership/group keys, permanent exactly-once application actions or large-media chunk streaming. Future R6 phases should implement group membership trust/authorization and chunked sync manifests **after** device regression passes.
- TrollStore/ordinary installation channels may use the same protocol; TrollStore marker never affects cryptographic identity or control authorization.

## Integration

Governor alone reviews protected signing/transport/schema surfaces and overlap with PR #53. Apply in ordered standalone integration branch, run iOS/XCTest and old-new iPhone 7 and newer iPhone BLE/LAN matrix; no self-merge or IPA publication by this lane.
