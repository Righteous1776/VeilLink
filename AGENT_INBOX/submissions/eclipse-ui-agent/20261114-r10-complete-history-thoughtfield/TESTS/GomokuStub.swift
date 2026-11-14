import Foundation

/// Only a lightweight 15x15 legality stub for isolated Linux tests.
/// DO NOT add this file to the production iOS target: use real GomokuState there.
enum MiniGamePlayer: Sendable {
    case host, guest
    var opponent: Self { self == .host ? .guest : .host }
}
struct GomokuState: Sendable {
    let boardSize = 15
    private(set) var values: [Int8] = Array(repeating: 0, count: 225)
    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var winner: MiniGamePlayer?
    private(set) var moveCount = 0
    var isDraw: Bool { moveCount == 225 && winner == nil }
    mutating func apply(index: Int, actor: MiniGamePlayer) -> Bool {
        guard winner == nil, actor == currentPlayer,
              (0..<225).contains(index), values[index] == 0 else { return false }
        values[index] = actor == .host ? 1 : 2
        moveCount += 1
        if moveCount < 225 { currentPlayer = actor.opponent }
        return true
    }
}
