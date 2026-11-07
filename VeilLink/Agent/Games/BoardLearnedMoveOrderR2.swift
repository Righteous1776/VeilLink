import Foundation

/// Offline distilled move-order policy from legally replayed chess games.
/// Model coefficients have bounded influence; rules, forced moves and search
/// evaluation are authoritative. Human learning and self-play remain separate.
enum BoardLearnedMoveOrderR2 {
    static let gomokuModelID = "G-R2-20261107-276-unique"
    static let xiangqiModelID = "X-R2-20261107-371-states"

    // Trained on 115 distinct native guest-winning games and 15,430
    // positive/negative move pairs. Held-out 569 positions: 77.68% imitation
    // versus 75.92% simple static comparator. Neither number is an Elo metric.
    private static let gomokuWeights: [Double] = [
        1.0, 0.7867019839, 0.2892125071, 0.1857073620,
        -0.0307307789, -0.0140620682, 0.0944147225
    ]

    /// Nonforced Gomoku move-order bonus only; never defeats win/block gates.
    /// Features (in training order): own-three, opponent-three, own-two,
    /// opponent-two, friendly-neighbour, enemy-neighbour, center proximity.
    static func gomokuBonus(in state: GomokuState, player: MiniGamePlayer, index: Int) -> Int {
        let n = GomokuState.size
        guard (0..<(n * n)).contains(index), state.value(at: index) == 0 else { return 0 }
        let own: Int8 = player == .host ? 1 : 2
        let opponent: Int8 = player == .host ? 2 : 1
        let row = index / n
        let column = index % n
        var vector = [Double](repeating: 0, count: 7)
        for (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)] {
            for offset in -4...0 {
                var ours = 0
                var theirs = 0
                var valid = true
                for k in 0..<5 {
                    let r = row + (offset + k) * dr
                    let c = column + (offset + k) * dc
                    guard (0..<n).contains(r), (0..<n).contains(c) else {
                        valid = false
                        break
                    }
                    if r == row && c == column { continue }
                    let value = state.value(at: r * n + c)
                    if value == own { ours += 1 }
                    if value == opponent { theirs += 1 }
                }
                if !valid { continue }
                if theirs == 0 {
                    if ours == 3 { vector[0] += 1 }
                    if ours == 2 { vector[2] += 1 }
                }
                if ours == 0 {
                    if theirs == 3 { vector[1] += 1 }
                    if theirs == 2 { vector[3] += 1 }
                }
            }
        }
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let r = row + dr
                let c = column + dc
                if (0..<n).contains(r), (0..<n).contains(c) {
                    let value = state.value(at: r * n + c)
                    if value == own { vector[4] += 1 }
                    if value == opponent { vector[5] += 1 }
                }
            }
        }
        vector[6] = Double(14 - abs(row - 7) - abs(column - 7)) / 14.0
        let score = zip(vector, gomokuWeights).reduce(0.0) { total, pair in
            total + pair.0 * pair.1
        }
        return max(-480, min(480, Int((score * 120.0).rounded())))
    }

    // 371 real Xiangqi states, 12,692 legal candidate moves.
    // Position-held-out check/capture classification AUC=0.672, NOT Elo.
    // May affect move order only, never search evaluation or legality.
    static func xiangqiBonus(in state: XiangqiState, from: Int, to: Int) -> Int {
        guard let piece = state.piece(at: from),
              (0..<(XiangqiState.rows * XiangqiState.columns)).contains(to) else { return 0 }
        let rowDistance = Double(abs(from / 9 - to / 9)) / 9.0
        let center = Double(max(0, 4 - abs(to % 9 - 4))) / 4.0
        let vector = [
            piece.kind == .horse ? 1.0 : 0.0,
            piece.kind == .rook ? 1.0 : 0.0,
            piece.kind == .cannon ? 1.0 : 0.0,
            piece.kind == .soldier ? 1.0 : 0.0,
            center, rowDistance
        ]
        let learned = [
            0.6860736801, 1.2928818584, 1.2116456907,
            0.5703465439, 1.3832336778, 1.0291730883
        ]
        let score = zip(vector, learned).reduce(-1.9790586230) { $0 + $1.0 * $1.1 }
        return max(-60, min(60, Int((score * 24.0).rounded())))
    }
}
