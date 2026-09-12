# V0.3.6 Runtime Optimization

VeilLink 0.3.6-dev build 12 is a performance-focused checkpoint built on V0.3.5.

- Protocol 4 unchanged.
- SQLite Schema V8 unchanged.
- BLE reassembly uses a typed `(source, frameID)` key, O(1) per-source partial counts, and stale pruning no more than once per short interval rather than on every packet.
- Incoming/outgoing attachment UI refresh signals now follow persisted progress quantization instead of every checkpoint/chunk.
- Message-only refreshes no longer force conversation-list requery/decryption.
- Accepted Outbox retry scheduling is one SQLite UPDATE instead of SELECT + UPDATE.
- Repeated `.sending`/`.queued` delivery writes are skipped when the visible state is already correct.
- V8 startup ensures indexes on `(local_identity_id, peer_identity_id, updated_at)` and `attachments(message_id)` without a schema-version bump.
- Local CI simulation and new regression tests cover direct packet round-trip, encoded-size accounting, retry-count behavior, and progress-notification quantization.

## Local performance self-audit

A Linux Swift `-O` synthetic benchmark (400 complete 4 KiB messages fragmented at a 31-byte packet size) measured the previous assembler around 0.46–0.49 s and the optimized assembler around 0.38 s in repeated runs. This is only a directional host benchmark, not an iPhone performance claim.

A separate attempt to bypass `BLEFragment` objects and directly emit encoded `Data` packets was rejected and reverted after the same host benchmark showed it roughly 25–34% slower in repeated runs. V0.3.6 therefore keeps the established sender fragmentation path and only ships the reassembly optimizations that demonstrated a positive result.
