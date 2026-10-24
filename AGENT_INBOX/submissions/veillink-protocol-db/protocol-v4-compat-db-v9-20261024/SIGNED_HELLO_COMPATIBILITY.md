# R5 peer compatibility acceptance matrix

| Local | Remote | Signed Hello extension | R5 negotiation | Expected control path |
| --- | --- | --- | --- | --- |
| R5 | R5 | both signed and verified, bit7 | immediate at established secure session | control kinds 10/11 only with pinned trusted identity |
| R5 | R4 | R4 none | R5 waits for genuine encrypted ACK (R4 bits7) | durable outbox remains pending before ACK |
| R5 | R2 | R2 none | R5 receives genuine ACK bits3 | kind10 best-effort only; ACK fallback advertises bits3 |
| R5 | original v4 | original none | no recognized enhancements | original chat, media and ACK only |
| original v4 | R5 | original decoder ignores optional fields | v4 signature stays unchanged | original chat/media path |

## Explicit domain separation

- Legacy mandatory signature: Ed25519(identity key) over `VeilLink/Hello/v4|...` (unchanged).
- Optional feature signature: Ed25519(same identity key) over `VeilLink/HelloCapabilities/v1|` + the legacy v4 signed payload + `|v4sig|` + the original 64-byte legacy signature + `|schema|bits|`. Binds features to identity, device ephemeral and session nonce without introducing an unauthenticated control frame.
- New feature bits are stored in RAM for the current session. Cache remains advisory, not a transport feature grant.

## Failure modes and tests

Unknown extension schema, invalid feature signature, tampered nonce or ephemeral, and stripped feature metadata cannot grant enhanced transport capability. Existing v4 identity signature is still mandatory. Old clients still ignore unknown JSON fields, but real-device validation and maximum BLE Hello-fragment bounds remain release blockers.
