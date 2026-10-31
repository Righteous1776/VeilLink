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
    let continuationCandidateLimit: Int
    let timeLimitMilliseconds: Int

    static func standard(profileLabel: String) -> GomokuBotBudget {
        let upper = profileLabel.uppercased()
        if upper.contains("SE1") || upper.contains("LEGACY") || upper.contains("IPHONE7") {
            return GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: 16, replyCandidateLimit: 10, continuationCandidateLimit: 0, timeLimitMilliseconds: 150)
        }
        if upper.contains("HIGH") || upper.contains("13PRO") {
            return GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: 28, replyCandidateLimit: 16, continuationCandidateLimit: 8, timeLimitMilliseconds: 260)
        }
        return GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: 22, replyCandidateLimit: 12, continuationCandidateLimit: 6, timeLimitMilliseconds: 200)
    }

    static func forDifficulty(_ difficulty: BoardBotDifficulty, profileLabel: String) -> GomokuBotBudget {
        let legacy = profileLabel.uppercased().contains("SE1")
            || profileLabel.uppercased().contains("LEGACY")
            || profileLabel.uppercased().contains("IPHONE7")
        switch difficulty {
        case .relaxed:
            return GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: 12, replyCandidateLimit: 8, continuationCandidateLimit: 0, timeLimitMilliseconds: legacy ? 100 : 130)
        case .balanced:
            return standard(profileLabel: profileLabel)
        case .advanced:
            return GomokuBotBudget(candidateRadius: 2, rootCandidateLimit: legacy ? 22 : 36, replyCandidateLimit: legacy ? 14 : 22, continuationCandidateLimit: legacy ? 6 : 14, timeLimitMilliseconds: legacy ? 240 : 520)
        case .master:
            return GomokuBotBudget(candidateRadius: legacy ? 2 : 3, rootCandidateLimit: legacy ? 28 : 48, replyCandidateLimit: legacy ? 16 : 30, continuationCandidateLimit: legacy ? 8 : 20, timeLimitMilliseconds: legacy ? 420 : 950)
        }
    }

    func reinforced(by trainingLevel: Int) -> GomokuBotBudget {
        let reinforcement = max(0, min(8, trainingLevel))
        guard reinforcement > 0 else { return self }
        return GomokuBotBudget(
            candidateRadius: candidateRadius,
            rootCandidateLimit: min(56, rootCandidateLimit + reinforcement * 2),
            replyCandidateLimit: min(34, replyCandidateLimit + reinforcement),
            continuationCandidateLimit: continuationCandidateLimit == 0
                ? 0
                : min(22, continuationCandidateLimit + reinforcement),
            timeLimitMilliseconds: min(1_100, timeLimitMilliseconds + reinforcement * 45)
        )
    }

    static let deterministicTest = GomokuBotBudget(
        candidateRadius: 2,
        rootCandidateLimit: 18,
        replyCandidateLimit: 10,
        continuationCandidateLimit: 8,
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
        budget: GomokuBotBudget,
        learning: AdaptiveBoardLearningSnapshot = .empty,
        formationPreference: GomokuFormationPreference = .disabled
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

        let urgentDefense = formationPreference.enabled
            && GomokuFormationPreference.opponentHasImmediateWin(in: state, player: player)
        let rootPosition = AdaptiveBoardPosition.gomoku(state)
        let rankedRoots = candidates
            .map {
                let learned = learning.bonus(position: rootPosition, action: String($0))
                let sequence = learning.rootAdjustment(action: String($0))
                return ($0, tacticalPriority(index: $0, state: state, player: player) + learned + sequence
                    + formationPreference.bonus(index: $0, state: state, player: player, urgentDefense: urgentDefense))
            }
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
                let replyPosition = AdaptiveBoardPosition.gomoku(next)
                let predictedReply = learning.predictedHumanReply(afterAIAction: String(index))
                let replies = candidateIndices(in: next, radius: budget.candidateRadius)
                    .map {
                        let learned = learning.bonus(position: replyPosition, action: String($0))
                        let prediction = predictedReply?.action == String($0)
                            ? min(4_000, predictedReply!.evidence * 900)
                            : 0
                        return ($0, tacticalPriority(index: $0, state: next, player: opponent) + learned + prediction)
                    }
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
                    var replyScore: Int
                    if afterReply.winner == opponent {
                        replyScore = lossScore
                    } else {
                        replyScore = staticEvaluation(afterReply, root: player)
                        if budget.continuationCandidateLimit > 0 {
                            // Swift 5.9's type checker struggles with the chained
                            // tuple-map/sort/prefix here. Keep the same ordering and
                            // candidate cap using explicitly typed intermediate values.
                            let continuationCandidates: [Int] = candidateIndices(
                                in: afterReply, radius: budget.candidateRadius
                            )
                            var continuationScores: [(index: Int, priority: Int)] = []
                            continuationScores.reserveCapacity(continuationCandidates.count)
                            for candidate in continuationCandidates {
                                let priority: Int = tacticalPriority(
                                    index: candidate, state: afterReply, player: player
                                )
                                continuationScores.append((index: candidate, priority: priority))
                            }
                            continuationScores.sort { lhs, rhs in
                                if lhs.priority != rhs.priority {
                                    return lhs.priority > rhs.priority
                                }
                                return lhs.index < rhs.index
                            }
                            let continuationLimit = min(
                                continuationScores.count, budget.continuationCandidateLimit
                            )
                            var bestContinuation = Int.min
                            for rankedIndex in 0..<continuationLimit {
                                let continuation = continuationScores[rankedIndex].index
                                guard Date.timeIntervalSinceReferenceDate < deadline else { break }
                                nodes += 1
                                var afterContinuation = afterReply
                                guard afterContinuation.apply(index: continuation, actor: player) else { continue }
                                let continuationScore = afterContinuation.winner == player
                                    ? winScore
                                    : staticEvaluation(afterContinuation, root: player)
                                bestContinuation = max(bestContinuation, continuationScore)
                            }
                            if bestContinuation != Int.min { replyScore = bestContinuation }
                        }
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

    static func coachingHint(beforePlaying index: Int, in state: GomokuState, for player: MiniGamePlayer) -> String {
        let own: Int8 = player == .host ? 1 : 2
        let opponent: Int8 = player == .host ? 2 : 1
        let attack = placementPatternScore(index: index, state: state, value: own)
        let defend = placementPatternScore(index: index, state: state, value: opponent)
        if defend >= 8_000 { return "教练提示：这手优先封堵了对方的强威胁，防守判断正确。" }
        if attack >= 2_000 { return "教练提示：你正在建立强进攻形状；下一手留意对方的反冲。" }
        return "教练提示：落子后先同时检查自己的活三和对方的冲四。"
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
