import Foundation

struct GomokuBotMove: Equatable, Sendable {
    let index: Int
    let score: Int
    let nodes: Int
    let elapsedMilliseconds: Int
    var engineLabel: String? = nil
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
        formationPreference: GomokuFormationPreference = .disabled,
        diagnosticCounterForkR4: Bool = true,
        diagnosticUseR6Defense: Bool = true,
        diagnosticR8ForcedWin: Bool = true,
        diagnosticEclipseUnified: Bool = true,
        difficultyRawValue: String? = nil
    ) -> GomokuBotMove? {
        guard state.winner == nil,
              !state.isDraw,
              state.currentPlayer == player else { return nil }

        let started = Date.timeIntervalSinceReferenceDate
        // First move has only one native search candidate: the center.
        // Avoid expensive full static search for the unambiguous empty board.
        if state.moveCount == 0 {
            return result(index: Self.size * Self.size / 2, score: 0, nodes: 1, started: started)
        }
        let deadline = started + Double(max(30, budget.timeLimitMilliseconds)) / 1_000.0
        var nodes = 0
        var candidates = candidateIndices(in: state, radius: budget.candidateRadius)

        if candidates.isEmpty {
            candidates = [Self.size * Self.size / 2]
        }

        // Mandatory tactics must run even if the wall-clock search budget has
        // already expired under heavy UI/CI load. This bounded 225-cell scan
        // cannot be skipped by voluntary time cutoff.
        for index in candidates {
            nodes += 1
            var next = state
            if next.apply(index: index, actor: player), next.winner == player {
                return result(index: index, score: winScore, nodes: nodes, started: started)
            }
        }

        // Selected from the tactical-safety Inbox proposal PR #111.
        // Learning/formation preferences must not outrank blocking an immediate
        // opponent five. Inspect stone geometry without mutating turn ownership.
        let opposingStone: Int8 = player == .host ? 2 : 1
        for index in candidates {
            nodes += 1
            if completesFive(index: index, in: state, stone: opposingStone) {
                return result(index: index, score: winScore / 2, nodes: nodes, started: started)
            }
        }

        // R8: one-pass deterministic proof of win-in-two from real native
        // missed opportunities. More reliable than hoping a short search
        // budget will rank the winning fork. Never override immediate
        // own-win or mandatory immediate-opponent-block checks above.
        // Diagnostic opt-out preserves prior R3/R4/R6 paired comparisons.
        if diagnosticR8ForcedWin,
           let forcing = GomokuCounterForkR4.immediateTwoTurnWinCandidate(
                in: state, player: player, candidates: candidates
           ) {
            nodes += 1
            return result(index: forcing, score: winScore - 1, nodes: nodes, started: started)
        }

        let urgentDefense = formationPreference.enabled
            && GomokuFormationPreference.opponentHasImmediateWin(in: state, player: player)
        let rootPosition = AdaptiveBoardPosition.gomoku(state)
        // R4: rule-verified opponent fork suppression runs strictly AFTER
        // the mandatory own-win/opponent-immediate-win gates. Ordinary
        // positions pay for one bounded 225-cell scan, not a deep rollout.
        // The default is identical to production R4. The explicit `false`
        // path is ONLY for matched-opening same-engine R3/R4 diagnostic
        // tournaments, not a user-facing feature switch.
        let defensive: (moves: [Int], underThreat: Bool) = diagnosticCounterForkR4
            ? GomokuCounterForkR4.safeCandidates(
                in: state, player: player, candidates: candidates
              )
            : (candidates, false)
        let rankedRoots = defensive.moves
            .map {
                let learned = learning.bonus(position: rootPosition, action: String($0))
                let sequence = learning.rootAdjustment(action: String($0))
                let trainedDefense: Int
                if defensive.underThreat {
                    trainedDefense = diagnosticUseR6Defense
                        ? GomokuCounterForkR4.trainedR6DefensiveBonus(
                            in: state, player: player, index: $0
                          )
                        : GomokuCounterForkR4.trainedDefensiveBonus(
                            in: state, player: player, index: $0
                          )
                } else {
                    trainedDefense = 0
                }
                return ($0, tacticalPriority(index: $0, state: state, player: player)
                    + trainedR3ForkBonus(index: $0, state: state, player: player)
                    + trainedDefense + learned + sequence
                    + formationPreference.bonus(index: $0, state: state, player: player, urgentDefense: urgentDefense))
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0 < rhs.0
            }
            .prefix(max(1, budget.rootCandidateLimit))

        // ECLIPSE R10: preserve all incumbent mandatory rules and learned
        // root scores, then search with the trained entire-tree ordering.
        // The real rules below the bridge remain the final legality gate.
        let remainingMilliseconds = Int(max(0, (deadline - Date.timeIntervalSinceReferenceDate) * 1_000))
        let unifiedBudget = GomokuBotBudget(
            candidateRadius: budget.candidateRadius,
            rootCandidateLimit: budget.rootCandidateLimit,
            replyCandidateLimit: budget.replyCandidateLimit,
            continuationCandidateLimit: budget.continuationCandidateLimit,
            timeLimitMilliseconds: remainingMilliseconds
        )
        if diagnosticEclipseUnified, remainingMilliseconds >= 30,
           let unified = VeilGomokuUnifiedBridge.chooseMove(
                in: state, for: player, budget: unifiedBudget,
                permittedRoots: rankedRoots.map { $0.0 },
                rootScores: Dictionary(uniqueKeysWithValues: rankedRoots.map { ($0.0, $0.1) }),
                difficultyRawValue: difficultyRawValue
           ) {
            return unified
        }

        // A time budget is a *search-quality* bound, not permission to return
        // no move in an otherwise legal position. A delayed worker can enter
        // the root loop after its deadline, so retain the best ranked legal
        // root as the emergency fallback (mandatory win/block scans ran first).
        let safeFallback = rankedRoots.first
        var bestIndex: Int? = safeFallback?.0
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
        let resolvedScore = bestScore == Int.min ? (safeFallback?.1 ?? 0) : bestScore
        return result(index: bestIndex, score: resolvedScore, nodes: nodes, started: started)
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

    /// True when a hypothetical legal stone at index connects five in a row.
    private static func completesFive(index: Int, in state: GomokuState, stone: Int8) -> Bool {
        guard state.value(at: index) == 0 else { return false }
        let row = index / size
        let col = index % size
        for (dr, dc) in [(1, 0), (0, 1), (1, 1), (1, -1)] {
            let connected = 1
                + count(state: state, row: row, col: col, dr: dr, dc: dc, value: stone)
                + count(state: state, row: row, col: col, dr: -dr, dc: -dc, value: stone)
            if connected >= 5 { return true }
        }
        return false
    }


    /// R3 policy distillation from replayed VeilLink v28 real positions.
    /// Trained on 53,125 nonforced candidate examples; 18,585 position-disjoint
    /// holdout examples. Predicts *two simultaneous next-turn five threats*,
    /// not an Elo, solved win, or optimal human move.
    /// Root hint is strictly bounded. The mandatory win/block scans above run
    /// before this policy and native search still owns the final decision.
    static func trainedR3ForkBonus(index: Int, state: GomokuState, player: MiniGamePlayer) -> Int {
        guard state.value(at: index) == 0 else { return 0 }
        let row = index / size
        let col = index % size
        let own: Int8 = player == .host ? 1 : 2
        let enemy: Int8 = own == 1 ? 2 : 1
        var ownThree = 0, enemyThree = 0, ownTwo = 0, enemyTwo = 0

        // Match the OFFLINE train-time five-cell-window feature extractor.
        for (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)] {
            for shift in 0..<5 {
                let firstRow = row - dr * shift
                let firstCol = col - dc * shift
                let lastRow = firstRow + dr * 4
                let lastCol = firstCol + dc * 4
                guard (0..<size).contains(firstRow), (0..<size).contains(firstCol),
                      (0..<size).contains(lastRow), (0..<size).contains(lastCol) else { continue }
                var ownCount = 0, enemyCount = 0
                for offset in 0..<5 {
                    let r = firstRow + dr * offset
                    let c = firstCol + dc * offset
                    if r == row && c == col { continue }
                    let stone = state.value(at: r * size + c)
                    if stone == own { ownCount += 1 }
                    if stone == enemy { enemyCount += 1 }
                }
                if enemyCount == 0 {
                    if ownCount == 3 { ownThree += 1 }
                    if ownCount == 2 { ownTwo += 1 }
                }
                if ownCount == 0 {
                    if enemyCount == 3 { enemyThree += 1 }
                    if enemyCount == 2 { enemyTwo += 1 }
                }
            }
        }

        var friendlyAdjacent = 0, enemyAdjacent = 0
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let r = row + dr, c = col + dc
                guard (0..<size).contains(r), (0..<size).contains(c) else { continue }
                let stone = state.value(at: r * size + c)
                if stone == own { friendlyAdjacent += 1 }
                if stone == enemy { enemyAdjacent += 1 }
            }
        }
        let centrality = Double(14 - abs(row - 7) - abs(col - 7)) / 14
        let features = [
            Double(ownThree), Double(enemyThree), Double(ownTwo), Double(enemyTwo),
            Double(friendlyAdjacent), Double(enemyAdjacent), centrality
        ]
        let trained = [
            8.908273703236532, 0.5963231127800033, 0.031010864699874865,
            0.38785730930075774, 0.07346957532346292, 0.14558021087394568,
            0.4029194642259561
        ]
        var logit = -12.706419814435504
        for j in 0..<trained.count { logit += trained[j] * features[j] }
        return max(0, min(2_400, Int(max(0, logit) * 350)))
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
