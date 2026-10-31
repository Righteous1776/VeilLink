# Proposal — choose board colour and turn order without corrupting learning

`LocalAIGameController` currently hard-codes human=`host` and computer=`guest`; the UI therefore always forces Gomoku black / Xiangqi red. The candidate turns the board side into a session-only choice, resets the current game on change and starts the computer immediately when it owns the first colour.

The key compatibility detail is learning: the existing store's actor labels mean “local player” and “computer”, although their enum names are host/guest. A direct colour swap would reverse learned preferences. The candidate maps physical actors back into the existing local-player/computer roles before storing plies. No schema, database, existing history or exported training package changes.

The feature targets stacked PR #114 because that is where current native-training / formation code resides. It overlaps `LocalAIGameController.swift`, `GameLobbyView.swift` and the local-game tests with #112–#114; Governor must apply it only after stack arbitration.
