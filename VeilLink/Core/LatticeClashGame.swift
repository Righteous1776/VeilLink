import Foundation

enum LatticeClashPlayer: UInt8, CaseIterable, Equatable, Sendable {
    case host = 1
    case guest = 2

    var opponent: LatticeClashPlayer {
        self == .host ? .guest : .host
    }
}

enum LatticeClashCell: UInt8, Equatable, Sendable {
    case empty = 0
    case host = 1
    case guest = 2

    init(owner: LatticeClashPlayer) {
        self = owner == .host ? .host : .guest
    }

    var owner: LatticeClashPlayer? {
        switch self {
        case .empty: return nil
        case .host: return .host
        case .guest: return .guest
        }
    }
}

struct LatticeClashMove: Equatable, Sendable {
    let index: Int
}

struct LatticeClashTurnResult: Equatable, Sendable {
    let actor: LatticeClashPlayer
    let move: LatticeClashMove
    let captured: [Int]
    let hostCount: Int
    let guestCount: Int
    let retainedTurn: Bool
}

struct LatticeClashState: Equatable, Sendable {
    static let size = 7
    static let cellCount = size * size
    static let majorityCount = 25
    static let maxTurns = cellCount - 4

    private(set) var board: [LatticeClashCell]
    private(set) var currentPlayer: LatticeClashPlayer
    private(set) var turn: Int
    private(set) var winner: LatticeClashPlayer?
    private(set) var isDraw: Bool
    private(set) var lastMove: Int?
    private(set) var lastTurn: LatticeClashTurnResult?

    init() {
        var board = Array(repeating: LatticeClashCell.empty, count: Self.cellCount)
        board[Self.index(row: 2, column: 0)] = .host
        board[Self.index(row: 4, column: 0)] = .host
        board[Self.index(row: 2, column: 6)] = .guest
        board[Self.index(row: 4, column: 6)] = .guest
        self.init(board: board, currentPlayer: .host)
    }

    init(
        board: [LatticeClashCell],
        currentPlayer: LatticeClashPlayer,
        turn: Int = 0,
        winner: LatticeClashPlayer? = nil,
        isDraw: Bool = false,
        lastMove: Int? = nil,
        lastTurn: LatticeClashTurnResult? = nil
    ) {
        precondition(board.count == Self.cellCount, "Lattice Clash requires a 7x7 board")
        self.board = board
        self.currentPlayer = currentPlayer
        self.turn = max(0, turn)
        self.winner = winner
        self.isDraw = isDraw
        self.lastMove = lastMove
        self.lastTurn = lastTurn
    }

    var isFinished: Bool {
        winner != nil || isDraw
    }

    func cell(at index: Int) -> LatticeClashCell {
        guard (0..<Self.cellCount).contains(index) else { return .empty }
        return board[index]
    }

    func count(for player: LatticeClashPlayer) -> Int {
        board.filter { $0.owner == player }.count
    }

    func legalMoves(for player: LatticeClashPlayer) -> [LatticeClashMove] {
        guard !isFinished else { return [] }
        return rawLegalMoves(for: player)
    }

    func isLegal(move: LatticeClashMove, actor: LatticeClashPlayer) -> Bool {
        guard !isFinished,
              actor == currentPlayer,
              (0..<Self.cellCount).contains(move.index),
              board[move.index] == .empty else {
            return false
        }
        return Self.neighbors(of: move.index).contains { board[$0].owner == actor }
    }

    @discardableResult
    mutating func apply(move: LatticeClashMove, actor: LatticeClashPlayer) -> Bool {
        guard isLegal(move: move, actor: actor) else { return false }

        board[move.index] = LatticeClashCell(owner: actor)
        let captured = resolveCaptures(for: actor)
        turn += 1
        lastMove = move.index

        if count(for: actor) >= Self.majorityCount {
            winner = actor
        } else if turn >= Self.maxTurns || !board.contains(.empty) {
            finishByScore()
        } else {
            let opponent = actor.opponent
            let opponentMoves = rawLegalMoves(for: opponent)
            if !opponentMoves.isEmpty {
                currentPlayer = opponent
            } else if !rawLegalMoves(for: actor).isEmpty {
                currentPlayer = actor
            } else {
                finishByScore()
            }
        }

        lastTurn = LatticeClashTurnResult(
            actor: actor,
            move: move,
            captured: captured,
            hostCount: count(for: .host),
            guestCount: count(for: .guest),
            retainedTurn: !isFinished && currentPlayer == actor
        )
        return true
    }

    private func rawLegalMoves(for player: LatticeClashPlayer) -> [LatticeClashMove] {
        guard count(for: player) > 0 else { return [] }
        var moves: [LatticeClashMove] = []
        moves.reserveCapacity(Self.cellCount)
        for index in 0..<Self.cellCount where board[index] == .empty {
            if Self.neighbors(of: index).contains(where: { board[$0].owner == player }) {
                moves.append(LatticeClashMove(index: index))
            }
        }
        return moves
    }

    private mutating func resolveCaptures(for actor: LatticeClashPlayer) -> [Int] {
        var captured: [Int] = []
        let enemy = actor.opponent

        while true {
            var wave: [Int] = []
            for index in 0..<Self.cellCount where board[index].owner == enemy {
                let support = Self.neighbors(of: index)
                    .reduce(into: 0) { partial, neighbor in
                        if board[neighbor].owner == actor {
                            partial += 1
                        }
                    }
                if support >= 3 {
                    wave.append(index)
                }
            }

            guard !wave.isEmpty else { break }
            for index in wave {
                board[index] = LatticeClashCell(owner: actor)
            }
            captured.append(contentsOf: wave)
        }

        return captured
    }

    private mutating func finishByScore() {
        let host = count(for: .host)
        let guest = count(for: .guest)
        if host == guest {
            winner = nil
            isDraw = true
        } else {
            winner = host > guest ? .host : .guest
            isDraw = false
        }
    }

    static func index(row: Int, column: Int) -> Int {
        row * size + column
    }

    static func rowColumn(for index: Int) -> (row: Int, column: Int) {
        (index / size, index % size)
    }

    static func neighbors(of index: Int) -> [Int] {
        guard (0..<cellCount).contains(index) else { return [] }
        let origin = rowColumn(for: index)
        var result: [Int] = []
        result.reserveCapacity(8)

        for rowDelta in -1...1 {
            for columnDelta in -1...1 {
                if rowDelta == 0 && columnDelta == 0 { continue }
                let row = origin.row + rowDelta
                let column = origin.column + columnDelta
                guard (0..<size).contains(row), (0..<size).contains(column) else { continue }
                result.append(Self.index(row: row, column: column))
            }
        }
        return result
    }
}

enum LatticeClashBot {
    static func chooseMove(
        in state: LatticeClashState,
        actor: LatticeClashPlayer
    ) -> LatticeClashMove? {
        guard !state.isFinished, state.currentPlayer == actor else { return nil }
        let legal = state.legalMoves(for: actor)
        guard !legal.isEmpty else { return nil }

        var bestMove = legal[0]
        var bestScore = Int.min

        for move in legal {
            var probe = state
            guard probe.apply(move: move, actor: actor) else { continue }
            let score = search(state: probe, perspective: actor, depth: 1)
            if score > bestScore || (score == bestScore && move.index < bestMove.index) {
                bestScore = score
                bestMove = move
            }
        }
        return bestMove
    }

    private static func search(
        state: LatticeClashState,
        perspective: LatticeClashPlayer,
        depth: Int
    ) -> Int {
        if depth == 0 || state.isFinished {
            return evaluate(state: state, perspective: perspective)
        }

        let actor = state.currentPlayer
        let moves = state.legalMoves(for: actor)
        guard !moves.isEmpty else {
            return evaluate(state: state, perspective: perspective)
        }

        if actor == perspective {
            var best = Int.min
            for move in moves {
                var probe = state
                guard probe.apply(move: move, actor: actor) else { continue }
                best = max(best, search(state: probe, perspective: perspective, depth: depth - 1))
            }
            return best
        } else {
            var best = Int.max
            for move in moves {
                var probe = state
                guard probe.apply(move: move, actor: actor) else { continue }
                best = min(best, search(state: probe, perspective: perspective, depth: depth - 1))
            }
            return best
        }
    }

    private static func evaluate(
        state: LatticeClashState,
        perspective: LatticeClashPlayer
    ) -> Int {
        if state.winner == perspective {
            return 1_000_000 - state.turn
        }
        if state.winner == perspective.opponent {
            return -1_000_000 + state.turn
        }
        if state.isDraw {
            return 0
        }

        let ownCount = state.count(for: perspective)
        let enemyCount = state.count(for: perspective.opponent)
        let ownMobility = state.legalMoves(for: perspective).count
        let enemyMobility = state.legalMoves(for: perspective.opponent).count
        let center = centrality(in: state, player: perspective)
            - centrality(in: state, player: perspective.opponent)

        return (ownCount - enemyCount) * 100
            + (ownMobility - enemyMobility) * 6
            + center * 2
    }

    private static func centrality(
        in state: LatticeClashState,
        player: LatticeClashPlayer
    ) -> Int {
        let midpoint = LatticeClashState.size / 2
        var score = 0

        for index in 0..<LatticeClashState.cellCount where state.cell(at: index).owner == player {
            let coordinate = LatticeClashState.rowColumn(for: index)
            let distance = abs(coordinate.row - midpoint) + abs(coordinate.column - midpoint)
            score += max(0, LatticeClashState.size - distance)
        }
        return score
    }
}
