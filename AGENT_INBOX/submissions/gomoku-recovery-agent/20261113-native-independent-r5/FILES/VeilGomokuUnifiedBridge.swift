import Foundation

/// Bridge into the existing VeilLink board and learning contracts.
/// The caller MUST first run GomokuBot's own win / forced block / R8 / R4
/// tactical gates and pass only the resulting root candidate set here.
enum VeilGomokuUnifiedBridge {
    static func chooseMove(
        in state: GomokuState,
        for player: MiniGamePlayer,
        budget: GomokuBotBudget,
        permittedRoots: [Int],
        learning: AdaptiveBoardLearningSnapshot,
        formation: GomokuFormationPreference,
        onTrace: (@Sendable (VeilGomokuUnifiedSearch.Trace) -> Void)? = nil
    ) -> GomokuBotMove? {
        guard state.winner == nil,
              !state.isDraw,
              state.currentPlayer == player,
              !permittedRoots.isEmpty else { return nil }
        let started = Date.timeIntervalSinceReferenceDate
        let cells = (0..<(GomokuState.size * GomokuState.size)).map { index -> UInt8 in
            UInt8(max(0, state.value(at: index)))
        }
        guard let position = VeilGomokuUnifiedSearch.Position(
            cells: cells, toMove: player == .host ? 1 : 2
        ) else { return nil }

        // The new kernel receives only native scale root preferences. It never
        // reads, modifies, or replaces saved training database files.
        let trainingPosition = AdaptiveBoardPosition.gomoku(state)
        let opponentEmergency = GomokuFormationPreference.opponentHasImmediateWin(
            in: state, player: player
        )
        var bonuses: [Int: Int] = [:]
        for index in permittedRoots {
            let action = String(index)
            let learned = learning.bonus(position: trainingPosition, action: action)
                + learning.rootAdjustment(action: action)
            let formationBonus = formation.bonus(
                index: index, state: state, player: player,
                urgentDefense: opponentEmergency
            )
            bonuses[index] = max(-2_000, min(2_000, learned + formationBonus))
        }

        var limits = VeilGomokuUnifiedSearch.Limits()
        limits.maxMilliseconds = max(30, budget.timeLimitMilliseconds)
        limits.maxNodes = max(2_000, min(180_000, budget.timeLimitMilliseconds * 125))
        limits.maxDepth = budget.continuationCandidateLimit > 0 ? 6 : 3
        limits.width = max(4, min(24, budget.rootCandidateLimit))
        limits.candidateRadius = budget.candidateRadius
        limits.forcedLineDepth = budget.continuationCandidateLimit > 0 ? 6 : 3

        guard let decision = VeilGomokuUnifiedSearch.decide(
            position, limits: limits,
            allowedRoot: permittedRoots, rootBonuses: bonuses, trace: onTrace
        ) else { return nil }
        var legal = state
        guard legal.apply(index: decision.index, actor: player) else { return nil }
        return GomokuBotMove(
            index: decision.index,
            score: decision.score,
            nodes: decision.nodes,
            elapsedMilliseconds: max(0, Int(
                (Date.timeIntervalSinceReferenceDate - started) * 1000
            ))
        )
    }
}
