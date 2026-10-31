import Foundation

/// Observed geometric style, not a guarantee of strategic invulnerability.
/// Index is row-major on a 15x15 board; a chess-knight displacement is (1,2).
struct VeilBaguaEvidence: Equatable, Sendable {
    let moves: Int
    let transitions: Int
    let knightTransitions: Int

    var ratio: Double {
        transitions > 0 ? Double(knightTransitions) / Double(transitions) : 0
    }

    /// Conservative style hint only. A threat-search result always outranks it.
    var isCandidate: Bool {
        transitions >= 10 && knightTransitions >= 4 && ratio >= 0.25
    }
}

enum VeilBaguaFormation {
    static func isKnightMove(from: Int, to: Int, boardSize: Int = 15) -> Bool {
        guard boardSize > 2, (0..<(boardSize * boardSize)).contains(from),
              (0..<(boardSize * boardSize)).contains(to) else { return false }
        let dr = abs(from / boardSize - to / boardSize)
        let dc = abs(from % boardSize - to % boardSize)
        return (dr == 1 && dc == 2) || (dr == 2 && dc == 1)
    }

    static func analyze(games: [[String]], actor: Character = "h", boardSize: Int = 15) -> VeilBaguaEvidence {
        var moves = 0
        var transitions = 0
        var knight = 0
        for actions in games {
            let indices: [Int] = actions.compactMap { action in
                guard action.first == actor,
                      let index = Int(action.dropFirst()),
                      (0..<(boardSize * boardSize)).contains(index) else { return nil }
                return index
            }
            moves += indices.count
            for pair in zip(indices, indices.dropFirst()) {
                transitions += 1
                if isKnightMove(from: pair.0, to: pair.1, boardSize: boardSize) {
                    knight += 1
                }
            }
        }
        return VeilBaguaEvidence(moves: moves, transitions: transitions, knightTransitions: knight)
    }
}
