# VeilLink V0.2 Stability Hardening Checkpoint

This checkpoint focuses on correctness, bounded resource use, and performance without changing Protocol 4 or Schema V6.

- Settings and Owner diagnostics now report Protocol 4 consistently.
- Owner local authorization verifies the primary identity password, even when a secondary identity is active. Identity loading/import normalizes the local primary-identity invariant.
- Incomplete inbound attachment state is cleaned after the same 7-day horizon used by the reliable outbound queue. Cleanup lookup is backed by an idempotent `(completed, updated_at)` index. Cleanup resets the checkpoint so a still-pending sender can restart from chunk zero.
- Inbound attachment admission is bounded globally (16) and per sender (4), preventing one trusted peer from occupying every resumable-transfer slot.
- Active outbound images use a bounded 12 MiB LRU-style plaintext cache so a 3 MiB encrypted attachment is not read and decrypted again for every 48 KiB chunk. Cache entries are removed on success, failure, or identity reset.
- Protocol 4, its cryptographic domain separation, the wire format, and Schema V6 are unchanged.
