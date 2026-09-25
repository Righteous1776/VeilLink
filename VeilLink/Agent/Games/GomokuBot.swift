import Foundation

struct GomokuBotMove: Equatable, Sendable {
    let index: Int
    let score: Int
    let nodes: Int
    let elapsedMilliseconds: Int
}

struct GomokuBotBudget: Equatable, Sendable {
    let candidateRadius: Int
    let rootCandidateLimit: Int
    let replyCandidateLimit: Int
    let timeLimitMilliseconds: Int

    static func standard(profileLabel: String) -> GomokuBotBudget {
        let upper = profileLabel.uppercased()
        if upper.contains("SE1") || upper.contains("LEGACY") || upper.contains("IPHONE7") {
            return GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: 16, replyCandidateLimit: 10, timeLimitMilliseconds: 150)
        }
        if upper.contains("HIGH") || upper.contains("13PRO") {
            return GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: 28, replyCandidateLimit: 16, timeLimitMilliseconds: 260)
        }
        return GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: 22, replyCandidateLimit: 12, timeLimitMilliseconds: 200)
    }

    static let deterministicTest = GomokuBotBudget(
        candidateRadius: 2,
        rootCandidateLimit: 18,
        replyCandidateLimit: 10,
        timeLimitMilliseconds: 2_000
    )
}

enum GomokuBot {
    private static let winScore = 2_000_000
    private static let lossScore = -2_000_000
    private static let size = GomokuState.size

    static func chooseMove(
        in state: GomokuState,
        for player: MiniGamePlayer,
        budget: GomokuBotBudget
    ) -> GomokuBotMove? {
        guard state.winner == nil,
              !state.isDraw,
              state.currentPlayer == player else { return nil }

        let started = Date.timeIntervalSinceReferenceDate
        let deadline = started + Double(max(30, budget.timeLimitMilliseconds)) / 1_000.0
        var nodes = 0
        var candidates = candidateIndices(in: state, radius: budget.candidateRadius)

        if candidates.isEmpty {
            candidates = [Self.size * Self.size / 2]
        }

        // Forced win takes priority and is cheap enough to test before ranking.
        for index in candidates {
            guard Date.timeIntervalSinceReferenceDate < deadline else { break }
            nodes += 1
            var next = state
            if next.apply(index: index, actor: player), next.winner == player {
                return result(index: index, score: winScore, nodes: nodes, started: started)
            }
        }

        let rankedRoots = candidates
            .map { ($0, tacticalPriority(index: $0, state: state, player: player)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
            .prefix(max(1, budget.rootCandidateLimit))

        var bestIndex: Int?
        var bestScore = Int.min

        for (index, priority) in rankedRoots {
            guard Date.timeIntervalSinceReferenceDate < deadline else { break }
            nodes += 1
            var next = state
            guard next.apply(index: index, actor: player) else { continue }

            var score = priority + staticEvaluation(next, root: player)
            if next.winner == player {
                score = winScore
            } else {
                let opponent = player.opponent
                let replies = candidateIndices(in: next, radius: budget.candidateRadius)
                    .map { ($0, tacticalPriority(index: $0, state: next, player: opponent)) }
                    .sorted { lhs, rhs in
                        if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                        return lhs.0 < rhs.0
                    }
                    .prefix(max(1, budget.replyCandidateLimit))

                var worstReply = Int.max
                for (reply, _) in replies {
                    guard Date.timeIntervalSinceReferenceDate < deadline else { break }
                    nodes += 1
                    var afterReply = next
                    guard afterReply.apply(index: reply, actor: opponent) else { continue }
                    let replyScore: Int
                    if afterReply.winner == opponent {
                        replyScore = lossScore
                    } else {
                        replyScore = staticEvaluation(afterReply, root: player)
                    }
                    worstReply = min(worstReply, replyScore)
                    if worstReply <= lossScore { break }
                }
                if worstReply != Int.max {
                    score = min(score, worstReply)
                }
            }

            if bestIndex == nil || score > bestScore || (score == bestScore && index < bestIndex!) {
                bestIndex = index
                bestScore = score
            }
        }

        guard let bestIndex else { return nil }
        return result(index: bestIndex, score: bestScore, nodes: nodes, started: started)
    }

    static func legalCandidateCount(in state: GomokuState, radius: Int = 2) -> Int {
        candidateIndices(in: state, radius: radius).count
    }

    private static func result(index: Int, score: Int, nodes: Int, started: TimeInterval) -> GomokuBotMove {
        GomokuBotMove(
            index: index,
            score: score,
            nodes: nodes,
            elapsedMilliseconds: max(0, Int((Date.timeIntervalSinceReferenceDate - started) * 1_000))
        )
    }

    private static func candidateIndices(in state: GomokuState, radius: Int) -> [Int] {
        let occupied = (0..<(size * size)).filter { state.value(at: $0) != 0 }
        guard !occupied.isEmpty else { return [size * size / 2] }

        var set = Set<Int>()
        for index in occupied {
            let row = index / size
            let col = index % size
            for dr in -radius...radius {
                for dc in -radius...radius where dr != 0 || dc != 0 {
                    let r = row + dr
                    let c = col + dc
                    guard (0..<size).contains(r), (0..<size).contains(c) else { continue }
                    let candidate = r * size + c
                    if state.value(at: candidate) == 0 { set.insert(candidate) }
                }
            }
        }
        return set.sorted()
    }

    private static func tacticalPriority(index: Int, state: GomokuState, player: MiniGamePlayer) -> Int {
        let own: Int8 = player == .host ? 1 : 2
        let opp: Int8 = player == .host ? 2 : 1
        let attack = placementPatternScore(index: index, state: state, value: own)
        let defend = placementPatternScore(index: index, state: state, value: opp)
        let row = index / size
        let col = index % size
        let center = size / 2
        let centrality = max(0, 14 - abs(row - center) - abs(col - center))
        return attack * 12 + defend * 10 + centrality
    }

    private static func staticEvaluation(_ state: GomokuState, root: MiniGamePlayer) -> Int {
        if let winner = state.winner {
            return winner == root ? winScore : lossScore
        }
        let own: Int8 = root == .host ? 1 : 2
        let opp: Int8 = root == .host ? 2 : 1
        var score = 0
        for index in 0..<(size * size) where state.value(at: index) == 0 {
            score += placementPatternScore(index: index, state: state, value: own)
            score -= placementPatternScore(index: index, state: state, value: opp)
        }
        return score
    }

    private static func placementPatternScore(index: Int, state: GomokuState, value: Int8) -> Int {
        guard state.value(at: index) == 0 else { return Int.min / 8 }
        let row = index / size
        let col = index % size
        var total = 0
        for (dr, dc) in [(1, 0), (0, 1), (1, 1), (1, -1)] {
            let a = count(state: state, row: row, col: col, dr: dr, dc: dc, value: value)
            let b = count(state: state, row: row, col: col, dr: -dr, dc: -dc, value: value)
            let run = a + b + 1
            let openA = isOpen(state: state, row: row + dr * (a + 1), col: col + dc * (a + 1))
            let openB = isOpen(state: state, row: row - dr * (b + 1), col: col - dc * (b + 1))
            let openEnds = (openA ? 1 : 0) + (openB ? 1 : 0)
            switch (run, openEnds) {
            case (5..., _): total += 120_000
            case (4, 2): total += 22_000
            case (4, 1): total += 8_000
            case (3, 2): total += 2_000
            case (3, 1): total += 500
            case (2, 2): total += 160
            case (2, 1): total += 45
            default: total += openEnds * 5
            }
        }
        return total
    }

    private static func count(
        state: GomokuState,
        row: Int,
        col: Int,
        dr: Int,
        dc: Int,
        value: Int8
    ) -> Int {
        var r = row + dr
        var c = col + dc
        var result = 0
        while (0..<size).contains(r), (0..<size).contains(c), state.value(at: r * size + c) == value {
            result += 1
            r += dr
            c += dc
        }
        return result
    }

    private static func isOpen(state: GomokuState, row: Int, col: Int) -> Bool {
        guard (0..<size).contains(row), (0..<size).contains(col) else { return false }
        return state.value(at: row * size + col) == 0
    }
}
