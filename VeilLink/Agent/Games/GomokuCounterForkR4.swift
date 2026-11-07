import Foundation

/// R4: exact Gomoku fork-safety gate plus seven-feature R4 learned ordering.
/// The small linear policy was fitted to 2,484 genuine, independently
/// replayed VeilLink positions. Its coefficients never replace rule checks.
/// No network, external model, database migration or writable global state.
enum GomokuCounterForkR4 {
    private static let size = GomokuState.size
    private static let axes = [(0, 1), (1, 0), (1, 1), (1, -1)]

    /// Count empty cells where the opponent could move NEXT to create at
    /// least two distinct, immediately winning replies one move later.
    /// If virtualBlock is nonnegative, that empty cell is treated as having
    /// been occupied by us, without copying or mutating the board.
    ///
    /// Fixed working memory: two 225-cell arrays (~675 bytes + headers).
    /// A bounded 15*15*4*5 scan; no search-tree expansion.
    static func forkCellCount(
        in board: GomokuState,
        opponent: MiniGamePlayer,
        virtualBlock: Int = -1
    ) -> Int {
        let stone: Int8 = opponent == .host ? 1 : 2
        let capacity = size * size
        var firstReply = [Int16](repeating: -1, count: capacity)
        var hasFork = [Bool](repeating: false, count: capacity)
        var forks = 0

        for row in 0..<size {
            for column in 0..<size {
                for (dr, dc) in axes {
                    let endRow = row + 4 * dr
                    let endCol = column + 4 * dc
                    guard (0..<size).contains(endRow),
                          (0..<size).contains(endCol) else { continue }
                    var enemy = 0
                    var emptyA = -1, emptyB = -1
                    var blocked = false
                    for offset in 0..<5 {
                        let index = (row + offset * dr) * size + column + offset * dc
                        if index == virtualBlock {
                            blocked = true
                            break
                        }
                        let value = board.value(at: index)
                        if value == stone {
                            enemy += 1
                        } else if value == 0 {
                            if emptyA < 0 { emptyA = index }
                            else if emptyB < 0 { emptyB = index }
                        } else {
                            blocked = true
                            break
                        }
                    }
                    guard !blocked, enemy == 3, emptyA >= 0, emptyB >= 0 else {
                        continue
                    }
                    // A legal next move at emptyA creates a five-in-one
                    // continuation at emptyB, and vice versa. A fork exists
                    // only if one chosen square admits at least TWO DISTINCT
                    // winning-reply squares, not duplicate window evidence.
                    if firstReply[emptyA] < 0 {
                        firstReply[emptyA] = Int16(emptyB)
                    } else if firstReply[emptyA] != Int16(emptyB), !hasFork[emptyA] {
                        hasFork[emptyA] = true
                        forks += 1
                    }
                    if firstReply[emptyB] < 0 {
                        firstReply[emptyB] = Int16(emptyA)
                    } else if firstReply[emptyB] != Int16(emptyA), !hasFork[emptyB] {
                        hasFork[emptyB] = true
                        forks += 1
                    }
                }
            }
        }
        return forks
    }

    /// Called strictly after the native immediate-win and immediate-block
    /// gates. If the opponent has a fork-in-one, keep only moves that remove
    /// ALL such threats when any such move is present. If no complete
    /// defense exists, retain ALL candidates to allow counterattack/search.
    static func safeCandidates(
        in board: GomokuState,
        player: MiniGamePlayer,
        candidates: [Int]
    ) -> (moves: [Int], underThreat: Bool) {
        guard !candidates.isEmpty else { return ([], false) }
        let opponent = player.opponent
        let baseline = forkCellCount(in: board, opponent: opponent)
        guard baseline > 0 else { return (candidates, false) }
        let escapes = candidates.filter {
            forkCellCount(in: board, opponent: opponent, virtualBlock: $0) == 0
        }
        return (escapes.isEmpty ? candidates : escapes, true)
    }

    /// Distilled R4 model. Train-time 14 mirrored tactical features collapse
    /// exactly to seven unique features, saving storage and arithmetic.
    /// Trained to reduce opponent fork options, NOT to predict game result.
    /// Invoked only when the exact threat gate detects an active risk.
    static func trainedDefensiveBonus(
        in board: GomokuState,
        player: MiniGamePlayer,
        index: Int
    ) -> Int {
        guard (0..<(size * size)).contains(index), board.value(at: index) == 0
        else { return 0 }
        let own: Int8 = player == .host ? 1 : 2
        let opponent: Int8 = player == .host ? 2 : 1
        let row = index / size, column = index % size
        var ownThree = 0, oppThree = 0, ownTwo = 0, oppTwo = 0
        for (dr, dc) in axes {
            for shift in 0..<5 {
                let firstRow = row - dr * shift
                let firstCol = column - dc * shift
                let lastRow = firstRow + 4 * dr
                let lastCol = firstCol + 4 * dc
                guard (0..<size).contains(firstRow),
                      (0..<size).contains(firstCol),
                      (0..<size).contains(lastRow),
                      (0..<size).contains(lastCol) else { continue }
                var countOwn = 0, countOpp = 0
                for offset in 0..<5 {
                    let r = firstRow + offset * dr
                    let c = firstCol + offset * dc
                    if r == row && c == column { continue }
                    let stone = board.value(at: r * size + c)
                    if stone == own { countOwn += 1 }
                    else if stone == opponent { countOpp += 1 }
                }
                if countOpp == 0 {
                    if countOwn == 3 { ownThree += 1 }
                    else if countOwn == 2 { ownTwo += 1 }
                }
                if countOwn == 0 {
                    if countOpp == 3 { oppThree += 1 }
                    else if countOpp == 2 { oppTwo += 1 }
                }
            }
        }
        var friends = 0, enemies = 0
        for dr in -1...1 {
            for dc in -1...1 where dr != 0 || dc != 0 {
                let r = row + dr, c = column + dc
                guard (0..<size).contains(r), (0..<size).contains(c) else { continue }
                let value = board.value(at: r * size + c)
                if value == own { friends += 1 }
                else if value == opponent { enemies += 1 }
            }
        }
        let center = Double(14 - abs(row - 7) - abs(column - 7)) / 14.0
        let raw = -0.17198881639659588
            - 0.01325435799882135 * Double(ownThree)
            + 0.8104074675638822 * Double(oppThree)
            + 0.0010736105612463528 * Double(ownTwo)
            - 0.01033982399203205 * Double(oppTwo)
            - 0.006746374984911827 * Double(friends)
            - 0.02001955212897536 * Double(enemies)
            + 0.007056044570294954 * center
        return Int(max(-48_000.0, min(48_000.0, raw * 15_000.0)))
    }
}
