import Foundation

/// Exact five-completion threat classifier for terminal / depth-zero search
/// nodes of 15×15 unrestricted Gomoku. Trained ECLIPSE scores remain intact.
///
/// Input position must be a valid, NONTERMINAL state with `side` to move.
/// This module proves only immediate moves or forced one-square defense.
/// It is not a complete VCT solver and never guesses a human response.
enum EclipseR12LeafThreats {
    enum State: Equatable, Sendable {
        case ownImmediateWin(Int)
        case forcedBlock(Int)
        case unavoidableImmediateLoss([Int])
        case quiet
    }

    /// Returns `quiet` for invalid input; legality is caller-owned.
    static func inspect(cells: [UInt8], side: UInt8) -> State {
        guard cells.count == 225, side == 1 || side == 2,
              cells.allSatisfy({ $0 <= 2 }) else { return .quiet }
        let enemy: UInt8 = side == 1 ? 2 : 1
        // A winning move by the side to move outruns every opponent threat.
        if let own = completionSquares(cells, stone: side).first {
            return .ownImmediateWin(own)
        }
        let enemyWins = completionSquares(cells, stone: enemy)
        switch enemyWins.count {
        case 0: return .quiet
        case 1: return .forcedBlock(enemyWins[0])
        default: return .unavoidableImmediateLoss(enemyWins)
        }
    }

    /// Enumerates each DISTINCT legal square that completes a five-cell line.
    /// For the eight D4 orientations, the returned squares transform exactly.
    static func completionSquares(_ cells: [UInt8], stone: UInt8) -> [Int] {
        guard cells.count == 225, (1...2).contains(stone) else { return [] }
        var found = [Bool](repeating: false, count: 225)
        for (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)] {
            for row in 0..<15 {
                for col in 0..<15 {
                    let endRow = row + dr * 4, endCol = col + dc * 4
                    guard (0..<15).contains(endRow), (0..<15).contains(endCol) else { continue }
                    var own = 0, empty = -1, blocked = false
                    for offset in 0..<5 {
                        let index = (row + dr * offset) * 15 + col + dc * offset
                        switch cells[index] {
                        case stone: own += 1
                        case 0:
                            if empty == -1 { empty = index }
                            else { blocked = true }
                        default: blocked = true
                        }
                        if blocked { break }
                    }
                    if !blocked && own == 4 && empty >= 0 { found[empty] = true }
                }
            }
        }
        return (0..<225).filter { found[$0] }
    }
}
