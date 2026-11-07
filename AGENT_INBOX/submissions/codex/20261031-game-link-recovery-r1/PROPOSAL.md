# Reproduced Build64 bugs

1. `MiniGameHubView` and `MiniGameSessionView` have duplicate recovery helpers, but when no secure session exists `SessionCoordinator.transportID(for:)` is normally nil and they refresh BLE only. LAN Turbo and Internet Relay are not asked to recover.
2. Chat's quick game invitation and accept/decline paths do not call either helper. They call `sendMiniGamePacket` directly, receive “安全链路尚未就绪”, and do not start recovery.
3. The same peer and game therefore behave differently depending on whether the user acts from Chat or the Game Hub.

# Proposed repair

1. Centralise the gate in main-actor `AppModel.ensureRealtimeGameLink(for:)`.
2. Return true only for an already authenticated secure session.
3. Otherwise request the idempotent refresh operations for BLE, LAN Turbo and Internet Relay, record one non-identifying diagnostic action, and return false.
4. Route game creation, move/resign, rematch, quick invitation and quick accept/decline through the same gate.
5. Preserve the current no-optimistic-command rule: no packet or local game-history event is created while the secure session is unavailable. The user retries after the link-ready status appears, which also avoids duplicate invites after delayed recovery.

No peer identity is written into recovery telemetry.
