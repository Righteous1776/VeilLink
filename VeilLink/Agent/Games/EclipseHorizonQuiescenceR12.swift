import Foundation

/// ECLIPSE R12: bounded, exhaustive immediate-five classification for a
/// freestyle 15x15 Gomoku PVS leaf. The trained 48-tree move ordering remains
/// unchanged. Exact winning-completion detection is a *rule* check, not a new
/// fitted model or a claim about general forced wins.
///
/// The caller must supply a valid, nonterminal board and authentic side to move.
/// Intended as a gated replacement for `depth == 0 -> staticValue` only.
enum EclipseHorizonQuiescenceR12 {
    static let size = 15
    static let capacity = 225
    private static let axes = [(0, 1), (1, 0), (1, 1), (1, -1)]

    /// The searcher may only treat `ownImmediateWin` and `opponentDoubleFive`
    /// as proven short results. `forcedBlock` requires an additional quiet
    /// evaluation after applying the unique legal block; no mate is assumed.
    enum Probe: Equatable, Sendable {
        case ownImmediateWin(Int)
        case opponentDoubleFive([Int])
        case forcedBlock(Int)
        case quiet
    }

    /// Exhaustive over all 572 five-cell windows. Every exact completion
    /// point is deduplicated so overlapping windows cannot fake two threats.
    /// Passing invalid content yields nil; callers retain their old baseline.
    static func inspect(_ cells: [UInt8], toMove: UInt8) -> Probe? {
        guard cells.count == capacity, toMove == 1 || toMove == 2,
              cells.allSatisfy({ $0 <= 2 }) else { return nil }
        var own: Set<Int> = []
        var enemy: Set<Int> = []
        for (dr, dc) in axes {
            for row in 0..<size {
                for col in 0..<size {
                    let rLast = row + dr * 4, cLast = col + dc * 4
                    guard (0..<size).contains(rLast), (0..<size).contains(cLast) else { continue }
                    var one = 0, two = 0, hole = -1
                    for step in 0..<5 {
                        let index = (row + dr * step) * size + col + dc * step
                        switch cells[index] {
                        case 1: one += 1
                        case 2: two += 1
                        default: hole = index
                        }
                    }
                    if one == 4 && two == 0 && hole >= 0 {
                        if toMove == 1 { own.insert(hole) } else { enemy.insert(hole) }
                    }
                    if two == 4 && one == 0 && hole >= 0 {
                        if toMove == 2 { own.insert(hole) } else { enemy.insert(hole) }
                    }
                }
            }
        }
        // The side to move wins *before* an opponent's existing threat.
        if let win = own.min() { return .ownImmediateWin(win) }
        let threats = enemy.sorted()
        if threats.count >= 2 { return .opponentDoubleFive(threats) }
        if let block = threats.first { return .forcedBlock(block) }
        return .quiet
    }

    /// A purely tactical win/forced-loss score; no false certificate for quiet
    /// or unique-block positions. Relative to side to move and search ply.
    static func certifiedScore(_ probe: Probe, mate: Int, ply: Int) -> Int? {
        guard mate > 100, ply >= 0 else { return nil }
        switch probe {
        case .ownImmediateWin: return mate - ply - 1
        case .opponentDoubleFive: return -mate + ply + 2
        case .forcedBlock, .quiet: return nil
        }
    }
}
