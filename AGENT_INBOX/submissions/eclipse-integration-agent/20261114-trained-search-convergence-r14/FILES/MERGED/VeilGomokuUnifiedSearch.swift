import Foundation

/// Independently authored, platform-neutral freestyle Gomoku search.
/// Algorithms are general game-tree techniques; no vendored engine is linked.
/// Input cells: row-major 15x15, 0 empty, 1 black, 2 white.
enum VeilGomokuUnifiedSearch {
    static let boardSize = 15
    static let capacity = boardSize * boardSize
    static let mate = 10_000_000
    private static let infinity = mate + 100_000
    private static let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]

    struct Position: Sendable {
        let cells: [UInt8]
        let toMove: UInt8

        init?(cells: [UInt8], toMove: UInt8) {
            guard cells.count == capacity,
                  toMove == 1 || toMove == 2,
                  cells.allSatisfy({ $0 <= 2 }) else { return nil }
            self.cells = cells
            self.toMove = toMove
        }
    }

    struct Limits: Sendable {
        var maxDepth: Int = 5
        var maxNodes: Int = 80_000
        var maxMilliseconds: Int = 600
        var width: Int = 14
        var forcedLineDepth: Int = 5
        var candidateRadius: Int = 2
        // R13 exact threat-index acceleration, disabled before iOS and arena gates.
        var r13IncrementalThreatIndexEnabled: Bool = false
        /// R12 is explicitly opt-in until full iOS/arena promotion.
        var r12HorizonQuiescence: Bool = false
        /// At most three forced defensive plies at depth-zero.
        var r12MaxForcedBlocks: Int = 2
    }

    enum Phase: String, Sendable {
        case validating
        case forcedLine
        case deepening
        case complete
    }

    struct Trace: Sendable {
        let phase: Phase
        let completedDepth: Int
        let nodes: Int
        let rootCandidates: Int
        let selectedIndex: Int?
        let score: Int?
        let variation: [Int]
        let rule: String
    }

    struct Decision: Sendable {
        let index: Int
        let score: Int
        let completedDepth: Int
        let nodes: Int
        let variation: [Int]
        let rule: String
    }

    /// Root bonuses are native learned/history preferences, capped below mate scores.
    /// Trace snapshots correspond to actual completed search work only.
    static func decide(
        _ position: Position,
        limits: Limits = Limits(),
        allowedRoot: [Int]? = nil,
        rootBonuses: [Int: Int] = [:],
        trainedPolicy: Bool = true,
        trace: ((Trace) -> Void)? = nil,
        onExploredLine: (@Sendable ([Int], Int) -> Void)? = nil
    ) -> Decision? {
        var searcher = Searcher(position: position, limits: limits,
                                allowedRoot: allowedRoot, rootBonuses: rootBonuses,
                                trainedPolicy: trainedPolicy, trace: trace,
                                onExploredLine: onExploredLine)
        return searcher.run()
    }

    private struct Entry {
        let depth: Int
        let score: Int
        let flag: UInt8 // 0 exact; 1 lower bound; 2 upper bound
        let best: Int
    }

    private struct SplitMix64 {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var x = state
            x = (x ^ (x >> 30)) &* 0xbf58476d1ce4e5b9
            x = (x ^ (x >> 27)) &* 0x94d049bb133111eb
            return x ^ (x >> 31)
        }
    }

    private static let zobrist: [[UInt64]] = {
        var generator = SplitMix64(state: 0xD40C0F0A2026)
        return (0..<capacity).map { _ in
            [UInt64(0), generator.next(), generator.next()]
        }
    }()
    private static let sideHash: [UInt64] = {
        var generator = SplitMix64(state: 0xB0611A27)
        return [UInt64(0), generator.next(), generator.next()]
    }()

    private struct Searcher {
        var board: [UInt8]
        let player: UInt8
        let limits: Limits
        let allowed: Set<Int>?
        let bonuses: [Int: Int]
        let trainedPolicy: Bool
        let trace: ((Trace) -> Void)?
        let onExploredLine: (@Sendable ([Int], Int) -> Void)?
        var exploredPath: [Int] = []
        var hash: UInt64 = 0
        var nodes = 0
        var table: [UInt64: Entry] = [:]
        let started = Date.timeIntervalSinceReferenceDate
        var interrupted = false
        var r13Index: EclipseIncrementalThreatIndexR13?

        init(position: Position, limits: Limits, allowedRoot: [Int]?,
             rootBonuses: [Int: Int], trainedPolicy: Bool, trace: ((Trace) -> Void)?,
             onExploredLine: (@Sendable ([Int], Int) -> Void)?) {
            self.board = position.cells
            self.player = position.toMove
            self.limits = limits
            self.allowed = allowedRoot.map { Set($0.filter { (0..<capacity).contains($0) }) }
            self.bonuses = rootBonuses
            self.trainedPolicy = trainedPolicy
            self.trace = trace
            self.onExploredLine = onExploredLine
            self.r13Index = limits.r13IncrementalThreatIndexEnabled
                ? EclipseIncrementalThreatIndexR13(cells: position.cells) : nil
            for i in 0..<capacity where board[i] != 0 {
                hash ^= VeilGomokuUnifiedSearch.zobrist[i][Int(board[i])]
            }
        }

        private func opponent(_ side: UInt8) -> UInt8 { side == 1 ? 2 : 1 }
        private func valid(_ r: Int, _ c: Int) -> Bool { (0..<boardSize).contains(r) && (0..<boardSize).contains(c) }

        private func winningStone(at index: Int, side: UInt8) -> Bool {
            guard (0..<capacity).contains(index) else { return false }
            let r = index / boardSize, c = index % boardSize
            for (dr, dc) in directions {
                var count = 1
                for sign in [-1, 1] {
                    var nr = r + sign * dr, nc = c + sign * dc
                    while valid(nr, nc) && board[nr * boardSize + nc] == side {
                        count += 1
                        nr += sign * dr
                        nc += sign * dc
                    }
                }
                if count >= 5 { return true }
            }
            return false
        }

        private mutating func place(_ index: Int, _ side: UInt8) {
            if r13Index != nil && !r13Index!.place(index, stone: side) {
                // Fail back to the incumbent exact scans on cache divergence.
                r13Index = nil
            }
            board[index] = side
            hash ^= VeilGomokuUnifiedSearch.zobrist[index][Int(side)]
        }
        private mutating func unplace(_ index: Int, _ side: UInt8) {
            if r13Index != nil && !r13Index!.undo(index, stone: side) {
                r13Index = nil
            }
            board[index] = 0
            hash ^= VeilGomokuUnifiedSearch.zobrist[index][Int(side)]
        }

        private func neighbors(radius: Int) -> [Int] {
            var seen = [Bool](repeating: false, count: capacity)
            var occupied = 0
            let radius = max(1, min(3, radius))
            for i in 0..<capacity where board[i] != 0 {
                occupied += 1
                let r = i / boardSize, c = i % boardSize
                for dr in -radius...radius {
                    for dc in -radius...radius {
                        let rr = r + dr, cc = c + dc
                        if valid(rr, cc) {
                            let at = rr * boardSize + cc
                            if board[at] == 0 { seen[at] = true }
                        }
                    }
                }
            }
            if occupied == 0 { return [capacity / 2] }
            return (0..<capacity).filter { seen[$0] }
        }

        private mutating func immediateWins(side: UInt8, among positions: [Int]) -> [Int] {
            // Exact same five-completion semantics; use O(1) per candidate.
            if let r13Index {
                return positions.filter { index in
                    (0..<capacity).contains(index) && board[index] == 0 &&
                    r13Index.winsImmediately(stone: side, at: index)
                }
            }
            var out: [Int] = []
            for i in positions where board[i] == 0 {
                place(i, side)
                let win = winningStone(at: i, side: side)
                unplace(i, side)
                if win { out.append(i) }
            }
            return out
        }

        /// Finds opponent fork cells by collecting two DISTINCT five-completion
        /// points after a hypothetical opponent move. Exact for freestyle rules.
        private func forkCells(for side: UInt8) -> [Int] {
            // Exact cached counts plus existing completions, not a heuristic.
            if let r13Index { return r13Index.forkSquares(stone: side) }
            var replies = [Int: Set<Int>]()
            for (dr, dc) in directions {
                for r in 0..<boardSize {
                    for c in 0..<boardSize {
                        let endR = r + dr * 4, endC = c + dc * 4
                        if !valid(endR, endC) { continue }
                        var own = 0
                        var spaces: [Int] = []
                        var blocked = false
                        for k in 0..<5 {
                            let i = (r + dr * k) * boardSize + c + dc * k
                            if board[i] == side { own += 1 }
                            else if board[i] == 0 { spaces.append(i) }
                            else { blocked = true; break }
                        }
                        if !blocked && own == 3 && spaces.count == 2 {
                            replies[spaces[0], default: []].insert(spaces[1])
                            replies[spaces[1], default: []].insert(spaces[0])
                        }
                    }
                }
            }
            return replies.filter { $0.value.count >= 2 }.map(\.key).sorted()
        }

        private func patternPriority(_ idx: Int, _ side: UInt8) -> Int {
            // Stable ordering heuristic: count adjacent own/other stones within
            // two squares, with stronger preference for extending unblocked runs.
            let r = idx / boardSize, c = idx % boardSize
            var score = 0
            for (dr, dc) in directions {
                for sign in [-1, 1] {
                    for distance in 1...2 {
                        let rr = r + sign * distance * dr, cc = c + sign * distance * dc
                        guard valid(rr, cc) else { continue }
                        let value = board[rr * boardSize + cc]
                        if value == side { score += distance == 1 ? 18 : 5 }
                        else if value == opponent(side) { score += distance == 1 ? 12 : 3 }
                    }
                }
            }
            let centerBias = boardSize - abs(r - 7) - abs(c - 7)
            return score * 8 + centerBias
        }

        /// Score once per legal candidate, outside the sort comparator.
        /// The learned policy orders the SAME bounded search and never votes
        /// on legality, proof certificates or compulsory win/block gates.
        private func orderingScore(_ index: Int, _ side: UInt8) -> Int {
            trainedPolicy
                ? EclipseTrainedOrdering.score(cells: board, index: index, side: side)
                : patternPriority(index, side)
        }

        private func ordered(_ candidates: [Int], side: UInt8, previousBest: Int? = nil, top: Int) -> [Int] {
            let scored = candidates.map { ($0, orderingScore($0, side)) }
            return scored.sorted { a, b in
                if a.0 == b.0 { return false }
                if a.0 == previousBest { return true }
                if b.0 == previousBest { return false }
                return a.1 == b.1 ? a.0 < b.0 : a.1 > b.1
            }.prefix(max(1, top)).map { $0.0 }
        }

        private func staticValue(toMove side: UInt8) -> Int {
            // Enumerate five-cell windows exactly once. This is a positional
            // heuristic, not a claim of mathematically proven winning status.
            var blackScore = 0, whiteScore = 0
            let weight = [0, 2, 28, 900, 45_000, 900_000]
            for (dr, dc) in directions {
                for r in 0..<boardSize {
                    for c in 0..<boardSize {
                        if !valid(r + 4 * dr, c + 4 * dc) { continue }
                        var b = 0, w = 0
                        for k in 0..<5 {
                            let i = (r + k * dr) * boardSize + c + k * dc
                            if board[i] == 1 { b += 1 }
                            else if board[i] == 2 { w += 1 }
                        }
                        if w == 0 { blackScore += weight[b] }
                        if b == 0 { whiteScore += weight[w] }
                    }
                }
            }
            return side == 1 ? blackScore - whiteScore : whiteScore - blackScore
        }

        private mutating func overBudget() -> Bool {
            if nodes >= max(1, limits.maxNodes) {
                interrupted = true
                return true
            }
            if Date.timeIntervalSinceReferenceDate - started >= Double(max(1, limits.maxMilliseconds)) / 1000 {
                interrupted = true
                return true
            }
            return false
        }

        /// A conservative forcing-four proof. Defender must answer the unique
        /// completion; if defender can win immediately, the line is rejected.
        private mutating func proveFour(side: UInt8, remaining: Int, firstAllowed: Set<Int>?, pv: inout [Int]) -> Bool {
            nodes += 1
            // Reserve at least 70% of the wall budget for ordinary PVS.
            // Missing a VCF proof is acceptable; a false proof is not.
            if Date.timeIntervalSinceReferenceDate - started >
                Double(max(1, limits.maxMilliseconds)) * 0.30 / 1000 { return false }
            if overBudget() || remaining <= 0 { return false }
            let opponentSide = opponent(side)
            let all = neighbors(radius: limits.candidateRadius)
            if !immediateWins(side: opponentSide, among: all).isEmpty { return false }
            let already = immediateWins(side: side, among: all)
            if !already.isEmpty {
                if firstAllowed == nil || firstAllowed!.contains(already[0]) {
                    pv = [already[0]]
                    return true
                }
            }
            for move in ordered(all, side: side, top: 28) {
                if let firstAllowed, !firstAllowed.contains(move) { continue }
                place(move, side)
                let candidatesAfter = neighbors(radius: limits.candidateRadius)
                let replies = immediateWins(side: side, among: candidatesAfter)
                let opposingWin = !immediateWins(side: opponentSide, among: candidatesAfter).isEmpty
                if !opposingWin && replies.count >= 2 {
                    pv = [move, replies[0]]
                    unplace(move, side)
                    return true
                }
                if !opposingWin && replies.count == 1 && remaining > 1 {
                    let defense = replies[0]
                    place(defense, opponentSide)
                    var continuation: [Int] = []
                    let valid = proveFour(side: side, remaining: remaining - 1,
                                          firstAllowed: nil, pv: &continuation)
                    unplace(defense, opponentSide)
                    if valid {
                        pv = [move, defense] + continuation
                        unplace(move, side)
                        return true
                    }
                }
                unplace(move, side)
                if interrupted { return false }
            }
            return false
        }

        /// Bounded leaf threat extension. A quiet/static leaf is not called a
        /// win. Every forced defense updates the board and search ply, then
        /// restores it. The same global node and time ceilings still apply.
        private mutating func r12TacticalLeaf(
            toMove side: UInt8, ply: Int, remainingForcedBlocks: Int,
            variation: inout [Int]
        ) -> Int {
            nodes += 1
            if overBudget() { return 0 }
            guard let probe = EclipseHorizonQuiescenceR12.inspect(board, toMove: side) else {
                return staticValue(toMove: side)
            }
            if overBudget() { return 0 }
            switch probe {
            case .ownImmediateWin(let finish):
                variation = [finish]
                return mate - ply - 1
            case .opponentDoubleFive:
                // Two DISTINCT immediate completions cannot both be blocked.
                return -mate + ply + 2
            case .forcedBlock(let required):
                place(required, side)
                var continuation: [Int] = []
                let score: Int
                if remainingForcedBlocks > 1 {
                    score = -r12TacticalLeaf(
                        toMove: opponent(side), ply: ply + 1,
                        remainingForcedBlocks: remainingForcedBlocks - 1,
                        variation: &continuation
                    )
                } else {
                    // Evaluation after, never before, the only legal block.
                    score = -staticValue(toMove: opponent(side))
                }
                unplace(required, side)
                if interrupted || overBudget() { return 0 }
                variation = [required] + continuation
                return score
            case .quiet:
                return staticValue(toMove: side)
            }
        }

        private mutating func negamax(depth: Int, alpha: Int, beta: Int,
                                       toMove side: UInt8, last: Int, ply: Int,
                                       variation: inout [Int]) -> Int {
            nodes += 1
            if overBudget() { return 0 }
            if last >= 0 && winningStone(at: last, side: opponent(side)) { return -mate + ply }
            if !board.contains(0) { return staticValue(toMove: side) }
            if depth == 0 {
                guard limits.r12HorizonQuiescence else {
                    return staticValue(toMove: side)
                }
                return r12TacticalLeaf(
                    toMove: side, ply: ply,
                    remainingForcedBlocks: min(3, max(1, limits.r12MaxForcedBlocks)),
                    variation: &variation
                )
            }
            let tableKey = hash ^ VeilGomokuUnifiedSearch.sideHash[Int(side)]
            let oldAlpha = alpha
            if let hit = table[tableKey], hit.depth >= depth {
                if hit.flag == 0 {
                    // A TT hit contains the chosen first move, not a replayed
                    // complete line. Never invent missing continuation moves.
                    variation = [hit.best]
                    return hit.score
                }
                if hit.flag == 1 && hit.score >= beta { return hit.score }
                if hit.flag == 2 && hit.score <= alpha { return hit.score }
            }
            var moves = neighbors(radius: limits.candidateRadius)
            let wins = immediateWins(side: side, among: moves)
            if let first = wins.first { variation = [first]; return mate - ply - 1 }
            let blocks = immediateWins(side: opponent(side), among: moves)
            if blocks.count > 1 { return -mate + ply + 2 }
            if let block = blocks.first { moves = [block] }
            let pref = table[tableKey]?.best
            moves = ordered(moves, side: side, previousBest: pref, top: limits.width)
            var best = -infinity
            var bestMove = -1
            var bestLine: [Int] = []
            var lower = alpha
            var first = true
            for i in moves {
                place(i, side)
                exploredPath.append(i)
                if exploredPath.count <= 3 { onExploredLine?(exploredPath, nodes) }
                var child: [Int] = []
                var score: Int
                if first {
                    score = -negamax(depth: depth - 1, alpha: -beta, beta: -lower,
                                     toMove: opponent(side), last: i, ply: ply + 1,
                                     variation: &child)
                } else {
                    score = -negamax(depth: depth - 1, alpha: -lower - 1, beta: -lower,
                                     toMove: opponent(side), last: i, ply: ply + 1,
                                     variation: &child)
                    if !interrupted && score > lower && score < beta {
                        child.removeAll()
                        score = -negamax(depth: depth - 1, alpha: -beta, beta: -lower,
                                         toMove: opponent(side), last: i, ply: ply + 1,
                                         variation: &child)
                    }
                }
                unplace(i, side)
                exploredPath.removeLast()
                if interrupted { return 0 }
                if score > best {
                    best = score
                    bestMove = i
                    bestLine = [i] + child
                }
                if best > lower { lower = best }
                if lower >= beta { break }
                first = false
            }
            variation = bestLine
            if bestMove >= 0 && abs(best) < mate / 2 {
                // Mate distance depends on search ply. Avoid caching these
                // ply-relative values without explicit normalization.
                if table.count > 50_000 { table.removeAll(keepingCapacity: true) }
                table[tableKey] = Entry(depth: depth, score: best,
                                        flag: best <= oldAlpha ? 2 : best >= beta ? 1 : 0,
                                        best: bestMove)
            }
            return best == -infinity ? staticValue(toMove: side) : best
        }

        mutating func run() -> Decision? {
            let all = neighbors(radius: limits.candidateRadius)
            let roots = all.filter { allowed == nil || allowed!.contains($0) }
            guard !roots.isEmpty else { return nil }
            trace?(Trace(phase: .validating, completedDepth: 0, nodes: nodes,
                         rootCandidates: roots.count, selectedIndex: nil, score: nil,
                         variation: [], rule: "checking forced moves"))
            let own = immediateWins(side: player, among: roots)
            if let win = own.first { return conclude(win, score: mate, depth: 1, pv: [win], rule: "immediate-win", roots: roots.count) }
            let opponentWins = immediateWins(side: opponent(player), among: all)
            if let forced = opponentWins.first {
                if roots.contains(forced) {
                    return conclude(forced, score: opponentWins.count > 1 ? -mate : mate / 2,
                                    depth: 1, pv: [forced], rule: "mandatory-block", roots: roots.count)
                }
                // The allowed-root policy may not bypass the necessary block.
                return nil
            }
            // Counterattack is valid only with TWO different completion cells
            // AND no immediate opponent five. This check precedes fork veto,
            // because an immediate double win can outrun an opponent's fork.
            for index in roots {
                place(index, player)
                let after = neighbors(radius: limits.candidateRadius)
                let ownFinishes = immediateWins(side: player, among: after)
                let instantOpponentWin = immediateWins(side: opponent(player), among: after)
                unplace(index, player)
                if ownFinishes.count >= 2 && instantOpponentWin.isEmpty {
                    return conclude(index, score: mate - 2, depth: 2,
                                    pv: [index, ownFinishes[0]], rule: "double-completion-win",
                                    roots: roots.count)
                }
            }
            // Reject moves allowing the opponent to create a fork on its next
            // turn whenever any candidate prevents all such forks.
            var safe: [Int] = []
            var risk: [(Int, Int)] = []
            for i in roots {
                place(i, player)
                let forks = forkCells(for: opponent(player)).count
                unplace(i, player)
                if forks == 0 { safe.append(i) }
                risk.append((i, forks))
            }
            let eligible = safe.isEmpty ? risk.sorted { $0.1 < $1.1 }.map(\.0) : safe
            guard let fallback = ordered(eligible, side: player, top: eligible.count).first else { return nil }
            trace?(Trace(phase: .forcedLine, completedDepth: 0, nodes: nodes,
                         rootCandidates: eligible.count, selectedIndex: nil, score: nil,
                         variation: [], rule: safe.isEmpty ? "no proven fork-free root" : "root fork safety verified"))
            var vcf: [Int] = []
            if limits.forcedLineDepth > 0 && proveFour(side: player,
                 remaining: min(8, limits.forcedLineDepth), firstAllowed: Set(eligible), pv: &vcf),
               let first = vcf.first {
                return conclude(first, score: mate - vcf.count, depth: vcf.count,
                                pv: vcf, rule: "verified-forcing-four", roots: eligible.count)
            }
            // A proof search that ran out of time must not be labeled a win.
            interrupted = false
            let rootOrdering = eligible.map {
                ($0, orderingScore($0, player) + min(2000, max(-2000, bonuses[$0] ?? 0)))
            }
            let sorted = rootOrdering.sorted { a, b in
                a.1 == b.1 ? a.0 < b.0 : a.1 > b.1
            }.prefix(max(1, min(eligible.count, limits.width))).map { $0.0 }
            var lastDecision = Decision(index: fallback, score: 0, completedDepth: 0,
                                        nodes: nodes, variation: [fallback], rule: "safe-fallback")
            for depth in 1...max(1, min(12, limits.maxDepth)) {
                interrupted = false
                var best = -infinity
                var bestPV: [Int] = []
                // Root preference is a post-evaluation offset. Use a full
                // window for each root so PVS bounds never mix score scales.
                // Internal nodes retain principal-variation/null-window search.
                for move in sorted {
                    nodes += 1
                    if overBudget() { break }
                    place(move, player)
                    exploredPath = [move]
                    onExploredLine?(exploredPath, nodes)
                    var childPV: [Int] = []
                    let value = -negamax(depth: depth - 1, alpha: -infinity,
                                          beta: infinity,
                                          toMove: opponent(player), last: move,
                                          ply: 1, variation: &childPV)
                    unplace(move, player)
                    exploredPath.removeAll(keepingCapacity: true)
                    if interrupted { break }
                    let preference = min(2_000, max(-2_000, bonuses[move] ?? 0))
                    let adjusted = abs(value) >= mate / 2 ? value : value + preference
                    if adjusted > best {
                        best = adjusted
                        bestPV = [move] + childPV
                    }
                }
                if interrupted { break }
                if let index = bestPV.first {
                    lastDecision = Decision(index: index, score: best,
                        completedDepth: depth, nodes: nodes, variation: bestPV,
                        rule: "iterative-pvs")
                    trace?(Trace(phase: .deepening, completedDepth: depth,
                         nodes: nodes, rootCandidates: sorted.count,
                         selectedIndex: index, score: best, variation: bestPV,
                         rule: "completed-depth"))
                    if best >= mate / 2 { break }
                }
            }
            return conclude(lastDecision.index, score: lastDecision.score,
                            depth: lastDecision.completedDepth, pv: lastDecision.variation,
                            rule: lastDecision.rule, roots: eligible.count)
        }

        private func conclude(_ move: Int, score: Int, depth: Int,
                              pv: [Int], rule: String, roots: Int) -> Decision {
            trace?(Trace(phase: .complete, completedDepth: depth, nodes: nodes,
                         rootCandidates: roots, selectedIndex: move, score: score,
                         variation: pv, rule: rule))
            return Decision(index: move, score: score, completedDepth: depth,
                            nodes: nodes, variation: pv, rule: rule)
        }
    }
}
