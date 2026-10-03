import Foundation

struct LudoBotMove: Equatable, Sendable {
    let pieceIndex: Int
    let score: Int
}

enum LudoBot {
    static func chooseMove(
        in state: LudoState,
        for player: MiniGamePlayer,
        sessionID: String,
        difficulty: BoardBotDifficulty = .strategist
    ) -> LudoBotMove? {
        guard state.winner == nil, state.currentPlayer == player else { return nil }
        let legal = state.legalPieces(sessionID: sessionID).sorted()
        if legal.isEmpty {
            return LudoBotMove(pieceIndex: -1, score: 0)
        }

        if difficulty == .trainee, let first = legal.first {
            var next = state
            guard next.apply(pieceIndex: first, actor: player, sessionID: sessionID) else {
                return nil
            }
            return LudoBotMove(
                pieceIndex: first,
                score: evaluate(before: state, after: next, player: player, movedPiece: first)
            )
        }

        var best: LudoBotMove?
        for piece in legal {
            var next = state
            guard next.apply(pieceIndex: piece, actor: player, sessionID: sessionID) else { continue }

            var score = evaluate(before: state, after: next, player: player, movedPiece: piece)
            if difficulty == .master,
               next.winner == nil,
               next.currentPlayer == player.opponent {
                score -= strongestReplyScore(
                    in: next,
                    for: player.opponent,
                    sessionID: sessionID
                ) / 2
            }

            let candidate = LudoBotMove(pieceIndex: piece, score: score)
            if best == nil
                || candidate.score > best!.score
                || (candidate.score == best!.score && piece < best!.pieceIndex) {
                best = candidate
            }
        }
        return best
    }


    private static func strongestReplyScore(
        in state: LudoState,
        for player: MiniGamePlayer,
        sessionID: String
    ) -> Int {
        let legal = state.legalPieces(sessionID: sessionID).sorted()
        var best = 0
        for piece in legal {
            var reply = state
            guard reply.apply(pieceIndex: piece, actor: player, sessionID: sessionID) else { continue }
            best = max(
                best,
                evaluate(before: state, after: reply, player: player, movedPiece: piece)
            )
        }
        return best
    }

    private static func evaluate(before: LudoState, after: LudoState, player: MiniGamePlayer, movedPiece: Int) -> Int {
        let oldPieces = before.pieces(for: player)
        let newPieces = after.pieces(for: player)
        let oldProgress = oldPieces[movedPiece]
        let newProgress = newPieces[movedPiece]

        var score = 0
        if newProgress == LudoState.finishProgress { score += 8_000 }
        if oldProgress == -1, newProgress == 0 { score += 850 }
        score += max(0, newProgress - max(oldProgress, 0)) * 18
        score += after.lastCapturedCount * 2_200
        if after.lastMoveGrantedExtraTurn { score += 500 }
        score += after.finishedCount(for: player) * 1_200

        if let track = after.trackPosition(player: player, progress: newProgress), [0, 13, 26, 39].contains(track) {
            score += 180
        }

        return score
    }
}
