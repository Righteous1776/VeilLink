# V0.4.1 Game Experience Overhaul

Base: local V0.4.0 Encrypted Mini Games checkpoint; upstream GitHub base `126fd9cfaacca70af41493eb3739ca05cd143d3b`.

## Reliability and rules

- Game history replay is turn-driven and deterministic, deduplicates `actionID`, ignores gameplay sent before acceptance, and resolves same-turn conflicts consistently.
- Pending invitations can be withdrawn without creating a fake finished match.
- Gomoku exposes a winning line and correctly terminates as a draw on a full board.
- Chinese chess surfaces check state and treats a side with no legal move as defeated, while preserving palace, river, horse-leg, elephant-eye, cannon-screen, flying-general and self-check validation.
- Ludo tracks capture count, extra-turn state and finished-piece counts for clearer UI state.

## Experience

- Chat transcripts render one live encrypted game card at the invitation position; move payloads remain hidden.
- Tapping a chat game card deep-links into that exact encrypted session.
- Gomoku uses a true 15×15 intersection board with star points, last-move marker and winning-line highlight.
- Xiangqi uses an intersection board with river, palaces, local-player rotation, legal destinations, last-move trace and check banner.
- Two-player Ludo uses a visual 52-position flight track with home/track/final-lane piece placement.
- Rules sheets, rematch, invite withdrawal, turn/receive/result haptics and duplicate-tap suppression are included.
- Motion respects Reduce Motion and the existing low-complexity device profile.

## Performance

- Game Hub and session history reconstruction load off the main thread.
- Chat history automatically expands only when hidden game events are present without their invitation record, preserving a live card without permanently increasing the ordinary message window.

## Compatibility

Protocol 4 is unchanged. SQLite Schema V8 is unchanged. The reserved `VLGM1` structured-text envelope remains the carrier, so no new BLE wire kind, database table, or parallel game transport is introduced.

## Validation

- Linux-compatible core typecheck and executable game harness pass.
- Every Swift source parses successfully.
- iOS 15 / SE1 / iPhone 7 compatibility guards remain green.
- Full Simulator XCTest and unsigned `iphoneos` compilation remain the macOS/GitHub CI gate before merging upstream.
