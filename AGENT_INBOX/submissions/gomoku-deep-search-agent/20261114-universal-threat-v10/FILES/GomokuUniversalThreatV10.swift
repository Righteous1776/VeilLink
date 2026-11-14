import Foundation

/// VeilLink V10: a conservative, full-defense proof of a three-attack-turn win.
///
/// V9 proves forcing-four chains where one immediate-five completion forces a
/// unique block. V10 additionally covers selected open-three attacks where the
/// defender may choose ANY legal square. It claims a win only after verifying
/// that every one of those replies still allows a safe double-five fork.
///
/// This module NEVER labels an unexamined candidate "safe" or "winning".
/// A timeout, cancellation, or node-cap exhaustion yields nil (unknown).
/// In an active match, this proof is private engine data: do not expose its
/// coordinates or response lines to ECLIPSE's human-facing UI.
enum GomokuUniversalThreatV10 {
    struct Certificate: Equatable, Sendable {
        let firstMove: Int
        let defenderRepliesChecked: Int
        let workUnitsChecked: Int
        let verifiedBy: String
    }

    private static let cells = GomokuState.size * GomokuState.size
    private static let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]

    /// A sufficient, not necessary, VCT proof under unrestricted Gomoku rules.
    /// The returned root has no immediate five threat; after any opponent move,
    /// the attacker can produce two distinct immediate-five completions while
    /// ensuring the opponent cannot win before either completion is played.
    static func provenThreeTurnOpener(
        in state: GomokuState,
        for attacker: MiniGamePlayer,
        roots: [Int],
        deadline: TimeInterval,
        nodeCap: Int = 10_000
    ) -> Certificate? {
        guard state.currentPlayer == attacker,
              state.winner == nil, !state.isDraw,
              nodeCap > 0, !roots.isEmpty else { return nil }
        var verifier = Verifier(deadline: deadline, cap: nodeCap)
        for root in roots {
            guard verifier.available else { return nil }
            guard (0..<cells).contains(root), state.value(at: root) == 0 else { continue }
            var afterRoot = state
            guard afterRoot.apply(index: root, actor: attacker) else { continue }
            verifier.used += 1
            // Already solved by mandatory own-win and R8/V9 four-threat gates.
            guard afterRoot.winner == nil, !afterRoot.isDraw,
                  !hasImmediateFive(afterRoot, stone: attacker == .host ? 1 : 2)
            else { continue }

            // If the opponent can win right now, its winning move is a legal
            // answer that refutes this opener. There is nothing to enumerate.
            let defender = attacker.opponent
            let enemyStone: Int8 = defender == .host ? 1 : 2
            guard !hasImmediateFive(afterRoot, stone: enemyStone) else { continue }

            // An opponent's added stone can only REMOVE our potential forks,
            // never create one. Therefore it is safe to precompute the full
            // fork-producing root list once and revalidate after each reply.
            var possibleForks: [Int] = []
            for index in 0..<cells where afterRoot.value(at: index) == 0 {
                guard verifier.available else { return nil }
                verifier.used += 1
                if GomokuCounterForkR4.createsForcedDoubleWin(
                    in: afterRoot, player: attacker, virtualPlacement: index
                ) { possibleForks.append(index) }
            }
            guard !possibleForks.isEmpty else { continue }

            var allDefensesCovered = true
            var defenderCount = 0
            for defense in 0..<cells where afterRoot.value(at: defense) == 0 {
                guard verifier.available else { return nil }
                var afterDefense = afterRoot
                guard afterDefense.apply(index: defense, actor: defender) else {
                    allDefensesCovered = false
                    break
                }
                verifier.used += 1
                defenderCount += 1
                if afterDefense.winner == defender || afterDefense.isDraw {
                    allDefensesCovered = false
                    break
                }

                // The defender just played. Its next possible move comes
                // after our fork-producing move. Any existing immediate five
                // must be occupied by our reply; otherwise it beats the fork.
                let defenderWins = winningCells(afterDefense, stone: enemyStone)
                if defenderWins.count > 1 {
                    allDefensesCovered = false
                    break
                }
                var responseWorks = false
                for reply in possibleForks where afterDefense.value(at: reply) == 0 {
                    guard verifier.available else { return nil }
                    verifier.used += 1
                    // A defender immediate five is blocked only when our new
                    // stone occupies its unique winning square.
                    if let mustBlock = defenderWins.first, reply != mustBlock { continue }
                    if GomokuCounterForkR4.createsForcedDoubleWin(
                        in: afterDefense, player: attacker, virtualPlacement: reply
                    ) {
                        responseWorks = true
                        break
                    }
                }
                if !responseWorks {
                    allDefensesCovered = false
                    break
                }
            }
            if allDefensesCovered, defenderCount > 0 {
                guard verifier.available else { return nil }
                return Certificate(
                    firstMove: root,
                    defenderRepliesChecked: defenderCount,
                    workUnitsChecked: verifier.used,
                    verifiedBy: "exhaustive-defender-double-fork"
                )
            }
        }
        return nil
    }

    private struct Verifier {
        let deadline: TimeInterval
        let cap: Int
        var used = 0
        var available: Bool {
            used < cap && Date.timeIntervalSinceReferenceDate < deadline
                && !Task<Never, Never>.isCancelled
        }
    }

    /// Geometry-only hypothetical immediate wins; it does not change turn.
    private static func winningCells(_ board: GomokuState, stone: Int8) -> [Int] {
        var out: [Int] = []
        for index in 0..<cells where board.value(at: index) == 0 {
            if makesFive(board, index: index, stone: stone) { out.append(index) }
        }
        return out
    }

    private static func hasImmediateFive(_ board: GomokuState, stone: Int8) -> Bool {
        for index in 0..<cells where board.value(at: index) == 0 {
            if makesFive(board, index: index, stone: stone) { return true }
        }
        return false
    }

    private static func makesFive(_ board: GomokuState, index: Int, stone: Int8) -> Bool {
        let row = index / GomokuState.size
        let column = index % GomokuState.size
        for (dr, dc) in directions {
            var count = 1
            for sign in [-1, 1] {
                var r = row + dr * sign, c = column + dc * sign
                while (0..<GomokuState.size).contains(r),
                      (0..<GomokuState.size).contains(c),
                      board.value(at: r * GomokuState.size + c) == stone {
                    count += 1
                    r += dr * sign
                    c += dc * sign
                }
            }
            if count >= 5 { return true }
        }
        return false
    }
}
