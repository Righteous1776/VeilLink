# Proposal — P0 repair for game link recovery

## Verified defect

The prior candidate's `ensureRealtimeGameLink` only called BLE/LAN/relay refresh methods when no secure session existed. `BLETransport.refreshLinks()` scans, advertises, refreshes queues and RSSI, but it does not emit `onConnected` for an already-connected peripheral. Therefore it cannot by itself call `SessionCoordinator.connected` and restart the authenticated Hello exchange.

The old game-only helper at least attempted `recoverSecureSession`; replacing it without preserving that action regresses the important physical-link-alive / secure-session-lost case. There is a second edge case in the current recovery implementation: it calls `refreshPreferredTransport` first, which deliberately removes the preferred binding when the session is not secure. The recovery target is then lost before re-handshaking begins.

## Proposed correction

1. Select a recovery transport before changing bindings, considering the prior secure route, remembered peer transports, a live session with the same remote identity, and the displayed nearby-peer transport.
2. Clear only the stale session context, issue a fresh Hello on that exact transport, and schedule the existing bounded handshake watchdog.
3. Make the operation return whether a directed re-handshake began. Existing callers may ignore the return value.
4. Keep the existing game UI's refusal to persist a game packet while `hasSecureSession` remains false.

This keeps the existing packet format and trust checks unchanged. It does not make a disconnected or untrusted peer sendable. A broader unified recovery entry point remains a follow-up only after #130 is reworked.
