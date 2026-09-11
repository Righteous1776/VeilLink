# VeilLink V0.2.2 Runtime Stability

This checkpoint keeps Protocol 4 and Schema V6 unchanged. It focuses on long-running stability and recovery rather than new product features.

## Changes

- BLE reassembly is bounded to the real 96 KB Protocol 4 envelope budget instead of megabyte-class buffers.
- A single BLE source may hold at most eight incomplete frames, while global reassembly is capped to 32 frames / 768 KB.
- BLE assembler buffered-byte accounting is O(1) and evictions correctly release accounting state.
- Repeated invalid packets are rate-windowed per transport. Valid traffic resets the penalty; eight invalid packets within ten seconds disconnect only that link.
- Invalid unauthenticated nearby traffic no longer repeatedly overwrites user-facing errors.
- Completed inbound attachment temporary rows are removed after final storage. Duplicate manifests use the verified final attachment as the completion fact and do not restart from zero.
- Startup repairs legacy completed transfer rows and inconsistent temporary completion markers.
- Inbound/outbound transfer checkpoints remain exact for every chunk, while UI progress persistence is quantized to reduce redundant SQLite writes.
- Expired outbox and inbound-transfer cleanup use atomic batched transactions.
- SQLite WAL autocheckpoint is set to 512 pages with a 4 MiB journal size limit.
- App/build display version is synchronized to 0.2.2-dev / bundle 0.2.2 build 3.

## Compatibility

- Wire protocol: 4 (unchanged)
- Database schema: 6 (unchanged)
- No migration is required from the previous V0.2.1 checkpoint.
