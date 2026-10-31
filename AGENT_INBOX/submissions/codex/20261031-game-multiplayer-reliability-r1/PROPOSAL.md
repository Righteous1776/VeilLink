# Proposal — repair multiplayer game session visibility and channel truth

## Outcome

Apply `PATCH.diff` on an isolated Governor integration branch at the exact recorded baseline. This is a compatibility-preserving VLGM1 state/UI repair; it does not add fields, alter message encoding or migrate storage.

## Reproduced defects and corrections

### Quick rematch disappears

`coalescedLiveSessions` first selected live candidates, but then compared each candidate against **all** historical sessions. A terminal session created within eight seconds of a new invitation was treated as the progressed canonical collision winner. The new invite was consequently removed from the game hub and from the persistent chat card.

The candidate forms collision groups only from non-expired invited/active sessions. Finished, declined, cancelled and expired history remains visible in history, but can no longer suppress a new live session.

### Working LAN/relay game shown as disconnected

The game status component required both `GATT_READY` and a secure session. That condition is BLE-specific, while game packets may use an already authenticated LAN or relay-backed session. The send path accepted the packet but the UI said “等待发现对手设备”.

The candidate uses `SessionCoordinator.hasSecureSession` as channel readiness truth. BLE telemetry remains supplementary detail when available; a non-BLE secure session gets an explicit ACK/retry-capable status.

### Invalid local command enters durable queue

Receive decoding already rejects invalid UUIDs, negative turns and command/move shape mismatches. The outbound coordinator encoded and saved packets without invoking that same validator, so an internal caller could persist a command the peer necessarily drops.

The candidate exposes the existing validator inside the module and rejects invalid packets before `queueContent`. Valid VLGM1 bytes are unchanged.

## Integration boundary

- No edit overlaps PR #97's BLE watchdog/backoff source files.
- No wire version, packet field, database schema or identity behavior changes.
- No release, IPA, signing or workflow dispatch is authorized by this submission.
