# V0.4.3 Fair Play & Resilience

Base: local V0.4.2 checkpoint; upstream GitHub base remains `126fd9cfaacca70af41493eb3739ca05cd143d3b`.

- Xiangqi now records deterministic position signatures and ends casual matches as a draw after the same position with the same side to move appears three times. This prevents endless loops without pretending to implement every tournament-specific perpetual-check adjudication rule.
- Consecutive checks are tracked and surfaced as a warning/status detail; move legality remains governed by the existing check/self-check rules.
- Replay gains automatic playback while retaining step/slider controls.
- Incoming game invitations receive a dedicated attention section and stronger visual treatment.
- Added deterministic duplicate/reorder reconstruction coverage so repeated or late gameplay packets rebuild to the same accepted game state.
- Protocol 4, VLGM1 v1, and SQLite Schema V8 remain unchanged. No parallel game database is introduced.
