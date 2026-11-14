import Foundation
enum MiniGamePlayer: String, Codable, Hashable, Sendable {
    case host
    case guest


    var opponent: MiniGamePlayer { self == .host ? .guest : .host }


    var shortTitle: String { self == .host ? "主方" : "客方" }
}


enum MiniGameSessionStatus: Equatable {
    case invited
    case active
    case declined
    case cancelled
    case finished(winner: MiniGamePlayer?)
}


struct GomokuState: Equatable, Sendable {
    static let size = 15
    private(set) var board: [Int8] = Array(repeating: 0, count: size * size)
    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var winner: MiniGamePlayer?
    private(set) var moveCount = 0
    private(set) var lastMove: Int?


    var isDraw: Bool { winner == nil && moveCount == Self.size * Self.size }


    var winningLine: [Int] {
        guard let lastMove, winner != nil else { return [] }
        let value = board[lastMove]
        let row = lastMove / Self.size
        let col = lastMove % Self.size
        for (dr, dc) in [(1, 0), (0, 1), (1, 1), (1, -1)] {
            var points = [(row, col)]
            var r = row + dr
            var c = col + dc
            while (0..<Self.size).contains(r), (0..<Self.size).contains(c), board[r * Self.size + c] == value {
                points.append((r, c)); r += dr; c += dc
            }
            r = row - dr; c = col - dc
            while (0..<Self.size).contains(r), (0..<Self.size).contains(c), board[r * Self.size + c] == value {
                points.insert((r, c), at: 0); r -= dr; c -= dc
            }
            if points.count >= 5 { return points.map { $0.0 * Self.size + $0.1 } }
        }
        return []
    }


    func value(at index: Int) -> Int8 {
        guard board.indices.contains(index) else { return 0 }
        return board[index]
    }


    mutating func apply(index: Int, actor: MiniGamePlayer) -> Bool {
        guard winner == nil,
              actor == currentPlayer,
              board.indices.contains(index),
              board[index] == 0 else { return false }
        board[index] = actor == .host ? 1 : 2
        lastMove = index
        moveCount += 1
        if hasFive(from: index, value: board[index]) {
            winner = actor
        } else if moveCount < Self.size * Self.size {
            currentPlayer = actor.opponent
        }
        return true
    }


    private func hasFive(from index: Int, value: Int8) -> Bool {
        let row = index / Self.size
        let col = index % Self.size
        let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]
        for (dr, dc) in directions {
            var count = 1
            count += countDirection(row: row, col: col, dr: dr, dc: dc, value: value)
            count += countDirection(row: row, col: col, dr: -dr, dc: -dc, value: value)
            if count >= 5 { return true }
        }
        return false
    }


    private func countDirection(row: Int, col: Int, dr: Int, dc: Int, value: Int8) -> Int {
        var r = row + dr
        var c = col + dc
        var result = 0
        while (0..<Self.size).contains(r), (0..<Self.size).contains(c), board[r * Self.size + c] == value {
            result += 1
            r += dr
            c += dc
        }
        return result
    }
}



