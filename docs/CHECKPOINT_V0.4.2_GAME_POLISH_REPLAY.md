# V0.4.2 Game Polish & Replay

Upstream reference: GitHub main `126fd9cfaacca70af41493eb3739ca05cd143d3b` via the local V0.4.1 checkpoint.

## Scope

- Adds deterministic replay frames reconstructed from the same encrypted mini-game events used to rebuild live state.
- Adds per-conversation completed-match statistics: wins, losses, draws, win rate, per-game breakdown data and current win streak.
- Records invite/start timestamps in rebuilt session snapshots and exposes finished-match duration without changing SQLite.
- Prevents accidental duplicate live sessions of the same game from the Game Hub by routing the user back into the existing session.
- Improves Ludo pacing: the local turn now requires an explicit roll/reveal interaction before legal planes become actionable; impossible rolls surface an explicit end-turn action.
- Adds finished-game replay UI with scrub/previous/next controls and read-only board rendering for all three games.
- Keeps iOS 15 and legacy-device motion budgets intact.

## Compatibility

- Protocol: 4 (unchanged)
- SQLite schema: V8 (unchanged)
- Mini-game payload: VLGM1 / packet version 1 (unchanged)
- Deployment target: iOS 15.0 (unchanged)

## Remaining macOS/real-device gates

XcodeGen generation, Simulator build, XCTest execution, unsigned `iphoneos` Release build, and dual-device BLE gameplay remain Work/macOS gates.
