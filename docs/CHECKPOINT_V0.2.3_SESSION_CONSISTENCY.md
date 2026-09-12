# VeilLink V0.2.3 Session Consistency

This checkpoint starts from GitHub `main` commit `db24024c89d309001072d9f0153ba3a2ced696cb`, the source revision that passed the real iOS Simulator build, unit tests, and the first unsigned `iphoneos` IPA workflow. Protocol 4 and Schema V6 remain unchanged.

## Changes

- CoreBluetooth readiness events are deduplicated per transport ID. A Central-side link is not declared usable until characteristic discovery and notification subscription both succeed, preventing a Hello from racing ahead of the return channel. A real disconnect allows a later reconnect event again.
- `SessionCoordinator` independently rejects duplicate `connected` callbacks and gives unauthenticated handshakes a 15-second lifetime. Successful authentication, disconnect, identity switch, rejection, invalid-packet disconnect, or peer invalidation cancels the deadline.
- Expired handshakes release their session, peer mapping, abuse-limiter state, and BLE link instead of remaining indefinitely in pre-authentication memory.
- Message row insertion and conversation preview/update now commit in one SQLite transaction rather than two independent writes.
- If encrypted attachment bytes are written to disk but the attachment database row cannot be committed, the newly written file is removed immediately so failed inserts do not leave orphan encrypted files.
- Connection event gate and database consistency regression tests were added.

## Compatibility

- Wire protocol: 4 (unchanged)
- SQLite schema: V6 (unchanged)
- Bundle version: 0.2.3 build 4
