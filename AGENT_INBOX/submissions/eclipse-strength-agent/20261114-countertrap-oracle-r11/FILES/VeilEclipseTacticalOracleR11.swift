import Foundation

/// ECLIPSE R11 threat oracle for freestyle 15×15 Gomoku.
///
/// Complements R10 / R5 / V9, rather than replacing the incumbent rule gates.
/// Its certificates are narrowly scoped to immediate wins, independent next-turn
/// five-completions and opponent forcing forks. A candidate's ordinary positional
/// value or broader game-theoretic outcome is NOT proved by this module.
/// All returned coordinates remain engine-private throughout an active match.
enum VeilEclipseTacticalOracleR11 {
    static let width = 15
    static let size = 225
    private static let axes: [(Int, Int)] = [(0, 1), (1, 0), (1, 1), (1, -1)]

    enum Classification: String, Sendable {
        case immediateWin
        case forcedTwoTurnWin
        case opponentImmediateWin
        case opponentForkTrap
        case unresolved
    }

    struct RootReport: Sendable {
        let index: Int
        let classification: Classification
        /// A verified tactical counter, not a player-facing hint.
        let privateCounter: Int?
        var isTacticallyLosing: Bool {
            classification == .opponentImmediateWin || classification == .opponentForkTrap
        }
        var isProvenWinning: Bool {
            classification == .immediateWin || classification == .forcedTwoTurnWin
        }
    }

    struct Audit: Sendable {
        let reports: [RootReport]
        let examinedWindows: Int
        /// If at least one non-losing root exists, exclude only roots with
        /// a verifiable short tactical loss. Otherwise leave incumbent roots
        /// unchanged: the oracle cannot fabricate a saving move.
        var filteredRoots: [Int] {
            let retained = reports.filter { !$0.isTacticallyLosing }.map(\.index)
            return retained.isEmpty ? reports.map(\.index) : retained
        }
        var certifiedWins: [Int] {
            reports.filter(\.isProvenWinning).map(\.index)
        }
    }

    /// Returns nil on partial examination. The caller must then keep the
    /// original vetted roots and incumbent R10/R5/V9 decision.
    static func audit(
        position: VeilEclipseStrategicPlannerR10.Position,
        vettedRoots: [Int],
        deadline: TimeInterval,
        windowCap: Int = 240_000
    ) -> Audit? {
        guard windowCap > 0, Date.timeIntervalSinceReferenceDate < deadline else { return nil }
        let player = position.toMove
        let opponent: UInt8 = player == 1 ? 2 : 1
        let board = position.cells
        let roots = Array(Set(vettedRoots.filter {
            (0..<size).contains($0) && board[$0] == 0
        })).sorted()
        guard !roots.isEmpty else { return nil }
        var windows = 0
        var reports: [RootReport] = []
        reports.reserveCapacity(roots.count)
        for root in roots {
            guard windows < windowCap, Date.timeIntervalSinceReferenceDate < deadline else { return nil }
            var after = board
            after[root] = player
            windows += 1

            if createsFive(after, index: root, player: player) {
                reports.append(.init(index: root, classification: .immediateWin, privateCounter: nil))
                continue
            }

            let enemyFives = winningCells(after, player: opponent)
            windows += size
            if let winningCounter = enemyFives.first {
                reports.append(.init(index: root, classification: .opponentImmediateWin,
                                     privateCounter: winningCounter))
                continue
            }

            let ownFives = winningCells(after, player: player)
            windows += size
            if ownFives.count >= 2 {
                reports.append(.init(index: root, classification: .forcedTwoTurnWin,
                                     privateCounter: nil))
                continue
            }

            // Count all distinct winning completions resulting from a possible
            // opponent next move. This scans every five-cell window. No width
            // truncation of defender replies, so the certificate is not a beam
            // heuristic. A reply forming two distinct five completions wins on
            // the following turn UNLESS our side can win immediately first.
            let (forks, inspected) = forkCells(after, player: opponent)
            windows += inspected
            var counter: Int?
            for fork in forks {
                windows += 1
                // The opponent fills one empty square; every other existing
                // immediate win for us stays available. If we can win, the
                // fork is not a valid opponent win-in-two certificate.
                guard !ownFives.contains(where: { $0 != fork }) else { continue }
                counter = fork
                break
            }
            reports.append(.init(index: root,
                                 classification: counter == nil ? .unresolved : .opponentForkTrap,
                                 privateCounter: counter))
            // Never return a partial set of classifications after budget ends.
            guard windows <= windowCap, Date.timeIntervalSinceReferenceDate < deadline else { return nil }
        }
        return Audit(reports: reports, examinedWindows: windows)
    }

    private static func createsFive(_ board: [UInt8], index: Int, player: UInt8) -> Bool {
        let row = index / width, col = index % width
        for (dr, dc) in axes {
            var n = 1
            for sign in [-1, 1] {
                var r = row + dr * sign, c = col + dc * sign
                while (0..<width).contains(r), (0..<width).contains(c),
                      board[r * width + c] == player {
                    n += 1
                    r += dr * sign
                    c += dc * sign
                }
            }
            if n >= 5 { return true }
        }
        return false
    }

    private static func winningCells(_ board: [UInt8], player: UInt8) -> [Int] {
        var scratch = board
        var wins: [Int] = []
        for index in 0..<size where board[index] == 0 {
            scratch[index] = player
            if createsFive(scratch, index: index, player: player) { wins.append(index) }
            scratch[index] = 0
        }
        return wins
    }

    /// A next-turn fork cell is proved only by TWO DIFFERENT five-completion
    /// endpoints, never by two overlapping windows mentioning the same endpoint.
    private static func forkCells(_ board: [UInt8], player: UInt8) -> ([Int], Int) {
        var endpoints: [Int: Set<Int>] = [:]
        var inspected = 0
        for (dr, dc) in axes {
            for row in 0..<width {
                for col in 0..<width {
                    let rEnd = row + dr * 4, cEnd = col + dc * 4
                    guard (0..<width).contains(rEnd), (0..<width).contains(cEnd) else { continue }
                    inspected += 1
                    var count = 0, holes: [Int] = [], blocked = false
                    for delta in 0..<5 {
                        let index = (row + dr * delta) * width + col + dc * delta
                        let stone = board[index]
                        if stone == player { count += 1 }
                        else if stone == 0 { holes.append(index) }
                        else { blocked = true; break }
                    }
                    guard !blocked && count == 3 && holes.count == 2 else { continue }
                    endpoints[holes[0], default: []].insert(holes[1])
                    endpoints[holes[1], default: []].insert(holes[0])
                }
            }
        }
        return (endpoints.filter { $0.value.count >= 2 }.map(\.key).sorted(), inspected)
    }
}
