# OMEGA 96 V0.2 — Known Limits

- Status is **SHADOW_ACCELERATED**; production cutover is denied.
- The fastest Fused Token Tree measurement begins at an attested 32-byte Aggregate Frame; Host Adapter raw-source normalization is outside that timed boundary.
- The Native hot lane is currently specialized for the DBHealth A9-compatible profile. VeilLink 288-state and SQLiteVault 576-state profiles still require universal Native compilation.
- The current extension targets CPython 3.13 x86_64 Linux and uses `-march=native`; portable/generic dispatch binaries are not yet supplied.
- OpenSSL low-level `SHA256_Init/Update/Final` APIs are deprecated and must be migrated without changing protocol hashes.
- pthread workers are created/joined per large batch; a persistent topology-aware physical worker pool is not yet implemented.
- VAULT state is not yet restart-safe durable storage.
- Only DBHealth has the strongest independent semantic Oracle coverage; the four implementation-diverse Oracle roles are not complete.
- 96 logical tiles are not 96 physical CPU cores; throughput is bounded by the host.
- All Canonical/target/transport/storage/game/Agent mutation authorities remain zero.
