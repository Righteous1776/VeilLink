# Test plan

1. With a ready BLE secure session, create/invite/accept/move/rematch from both Chat and Game Hub; verify exactly one command is queued per tap.
2. Drop BLE security while preserving connection intent. Tap each entry point and verify BLE refresh starts, no game message/history mutation occurs, and a retry succeeds after handshake.
3. Run the same scenario with BLE unavailable and LAN Turbo enabled; verify LAN refresh and subsequent secure-session recovery.
4. Run with remote relay enabled and local transports unavailable; verify relay `refreshNow()` executes and the recovered session can carry the command.
5. With all transports unavailable, verify all three idempotent refresh paths are requested, the alert is accurate, and repeated taps do not create invitations or moves.
6. Simulate near-simultaneous cross-invites after recovery; verify existing collision coalescing still produces one canonical live session.
7. Reorder/duplicate received game events and verify `MiniGameSessionBuilder` remains deterministic.
8. Run full `MiniGameTests`, transport/session tests, XCTest, simulator build and a two-device iPhone 7/iOS-current disconnect/reconnect smoke.
