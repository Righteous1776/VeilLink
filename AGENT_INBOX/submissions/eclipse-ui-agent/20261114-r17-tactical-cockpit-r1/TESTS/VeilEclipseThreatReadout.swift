import Foundation
enum VeilEclipseThreatReadout {
    static func instantWins(on state: GomokuState, for player: MiniGamePlayer) -> Int {
        let own: Int8 = player == .host ? 1 : 2
        var threats = 0
        let directions: [(Int, Int)] = [(1, 0), (0, 1), (1, 1), (1, -1)]
        for index in 0..<(GomokuState.size * GomokuState.size) where state.value(at: index) == 0 {
            let row = index / GomokuState.size
            let col = index % GomokuState.size
            var qualifies = false
            for (dr, dc) in directions {
                var count = 1
                for sign in [-1, 1] {
                    var r = row + dr * sign, c = col + dc * sign
                    while (0..<GomokuState.size).contains(r), (0..<GomokuState.size).contains(c),
                          state.value(at: r * GomokuState.size + c) == own {
                        count += 1
                        r += dr * sign; c += dc * sign
                    }
                }
                if count >= 5 { qualifies = true; break }
            }
            if qualifies { threats += 1 }
        }
        return threats
    }
}
