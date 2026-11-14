import Foundation

/// The native search is subordinate to GomokuBot's mandatory tactical rules.
/// Pass exactly the R4-vetted root candidates and the incumbent root scores.
/// This bridge never touches the old JavaScriptCore engine or user archives.
enum VeilGomokuUnifiedBridge {
    static func chooseMove(
        in state: GomokuState,
        for player: MiniGamePlayer,
        budget: GomokuBotBudget,
        permittedRoots: [Int],
        rootScores: [Int: Int],
        difficultyRawValue: String? = nil,
        onTrace: (@Sendable (VeilGomokuUnifiedSearch.Trace) -> Void)? = nil,
        onExploredLine: (@Sendable ([Int], Int) -> Void)? = nil
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

        // Original ranking incorporates R3/R6 threat models, sequence learning
        // and formation guidance. All become bounded tie-breaker preferences,
        // never permissions to ignore a proven tactical loss.
        // GomokuBot priorities span multiple tactical/learning scales.
        // Preserve their exact ordering, then normalize to a bounded preference
        // so the new search cannot drown out a verified win or forced block.
        let ranked = rootScores.sorted {
            $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
        }
        var bonuses: [Int: Int] = [:]
        for (rank, entry) in ranked.enumerated() {
            let offset = rank * 4_000 / max(1, ranked.count - 1)
            bonuses[entry.key] = 2_000 - offset
        }
        var limits = VeilGomokuUnifiedSearch.Limits()
        limits.maxMilliseconds = max(30, budget.timeLimitMilliseconds)
        limits.maxNodes = max(2_000, min(180_000, budget.timeLimitMilliseconds * 125))
        limits.maxDepth = budget.continuationCandidateLimit > 0 ? 6 : 3
        limits.width = max(4, min(24, budget.rootCandidateLimit))
        limits.candidateRadius = budget.candidateRadius
        limits.forcedLineDepth = budget.continuationCandidateLimit > 0 ? 6 : 3

        if let difficultyRawValue {
            limits = EclipseDifficultyPolicy.limits(
                rawValue: difficultyRawValue,
                maximumMilliseconds: budget.timeLimitMilliseconds
            )
            limits.candidateRadius = budget.candidateRadius
        }

        guard let decision = VeilGomokuUnifiedSearch.decide(
            position, limits: limits,
            allowedRoot: permittedRoots, rootBonuses: bonuses, trace: onTrace,
            onExploredLine: onExploredLine
        ) else { return nil }
        var legal = state
        guard legal.apply(index: decision.index, actor: player) else { return nil }
        return GomokuBotMove(
            index: decision.index, score: decision.score, nodes: decision.nodes,
            elapsedMilliseconds: max(0, Int(
                (Date.timeIntervalSinceReferenceDate - started) * 1000
            )),
            engineLabel: "ECLIPSE · 训练策略"
        )
    }
}
