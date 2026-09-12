# V0.3.1 Local Controls

- Protocol remains 4. No new wire message type is introduced.
- Schema advances to V7 with `outbound_queue.is_paused` so an outgoing image can remain paused across app relaunches.
- Pause preserves the receiver-confirmed attachment checkpoint. Resume continues from that checkpoint instead of restarting the image.
- Cancel stops future local sends but does not claim to revoke chunks already confirmed by the peer.
- Late authenticated checkpoints after a local cancel/delete are ignored safely instead of being treated as malformed traffic.
- Individual messages can be deleted locally; conversation preview is repaired to the newest remaining message.
- Clearing a conversation removes local messages/attachments while retaining the contact and trust relationship. Attachment files are deleted with their database rows.
- Received images can be automatically saved after final byte-count/SHA-256 validation when the user enables the setting. The default remains off.
- Device-local deletion keeps an 8-day sender-scoped message tombstone so an ACK-lost retransmission cannot silently recreate a deleted incoming message during the sender's seven-day retry window.
- Incomplete inbound image messages are protected from local delete / conversation clear until transfer completes, avoiding a half-deleted checkpoint state without introducing a new wire-level reject message.
