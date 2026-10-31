# Reproduced Build64 bug

The released Build64 product still declares:

- `let humanPlayer: MiniGamePlayer = .host`
- `let aiPlayer: MiniGamePlayer = .guest`
- Gomoku lobby text `你执黑先手`
- Xiangqi lobby text `你执红先手`

The search and legality gates also pass `.guest` directly. Therefore the previously requested colour/first-player control is absent, and merely adding a Picker would make the displayed side disagree with the engine.

# Proposed repair

1. Make `humanPlayer` published and mutable only through a board-game setter; derive `aiPlayer` as its opponent.
2. Expose labels: Gomoku host=`黑 · 先手`, guest=`白 · 后手`; Xiangqi host=`红 · 先手`, guest=`黑 · 后手`.
3. A side change restarts the board and schedules the computer immediately when the player selected guest/second.
4. Replace board-engine `.guest` constants with a main-actor snapshot of `aiPlayer`, including external JS engine, native Gomoku, Xiangqi, and rule-gate replay.
5. Store learning roles semantically: `.host` always means local human evidence and `.guest` always means computer evidence, regardless of physical colour. This avoids reinterpreting old learning data and requires no migration.
6. Keep Ludo, tactical and arcade side behaviour unchanged.

The UI control belongs in the status card rather than Settings, so selection is visible at the point of play and does not add global settings clutter.
