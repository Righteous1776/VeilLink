# RISKS and overlap

- CRITICAL: protocol, session and SQLite schema are protected; do not integrate solely because Agent Inbox Gate passes.
- New kind 10 is not backward-readable; it is strictly gated by the authenticated feature bit, not by app version guesses. ACK must have been received from trusted identity/key in stage 1. Cross-version handshake remains v4.
- Control payload is per-peer authenticated, **not** a group end-to-end encryption design; topics must be independently authorization-checked by consumers.
- Current send is best effort, no per-recipient durable outbox/receipt; not suitable for irreversible state transitions.
- Bounded 256-event cache does **not** establish permanent exactly-once delivery. Evicted IDs may be seen again across reconnection; consumer must be idempotent.
- Encryption-at-rest uses current database storage key, so backup/keychain restore test is mandatory.
- Cache pruning after insert occurs in a separate SQLite write; interrupted pruning can temporarily exceed bound until next successful insert. Governor may require a single transaction.
- Untested concurrency and BLE fragmentation performance, and lack of iOS Xcode build, prohibit declaring production readiness.
- Overlap with PR #53 v4 capability + DB v9 plan and PR #50 storage UI. Governor decides integration order and may revise proposal.
- Stage 2 depends exactly on Stage 1. Never apply Stage 2 alone or independently increment schema marker.
