# VeilLink protocol + SQLite architecture uplift (cumulative proposal)

**Base:** main `8048b5c52b87eeb5d3622582da5728a8c2d64dda`. **Status:** Inbox-only, no live product integration.

## Root limitations observed
- `SessionCoordinator.WireProtocol.version == 4` is mandatory for Hello, encryption and envelope framing.
- Single text payload <= 16 KiB, images/voice specially encoded, no generic typed application event bus.
- `conversations.peer_identity_id` and `outbound_queue.target_identity_id` reflect one-to-one delivery; no real group/multicast durable queue.
- No generic encrypted event inbox for app-level sync/agent/game state replay.

## Stage 1 (PATCH.diff)
Keeps Wire v4 signatures and crypto intact. Optional authenticated ACK feature bits are versioned, backward-decodable, and fingerprint-scoped to a trusted contact in SQLite schema v9. Existing messages, attachment tables, backup envelope and version/build values are unchanged.

## Stage 2 (PATCH_STAGE2.diff) — apply after stage 1
- New `WireKind.controlEvent=10`, but **only emitted to peers with the authenticated capability bit 1** from Stage 1. Legacy v4 peers continue their current handshake/message path and never receive unknown control frames.
- New bounded typed `VeilControlEvent`: v1 schema, canonical UUID event ID, safe topic name and at most 24 KiB payload / 48 KiB encoded frame.
- Per-event authenticated ChaChaPoly using current session directional keys and dedicated AAD context `control-event-v1`; replay window and messageID/eventID binding on receive.
- SQLite v9 `control_event_inbox`: idempotent key `(local identity, peer identity, event ID)`, encrypted event body at rest, 256 retained records per peer, foreign-key cascade. No plaintext application payload stored in metadata.
- Validated controls are stored **before** optional callback dispatch; consumer still must authorize each topic and transition. Reboot consumers can query recent encrypted events through the new read API.
- Send uses existing control priority and returns `unsupportedLink` without matching negotiated bit. Sending is best-effort: no control-specific delivery ACK or durable outbound fan-out in this stage.

## Strict boundaries
Do not label this a completed group chat, offline task sync, broadcast, v5 protocol or unlimited large-file pipeline. Those need explicit role/membership authority, per-recipient receipts, durable outbox, conflict resolution, encryption model and device stress testing. No automatic privilege escalation, trusted peer creation or bypass of BLE-first trust.

## Next phases
1. Real v5 negotiation over v4 authenticated Hello-compatible extension; dual-stack with old device fallback.
2. Per-recipient durable control outbox and ACK state machine; idempotence beyond bounded inbox retention.
3. Group membership semantics, sender authorization, group ratchet or per-recipient encryption contract, join/leave/revocation.
4. Transfer manifests, 64-bit ranges and chunk recovery aligned to BLE/LAN constrained MTUs; never simply raise packet size.
5. Backup migration/recovery, observability and adversarial replay/fuzz tests.

## Integration procedure
On current main, verify `git apply --check PATCH.diff`; apply stage 1; verify and apply `PATCH_STAGE2.diff`; run full iOS build/XCTest on macOS, old/new v4 device mixed matrix, actual BLE and LAN, snapshot/restore, protected surface review. PR #53 negotiation plan must be arbitrated by Governor. No version change or IPA publish without separate owner-authorized release gate.
