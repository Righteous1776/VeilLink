# V0.4.0 Encrypted Mini Games

Base: GitHub main `126fd9cfaacca70af41493eb3739ca05cd143d3b` (V0.3.13).

## Added

- Conversation Game Hub reachable from the attachment `+` menu.
- Gomoku: 15×15 board, deterministic turn reconstruction, five-in-a-row victory detection.
- Chinese chess: standard initial board, red/black roles, piece movement rules, palace/river restrictions, horse-leg and elephant-eye blocking, cannon screens, flying-general behavior, and self-check rejection.
- Two-player Ludo: four pieces per side, deterministic local dice, launch-on-six, capture, finishing lane and extra turn on six/capture.
- Invite / accept / decline / resign lifecycle.
- Game operations persist through the existing encrypted chat message store and are reconstructed after app restart or BLE reconnect.
- Game traffic is hidden from ordinary message bubbles while conversation previews remain human-readable.

## Compatibility

Protocol 4 is unchanged. SQLite Schema V8 is unchanged. Game traffic uses a reserved `VLGM1` structured-text envelope carried inside the existing encrypted-message path, so no new BLE wire kind or database table is introduced. Older clients remain transport-compatible but may display the reserved game payload as text if paired with a V0.4.0 client.

## Validation

- Linux-compatible rules/codec smoke tests pass.
- `scripts/local-ci-sim.sh` parses every Swift source and exercises the game codec/rules in its core harness.
- Full Simulator XCTest and `iphoneos` unsigned IPA compilation remain the GitHub/macOS CI gate.
