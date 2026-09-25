import Foundation

struct XiangqiBotMove: Equatable, Sendable {
    let from: Int
    let to: Int
    let score: Int
    let completedDepth: Int
    let nodes: Int
    let elapsedMilliseconds: Int
}

struct XiangqiBotBudget: Equatable, Sendable {
    let maxDepth: Int
    let quiescenceDepth: Int
    let timeLimitMilliseconds: Int

    static func standard(profileLabel: String) -> XiangqiBotBudget {
        let upper = profileLabel.uppercased()
        if upper.contains("SE1") || upper.contains("LEGACY") || upper.contains("IPHONE7") {
            return XiangqiBotBudget(maxDepth: 4, quiescenceDepth: 1, timeLimitMilliseconds: 180)
        }
        if upper.contains("HIGH") || upper.contains("13PRO") {
            return XiangqiBotBudget(maxDepth: 6, quiescenceDepth: 2, timeLimitMilliseconds: 420)
        }
        return XiangqiBotBudget(maxDepth: 5, quiescenceDepth: 2, timeLimitMilliseconds: 280)
    }

    static let deterministicTest = XiangqiBotBudget(
        maxDepth: 2,
        quiescenceDepth: 1,
        timeLimitMilliseconds: 2_000
    )
}

enum XiangqiBot {
    private static let mateScore = 1_000_000
    private static let infinity = 2_000_000

    private struct Move: Equatable {
        let from: Int
        let to: Int
        let orderingScore: Int
    }

    private struct SearchContext {
        let deadline: TimeInterval
        let rootPlayer: MiniGamePlayer
        let quiescenceDepth: Int
        var nodes = 0
        var stopped = false

        mutating func checkpoint() -> Bool {
            nodes += 1
            if Date.timeIntervalSinceReferenceDate >= deadline {
                stopped = true
                return false
            }
            return true
        }
    }

    static func chooseMove(
        in state: XiangqiState,
        for player: MiniGamePlayer,
        budget: XiangqiBotBudget
    ) -> XiangqiBotMove? {
        guard state.winner == nil,
              !state.isDraw,
              state.currentPlayer == player else {
            return nil
        }

        let started = Date.timeIntervalSinceReferenceDate
        let deadline = started + Double(max(40, budget.timeLimitMilliseconds)) / 1_000.0
        let rootMoves = orderedLegalMoves(in: state, actor: player)
        guard !rootMoves.isEmpty else { return nil }

        var bestCompleted: (move: Move, score: Int, depth: Int)?
        var context = SearchContext(
            deadline: deadline,
            rootPlayer: player,
            quiescenceDepth: max(0, budget.quiescenceDepth)
        )

        for depth in 1...max(1, budget.maxDepth) {
            if Date.timeIntervalSinceReferenceDate >= deadline { break }

            var alpha = -infinity
            let beta = infinity
            var iterationBest: (move: Move, score: Int)?
            var completed = true

            for move in rootMoves {
                if !context.checkpoint() {
                    completed = false
                    break
                }

                var next = state
                guard next.apply(from: move.from, to: move.to, actor: player) else {
                    continue
                }

                var score = search(
                    state: next,
                    depth: depth - 1,
                    alpha: alpha,
                    beta: beta,
                    context: &context
                )

                // Repetition is legal but usually undesirable when another close move exists.
                if next.currentPositionRepetitionCount >= 2 {
                    score -= 90
                }

                if context.stopped {
                    completed = false
                    break
                }

                if iterationBest == nil
                    || score > iterationBest!.score
                    || (score == iterationBest!.score && stableOrder(move) < stableOrder(iterationBest!.move)) {
                    iterationBest = (move, score)
                }
                alpha = max(alpha, score)
            }

            guard completed, let iterationBest else { break }
            bestCompleted = (iterationBest.move, iterationBest.score, depth)
        }

        let selected: (move: Move, score: Int, depth: Int)
        if let bestCompleted {
            selected = bestCompleted
        } else {
            let fallback = rootMoves[0]
            selected = (fallback, evaluate(afterApplying: fallback, to: state, actor: player, root: player), 0)
        }

        let elapsed = Int((Date.timeIntervalSinceReferenceDate - started) * 1_000)
        return XiangqiBotMove(
            from: selected.move.from,
            to: selected.move.to,
            score: selected.score,
            completedDepth: selected.depth,
            nodes: context.nodes,
            elapsedMilliseconds: max(0, elapsed)
        )
    }

    static func legalMoveCount(in state: XiangqiState, actor: MiniGamePlayer) -> Int {
        orderedLegalMoves(in: state, actor: actor).count
    }

    private static func search(
        state: XiangqiState,
        depth: Int,
        alpha: Int,
        beta: Int,
        context: inout SearchContext
    ) -> Int {
        guard context.checkpoint() else {
            return evaluate(state, root: context.rootPlayer)
        }

        if let winner = state.winner {
            return winner == context.rootPlayer
                ? mateScore + depth
                : -mateScore - depth
        }
        if state.isDraw {
            return 0
        }
        if depth <= 0 {
            return quiescence(
                state: state,
                remaining: context.quiescenceDepth,
                alpha: alpha,
                beta: beta,
                context: &context
            )
        }

        let actor = state.currentPlayer
        let moves = orderedLegalMoves(in: state, actor: actor)
        if moves.isEmpty {
            return state.isInCheck(player: actor)
                ? (actor == context.rootPlayer ? -mateScore - depth : mateScore + depth)
                : 0
        }

        if actor == context.rootPlayer {
            var best = -infinity
            var localAlpha = alpha
            for move in moves {
                if context.stopped { break }
                var next = state
                guard next.apply(from: move.from, to: move.to, actor: actor) else { continue }
                let value = search(
                    state: next,
                    depth: depth - 1,
                    alpha: localAlpha,
                    beta: beta,
                    context: &context
                )
                best = max(best, value)
                localAlpha = max(localAlpha, best)
                if localAlpha >= beta { break }
            }
            return best == -infinity ? evaluate(state, root: context.rootPlayer) : best
        } else {
            var best = infinity
            var localBeta = beta
            for move in moves {
                if context.stopped { break }
                var next = state
                guard next.apply(from: move.from, to: move.to, actor: actor) else { continue }
                let value = search(
                    state: next,
                    depth: depth - 1,
                    alpha: alpha,
                    beta: localBeta,
                    context: &context
                )
                best = min(best, value)
                localBeta = min(localBeta, best)
                if alpha >= localBeta { break }
            }
            return best == infinity ? evaluate(state, root: context.rootPlayer) : best
        }
    }

    private static func quiescence(
        state: XiangqiState,
        remaining: Int,
        alpha: Int,
        beta: Int,
        context: inout SearchContext
    ) -> Int {
        guard context.checkpoint() else {
            return evaluate(state, root: context.rootPlayer)
        }
        if let winner = state.winner {
            return winner == context.rootPlayer ? mateScore : -mateScore
        }
        if state.isDraw { return 0 }

        let standPat = evaluate(state, root: context.rootPlayer)
        guard remaining > 0 else { return standPat }

        let actor = state.currentPlayer
        let captures = orderedLegalMoves(in: state, actor: actor).filter {
            state.piece(at: $0.to) != nil
        }
        guard !captures.isEmpty else { return standPat }

        if actor == context.rootPlayer {
            var best = standPat
            var localAlpha = max(alpha, best)
            if localAlpha >= beta { return best }

            for move in captures {
                if context.stopped { break }
                var next = state
                guard next.apply(from: move.from, to: move.to, actor: actor) else { continue }
                let value = quiescence(
                    state: next,
                    remaining: remaining - 1,
                    alpha: localAlpha,
                    beta: beta,
                    context: &context
                )
                best = max(best, value)
                localAlpha = max(localAlpha, best)
                if localAlpha >= beta { break }
            }
            return best
        } else {
            var best = standPat
            var localBeta = min(beta, best)
            if alpha >= localBeta { return best }

            for move in captures {
                if context.stopped { break }
                var next = state
                guard next.apply(from: move.from, to: move.to, actor: actor) else { continue }
                let value = quiescence(
                    state: next,
                    remaining: remaining - 1,
                    alpha: alpha,
                    beta: localBeta,
                    context: &context
                )
                best = min(best, value)
                localBeta = min(localBeta, best)
                if alpha >= localBeta { break }
            }
            return best
        }
    }

    private static func orderedLegalMoves(
        in state: XiangqiState,
        actor: MiniGamePlayer
    ) -> [Move] {
        guard state.currentPlayer == actor else { return [] }

        var moves: [Move] = []
        moves.reserveCapacity(48)

        for from in 0..<(XiangqiState.rows * XiangqiState.columns) {
            guard state.piece(at: from) != nil else { continue }
            for to in state.legalDestinations(from: from, actor: actor) {
                let capture = state.piece(at: to).map { pieceValue($0.kind) } ?? 0
                var next = state
                let legal = next.apply(from: from, to: to, actor: actor)
                guard legal else { continue }

                var ordering = capture * 16
                if next.isInCheck(player: actor.opponent) {
                    ordering += 600
                }
                if next.winner == actor {
                    ordering += mateScore
                }
                moves.append(Move(from: from, to: to, orderingScore: ordering))
            }
        }

        return moves.sorted {
            if $0.orderingScore != $1.orderingScore {
                return $0.orderingScore > $1.orderingScore
            }
            return stableOrder($0) < stableOrder($1)
        }
    }

    private static func evaluate(
        afterApplying move: Move,
        to state: XiangqiState,
        actor: MiniGamePlayer,
        root: MiniGamePlayer
    ) -> Int {
        var next = state
        guard next.apply(from: move.from, to: move.to, actor: actor) else {
            return -infinity
        }
        return evaluate(next, root: root)
    }

    private static func evaluate(_ state: XiangqiState, root: MiniGamePlayer) -> Int {
        if let winner = state.winner {
            return winner == root ? mateScore : -mateScore
        }
        if state.isDraw { return 0 }

        var score = 0
        for index in 0..<(XiangqiState.rows * XiangqiState.columns) {
            guard let piece = state.piece(at: index) else { continue }
            let owner: MiniGamePlayer = piece.side == .red ? .host : .guest
            let row = index / XiangqiState.columns
            let col = index % XiangqiState.columns

            var value = pieceValue(piece.kind)
            switch piece.kind {
            case .soldier:
                let advance = piece.side == .red ? (9 - row) : row
                value += advance * 9
                let crossed = piece.side == .red ? row <= 4 : row >= 5
                if crossed { value += 22 }
            case .horse, .cannon:
                value += max(0, 4 - abs(col - 4)) * 5
            case .rook:
                value += max(0, 4 - abs(col - 4)) * 3
            default:
                break
            }

            score += owner == root ? value : -value
        }

        if state.isInCheck(player: root) { score -= 75 }
        if state.isInCheck(player: root.opponent) { score += 75 }

        let ownChecks = state.consecutiveCheckCount(for: root)
        if ownChecks >= 2 { score -= 20 * ownChecks }

        if state.currentPositionRepetitionCount >= 2 {
            score += state.currentPlayer == root ? -35 : 35
        }

        return score
    }

    private static func pieceValue(_ kind: XiangqiPieceKind) -> Int {
        switch kind {
        case .general: return 100_000
        case .advisor: return 220
        case .elephant: return 220
        case .horse: return 450
        case .rook: return 900
        case .cannon: return 500
        case .soldier: return 100
        }
    }

    private static func stableOrder(_ move: Move) -> Int {
        move.from * 100 + move.to
    }
}
