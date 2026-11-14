import Foundation

/// V9: deterministic, rule-certified forcing-four search for unrestricted 15x15 Gomoku.
/// A result is returned ONLY when every non-losing defender reply is forced.
/// This is a bounded search, not a neural model or a general proof of no win.
enum GomokuForcingSearchV9 {
    struct Proof: Equatable, Sendable {
        let index: Int
        let nodes: Int
    }

    private static let side = GomokuState.size
    private static let axes = [(1, 0), (0, 1), (1, 1), (1, -1)]

    static func provenMove(
        in board: GomokuState,
        for attacker: MiniGamePlayer,
        candidates: [Int],
        maxAttackerMoves: Int,
        nodeCap: Int,
        deadline: TimeInterval
    ) -> Proof? {
        guard board.winner == nil, !board.isDraw,
              board.currentPlayer == attacker, maxAttackerMoves > 0,
              nodeCap > 0 else { return nil }
        var worker = Worker(attacker: attacker, deadline: deadline, cap: nodeCap)
        for index in candidates {
            guard worker.available else { break }
            guard (0..<(side * side)).contains(index), board.value(at: index) == 0 else { continue }
            var next = board
            guard next.apply(index: index, actor: attacker) else { continue }
            worker.nodes += 1
            if next.winner == attacker || worker.provenAfterAttackerMove(next, remaining: maxAttackerMoves - 1) {
                return Proof(index: index, nodes: worker.nodes)
            }
        }
        return nil
    }

    /// Returns geometrically legal immediate-five completions for the requested stone.
    /// This intentionally does not mutate whose turn it is.
    private static func winningCells(_ board: GomokuState, stone: Int8) -> [Int] {
        var result: [Int] = []
        for index in 0..<(side * side) where board.value(at: index) == 0 {
            if makesFive(board, index: index, stone: stone) { result.append(index) }
        }
        return result
    }

    private static func makesFive(_ board: GomokuState, index: Int, stone: Int8) -> Bool {
        let row = index / side, col = index % side
        for (dr, dc) in axes {
            var count = 1
            for sign in [-1, 1] {
                var r = row + dr * sign, c = col + dc * sign
                while (0..<side).contains(r), (0..<side).contains(c),
                      board.value(at: r * side + c) == stone {
                    count += 1
                    r += dr * sign
                    c += dc * sign
                }
            }
            if count >= 5 { return true }
        }
        return false
    }

    /// Only cells near stones can initiate a new forcing four.
    private static func nearbyCells(_ board: GomokuState) -> [Int] {
        var mask = [Bool](repeating: false, count: side * side)
        for occupied in 0..<(side * side) where board.value(at: occupied) != 0 {
            let r = occupied / side, c = occupied % side
            for dr in -2...2 {
                for dc in -2...2 {
                    let nr = r + dr, nc = c + dc
                    guard (0..<side).contains(nr), (0..<side).contains(nc) else { continue }
                    let index = nr * side + nc
                    if board.value(at: index) == 0 { mask[index] = true }
                }
            }
        }
        return mask.indices.filter { mask[$0] }
    }

    private struct Worker {
        let attacker: MiniGamePlayer
        let deadline: TimeInterval
        let cap: Int
        var nodes = 0
        var available: Bool { nodes < cap && Date.timeIntervalSinceReferenceDate < deadline }

        /// The defender can either win immediately, or must occupy the sole
        /// attacker completion. Two distinct attacker completions are a win.
        mutating func provenAfterAttackerMove(_ board: GomokuState, remaining: Int) -> Bool {
            guard available || board.winner == attacker else { return false }
            if board.winner == attacker { return true }
            if board.winner != nil || board.isDraw { return false }
            let attackerStone: Int8 = attacker == .host ? 1 : 2
            let defenderStone: Int8 = attacker == .host ? 2 : 1
            // Defender's own immediate win outranks our next-turn threats.
            if !GomokuForcingSearchV9.winningCells(board, stone: defenderStone).isEmpty {
                return false
            }
            let completions = GomokuForcingSearchV9.winningCells(board, stone: attackerStone)
            if completions.count >= 2 { return true }
            guard completions.count == 1, remaining > 0, available else { return false }
            var forced = board
            guard forced.apply(index: completions[0], actor: attacker.opponent) else { return false }
            nodes += 1
            return provenAtAttackerTurn(forced, remaining: remaining)
        }

        mutating func provenAtAttackerTurn(_ board: GomokuState, remaining: Int) -> Bool {
            guard remaining > 0, available,
                  board.currentPlayer == attacker,
                  board.winner == nil, !board.isDraw else { return false }
            for index in GomokuForcingSearchV9.nearbyCells(board) {
                guard available else { return false }
                var next = board
                guard next.apply(index: index, actor: attacker) else { continue }
                nodes += 1
                if next.winner == attacker || provenAfterAttackerMove(next, remaining: remaining - 1) {
                    return true
                }
            }
            return false
        }
    }
}
