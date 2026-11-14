import Foundation

// Linux-only, source-faithful GomokuState stub. NOT for inclusion in the app.
enum MiniGamePlayer: String {
    case host, guest
    var opponent: Self { self == .host ? .guest : .host }
}
struct GomokuState {
    static let size = 15
    private(set) var board: [Int8] = Array(repeating: 0, count: 225)
    private(set) var winner: MiniGamePlayer?
    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var moveCount = 0
    var isDraw: Bool { moveCount == 225 && winner == nil }
    func value(at index: Int) -> Int8 {
        board.indices.contains(index) ? board[index] : 0
    }
    mutating func apply(index: Int, actor: MiniGamePlayer) -> Bool {
        guard winner == nil, currentPlayer == actor, board.indices.contains(index),
              board[index] == 0 else { return false }
        board[index] = actor == .host ? 1 : 2
        moveCount += 1
        let row = index / 15, col = index % 15
        for (dr, dc) in [(1,0), (0,1), (1,1), (1,-1)] {
            var count = 1
            for sign in [-1, 1] {
                var r = row + dr * sign, c = col + dc * sign
                while (0..<15).contains(r), (0..<15).contains(c),
                      board[r*15+c] == board[index] {
                    count += 1
                    r += dr * sign
                    c += dc * sign
                }
            }
            if count >= 5 { winner = actor; return true }
        }
        currentPlayer = actor.opponent
        return true
    }
}
