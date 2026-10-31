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
    private static let openingIndices = [
        112, 111, 113, 97, 127, 96, 98, 126, 128,
        110, 114, 82, 142, 95, 99, 125, 129
    ]

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
        budget: GomokuBotBudget = trainingBudget,
        moveLimit: Int = GomokuState.size * GomokuState.size
    ) -> NativeGomokuSelfPlayGame? {
        guard moveLimit >= 5, !Task<Never, Never>.isCancelled else { return nil }
        var game = GomokuState()
        let opening = openingIndices[abs(seed % openingIndices.count)]
        let first = AdaptiveBoardPosition.gomoku(game)
        guard game.apply(index: opening, actor: .host) else { return nil }
        var plies = [AdaptiveBoardPly(position: first, action: String(opening), actor: .host)]
        var aiHistory: [Int] = []
        var decisions = 0

        while game.winner == nil && !game.isDraw && game.moveCount < moveLimit {
            if Task<Never, Never>.isCancelled { return nil }
            let actor = game.currentPlayer
            let before = AdaptiveBoardPosition.gomoku(game)
            let preference = actor == .guest
                ? GomokuFormationPreference(mode: formationMode, aiHistory: aiHistory, discovered: [])
                : .disabled
            guard let chosen = GomokuBot.chooseMove(
                in: game,
                for: actor,
                budget: budget,
                learning: learning,
                formationPreference: preference
            ), game.value(at: chosen.index) == 0,
               game.apply(index: chosen.index, actor: actor) else {
                return nil
            }
            plies.append(AdaptiveBoardPly(position: before, action: String(chosen.index), actor: actor))
            if actor == .guest { aiHistory.append(chosen.index) }
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
