import Foundation

/// A genuinely played match using the same GomokuState and native GomokuBot
/// as VeilLink's local human-vs-computer game. No diagram classification,
/// inferred moves, fake terminal results or non-native substitute evaluator.
struct NativeGomokuSelfPlayGame: Sendable {
    let plies: [AdaptiveBoardPly]
    let result: AdaptiveBoardGameResult
    let opening: Int
    let botDecisions: Int

    var completed: Bool { result != .unfinished && !plies.isEmpty }
}

/// Pure synchronous game runner. Call from a detached worker, NEVER the UI actor.
/// A deterministic preset first black stone creates opening diversity; every
/// subsequent move comes from the production native GomokuBot.chooseMove.
/// "Games trained" counts only complete, legal, durably recorded matches.
enum NativeGomokuSelfPlay {
    // 49 legal central starts; do not confuse replay count with novelty.
    static let openingIndices: [Int] = (4...10).flatMap { row in
        (4...10).map { column in row * GomokuState.size + column }
    }

    /// Different native search budgets create genuine deterministic Bot decision
    /// variants. Every move after the opening still comes from GomokuBot.
    static func curriculumBudget(seed: Int) -> GomokuBotBudget {
        switch (seed / openingIndices.count) % 4 {
        case 1:
            return GomokuBotBudget(
                candidateRadius: 2, rootCandidateLimit: 8,
                replyCandidateLimit: 4, continuationCandidateLimit: 0,
                timeLimitMilliseconds: 70
            )
        case 2:
            return GomokuBotBudget(
                candidateRadius: 2, rootCandidateLimit: 18,
                replyCandidateLimit: 8, continuationCandidateLimit: 0,
                timeLimitMilliseconds: 85
            )
        case 3:
            return GomokuBotBudget(
                candidateRadius: 2, rootCandidateLimit: 12,
                replyCandidateLimit: 6, continuationCandidateLimit: 4,
                timeLimitMilliseconds: 100
            )
        default:
            return trainingBudget
        }
    }

    /// Intentionally bounded for a real device; the user may resume in batches.
    static let trainingBudget = GomokuBotBudget(
        candidateRadius: 2,
        rootCandidateLimit: 12,
        replyCandidateLimit: 6,
        continuationCandidateLimit: 0,
        timeLimitMilliseconds: 70
    )

    static func play(
        seed: Int,
        formationMode: GomokuFormationMode,
        learning: AdaptiveBoardLearningSnapshot = .empty,
        budget: GomokuBotBudget? = nil,
        moveLimit: Int = GomokuState.size * GomokuState.size
    ) -> NativeGomokuSelfPlayGame? {
        guard moveLimit >= 5, !Task<Never, Never>.isCancelled else { return nil }
        var game = GomokuState()
        let opening = openingIndices[(seed % openingIndices.count + openingIndices.count) % openingIndices.count]
        let activeBudget = budget ?? curriculumBudget(seed: seed)
        let first = AdaptiveBoardPosition.gomoku(game)
        guard game.apply(index: opening, actor: .host) else { return nil }
        var plies = [AdaptiveBoardPly(position: first, action: String(opening), actor: .host)]
        // Guest remains the training Bot role in this runner; retain the host
        // opening history as its live opponent frontier for Veil 八卦阵 R2.
        var aiHistory: [Int] = []
        var opponentHistory: [Int] = [opening]
        var decisions = 0

        while game.winner == nil && !game.isDraw && game.moveCount < moveLimit {
            if Task<Never, Never>.isCancelled { return nil }
            let actor = game.currentPlayer
            let before = AdaptiveBoardPosition.gomoku(game)
            let preference = actor == .guest
                ? GomokuFormationPreference(
                    mode: formationMode,
                    aiHistory: aiHistory,
                    opponentHistory: opponentHistory,
                    discovered: []
                )
                : .disabled
            guard let chosen = GomokuBot.chooseMove(
                in: game,
                for: actor,
                budget: activeBudget,
                learning: learning,
                formationPreference: preference
            ), game.value(at: chosen.index) == 0,
               game.apply(index: chosen.index, actor: actor) else {
                return nil
            }
            plies.append(AdaptiveBoardPly(position: before, action: String(chosen.index), actor: actor))
            if actor == .guest {
                aiHistory.append(chosen.index)
            } else {
                opponentHistory.append(chosen.index)
            }
            decisions += 1
        }

        let result: AdaptiveBoardGameResult
        if let winner = game.winner {
            result = winner == .guest ? .aiWon : .humanWon
        } else if game.isDraw {
            result = .draw
        } else {
            // A timeout or ply limit is NOT silently a finished training game.
            return nil
        }

        return NativeGomokuSelfPlayGame(
            plies: plies, result: result, opening: opening, botDecisions: decisions
        )
    }
}
