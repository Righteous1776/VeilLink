import Foundation

enum MiniGameKind: String, Codable, CaseIterable, Identifiable {
    case gomoku
    case xiangqi
    case ludo
    case tactical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gomoku: return "五子棋"
        case .xiangqi: return "中国象棋"
        case .ludo: return "飞行棋"
        case .tactical: return "三国兵棋"
        }
    }

    var subtitle: String {
        switch self {
        case .gomoku: return "15 × 15 · 黑方先手"
        case .xiangqi: return "标准双人棋盘 · 红方先手"
        case .ludo: return "双人四棋子 · 本地确定性骰子"
        case .tactical: return "官渡决战 · 战役大地图 · 战争迷雾"
        }
    }

    var icon: String {
        switch self {
        case .gomoku: return "circle.grid.cross"
        case .xiangqi: return "checkerboard.rectangle"
        case .ludo: return "die.face.5"
        case .tactical: return "map.fill"
        }
    }
}

enum MiniGameCommand: String, Codable {
    case invite
    case accept
    case decline
    case move
    case resign
}

struct MiniGameMove: Codable, Hashable {
    let from: Int?
    let to: Int?
    let piece: Int?

    static func gomoku(index: Int) -> MiniGameMove {
        MiniGameMove(from: nil, to: index, piece: nil)
    }

    static func xiangqi(from: Int, to: Int) -> MiniGameMove {
        MiniGameMove(from: from, to: to, piece: nil)
    }

    static func ludo(piece: Int) -> MiniGameMove {
        MiniGameMove(from: nil, to: nil, piece: piece)
    }

    static func tactical(from: Int, to: Int) -> MiniGameMove {
        MiniGameMove(from: from, to: to, piece: nil)
    }

    static func tacticalPass() -> MiniGameMove {
        MiniGameMove(from: nil, to: nil, piece: -1)
    }
}

struct MiniGamePacket: Codable, Hashable, Identifiable {
    static let currentVersion = 1

    let version: Int
    let sessionID: String
    let game: MiniGameKind
    let command: MiniGameCommand
    let turn: Int
    let move: MiniGameMove?
    let actionID: String
    let createdAt: Date

    var id: String { actionID }

    init(
        sessionID: String = UUID().uuidString,
        game: MiniGameKind,
        command: MiniGameCommand,
        turn: Int = 0,
        move: MiniGameMove? = nil,
        actionID: String = UUID().uuidString,
        createdAt: Date = Date()
    ) {
        self.version = Self.currentVersion
        self.sessionID = sessionID
        self.game = game
        self.command = command
        self.turn = turn
        self.move = move
        self.actionID = actionID
        self.createdAt = createdAt
    }
}

enum MiniGameCodec {
    private static let prefix = "\u{2063}VLGM1:"

    static func encode(_ packet: MiniGamePacket) throws -> String {
        let data = try JSONEncoder().encode(packet)
        return prefix + data.base64EncodedString()
    }

    static func decode(_ body: String) -> MiniGamePacket? {
        guard body.hasPrefix(prefix) else { return nil }
        let encoded = String(body.dropFirst(prefix.count))
        guard let data = Data(base64Encoded: encoded),
              let packet = try? JSONDecoder().decode(MiniGamePacket.self, from: data),
              packet.version == MiniGamePacket.currentVersion,
              UUID(uuidString: packet.sessionID) != nil,
              UUID(uuidString: packet.actionID) != nil,
              packet.turn >= 0 else { return nil }
        return packet
    }

    static func previewText(for body: String) -> String? {
        guard let packet = decode(body) else { return nil }
        return previewText(for: packet)
    }

    static func previewText(for packet: MiniGamePacket) -> String {
        switch packet.command {
        case .invite: return "[小游戏] 邀请你玩\(packet.game.title)"
        case .accept: return "[小游戏] 已接受\(packet.game.title)对局"
        case .decline: return "[小游戏] 已拒绝\(packet.game.title)对局"
        case .move: return "[小游戏] \(packet.game.title) · 对局更新"
        case .resign: return "[小游戏] \(packet.game.title) · 对局结束"
        }
    }
}

enum MiniGamePlayer: String, Codable, Hashable {
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

struct GomokuState: Equatable {
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

enum XiangqiSide: String, Codable, Hashable {
    case red
    case black

    var opponent: XiangqiSide { self == .red ? .black : .red }
}

enum XiangqiPieceKind: String, Codable, Hashable {
    case general
    case advisor
    case elephant
    case horse
    case rook
    case cannon
    case soldier
}

struct XiangqiPiece: Codable, Hashable {
    let side: XiangqiSide
    let kind: XiangqiPieceKind

    var glyph: String {
        switch (side, kind) {
        case (.red, .general): return "帅"
        case (.black, .general): return "将"
        case (.red, .advisor): return "仕"
        case (.black, .advisor): return "士"
        case (.red, .elephant): return "相"
        case (.black, .elephant): return "象"
        case (.red, .horse): return "马"
        case (.black, .horse): return "馬"
        case (.red, .rook): return "车"
        case (.black, .rook): return "車"
        case (.red, .cannon): return "炮"
        case (.black, .cannon): return "砲"
        case (.red, .soldier): return "兵"
        case (.black, .soldier): return "卒"
        }
    }
}

enum XiangqiDrawReason: String, Equatable {
    case threefoldRepetition
}

struct XiangqiState: Equatable {
    static let rows = 10
    static let columns = 9

    private(set) var board: [XiangqiPiece?]
    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var winner: MiniGamePlayer?
    private(set) var drawReason: XiangqiDrawReason?
    private(set) var moveCount = 0
    private(set) var lastMove: MiniGameMove?
    private(set) var lastMoveGaveCheck = false
    private(set) var endedByNoLegalMove = false
    private(set) var hostConsecutiveChecks = 0
    private(set) var guestConsecutiveChecks = 0
    private var positionCounts: [String: Int] = [:]

    init() {
        board = Array(repeating: nil, count: Self.rows * Self.columns)
        setupInitialPosition()
        registerCurrentPosition()
    }

    var isDraw: Bool { drawReason != nil }

    func consecutiveCheckCount(for player: MiniGamePlayer) -> Int {
        player == .host ? hostConsecutiveChecks : guestConsecutiveChecks
    }

    var currentPositionRepetitionCount: Int { positionCounts[positionSignature()] ?? 0 }

    func piece(at index: Int) -> XiangqiPiece? {
        guard board.indices.contains(index) else { return nil }
        return board[index]
    }

    var currentSide: XiangqiSide { currentPlayer == .host ? .red : .black }

    var isCurrentPlayerInCheck: Bool { isGeneralInCheck(currentSide) }

    func isInCheck(player: MiniGamePlayer) -> Bool {
        isGeneralInCheck(player == .host ? .red : .black)
    }

    func legalDestinations(from index: Int, actor: MiniGamePlayer) -> [Int] {
        guard winner == nil, !isDraw, actor == currentPlayer,
              let piece = piece(at: index),
              player(for: piece.side) == actor else { return [] }
        return board.indices.filter { isLegalMove(from: index, to: $0, side: piece.side) }
    }

    mutating func apply(from: Int, to: Int, actor: MiniGamePlayer) -> Bool {
        guard winner == nil, !isDraw,
              actor == currentPlayer,
              board.indices.contains(from), board.indices.contains(to),
              let moving = board[from],
              player(for: moving.side) == actor,
              isLegalMove(from: from, to: to, side: moving.side) else { return false }

        let captured = board[to]
        board[to] = moving
        board[from] = nil
        lastMove = .xiangqi(from: from, to: to)
        moveCount += 1
        if captured?.kind == .general {
            winner = actor
            lastMoveGaveCheck = true
            return true
        }

        let opponent = actor.opponent
        currentPlayer = opponent
        let gaveCheck = isGeneralInCheck(currentSide)
        lastMoveGaveCheck = gaveCheck
        if actor == .host {
            hostConsecutiveChecks = gaveCheck ? hostConsecutiveChecks + 1 : 0
        } else {
            guestConsecutiveChecks = gaveCheck ? guestConsecutiveChecks + 1 : 0
        }
        if !hasAnyLegalMove(for: opponent) {
            winner = actor
            endedByNoLegalMove = true
        } else if registerCurrentPosition() >= 3 {
            drawReason = .threefoldRepetition
        }
        return true
    }

    func hasAnyLegalMove(for player: MiniGamePlayer) -> Bool {
        let side: XiangqiSide = player == .host ? .red : .black
        for source in board.indices {
            guard let piece = board[source], piece.side == side else { continue }
            for destination in board.indices where isLegalMove(from: source, to: destination, side: side) {
                return true
            }
        }
        return false
    }

    private mutating func setupInitialPosition() {
        let back: [XiangqiPieceKind] = [.rook, .horse, .elephant, .advisor, .general, .advisor, .elephant, .horse, .rook]
        for col in 0..<Self.columns {
            board[index(row: 0, col: col)] = XiangqiPiece(side: .black, kind: back[col])
            board[index(row: 9, col: col)] = XiangqiPiece(side: .red, kind: back[col])
        }
        board[index(row: 2, col: 1)] = XiangqiPiece(side: .black, kind: .cannon)
        board[index(row: 2, col: 7)] = XiangqiPiece(side: .black, kind: .cannon)
        board[index(row: 7, col: 1)] = XiangqiPiece(side: .red, kind: .cannon)
        board[index(row: 7, col: 7)] = XiangqiPiece(side: .red, kind: .cannon)
        for col in stride(from: 0, through: 8, by: 2) {
            board[index(row: 3, col: col)] = XiangqiPiece(side: .black, kind: .soldier)
            board[index(row: 6, col: col)] = XiangqiPiece(side: .red, kind: .soldier)
        }
    }

    private func player(for side: XiangqiSide) -> MiniGamePlayer { side == .red ? .host : .guest }

    private func index(row: Int, col: Int) -> Int { row * Self.columns + col }

    private func coordinates(_ index: Int) -> (row: Int, col: Int) { (index / Self.columns, index % Self.columns) }

    private func isLegalMove(from: Int, to: Int, side: XiangqiSide) -> Bool {
        guard from != to,
              board.indices.contains(from), board.indices.contains(to),
              let piece = board[from], piece.side == side,
              board[to]?.side != side,
              isPseudoLegalMove(from: from, to: to, piece: piece) else { return false }

        var simulated = self
        simulated.board[to] = piece
        simulated.board[from] = nil
        return !simulated.isGeneralInCheck(side)
    }

    private func isGeneralInCheck(_ side: XiangqiSide) -> Bool {
        guard let generalIndex = board.firstIndex(where: { $0?.side == side && $0?.kind == .general }) else { return true }
        for source in board.indices {
            guard let piece = board[source], piece.side == side.opponent else { continue }
            if isPseudoLegalMove(from: source, to: generalIndex, piece: piece) { return true }
        }
        return false
    }

    private func isPseudoLegalMove(from: Int, to: Int, piece: XiangqiPiece) -> Bool {
        let a = coordinates(from)
        let b = coordinates(to)
        let dr = b.row - a.row
        let dc = b.col - a.col
        let adr = abs(dr)
        let adc = abs(dc)

        switch piece.kind {
        case .general:
            if a.col == b.col, clearCountBetween(from: from, to: to) == 0, board[to]?.kind == .general {
                return true
            }
            return adr + adc == 1 && insidePalace(row: b.row, col: b.col, side: piece.side)

        case .advisor:
            return adr == 1 && adc == 1 && insidePalace(row: b.row, col: b.col, side: piece.side)

        case .elephant:
            guard adr == 2, adc == 2 else { return false }
            if piece.side == .red, b.row < 5 { return false }
            if piece.side == .black, b.row > 4 { return false }
            let eye = index(row: a.row + dr / 2, col: a.col + dc / 2)
            return board[eye] == nil

        case .horse:
            guard (adr == 2 && adc == 1) || (adr == 1 && adc == 2) else { return false }
            let leg: Int
            if adr == 2 {
                leg = index(row: a.row + dr / 2, col: a.col)
            } else {
                leg = index(row: a.row, col: a.col + dc / 2)
            }
            return board[leg] == nil

        case .rook:
            guard (dr == 0) != (dc == 0) else { return false }
            return clearCountBetween(from: from, to: to) == 0

        case .cannon:
            guard (dr == 0) != (dc == 0) else { return false }
            let blockers = clearCountBetween(from: from, to: to)
            return board[to] == nil ? blockers == 0 : blockers == 1

        case .soldier:
            switch piece.side {
            case .red:
                if dr == -1 && dc == 0 { return true }
                return a.row <= 4 && dr == 0 && adc == 1
            case .black:
                if dr == 1 && dc == 0 { return true }
                return a.row >= 5 && dr == 0 && adc == 1
            }
        }
    }

    @discardableResult
    private mutating func registerCurrentPosition() -> Int {
        let signature = positionSignature()
        let count = (positionCounts[signature] ?? 0) + 1
        positionCounts[signature] = count
        return count
    }

    private func positionSignature() -> String {
        var result = currentPlayer == .host ? "H|" : "G|"
        result.reserveCapacity(2 + board.count * 2)
        for square in board {
            guard let square else { result.append("."); continue }
            result.append(square.side == .red ? "r" : "b")
            switch square.kind {
            case .general: result.append("g")
            case .advisor: result.append("a")
            case .elephant: result.append("e")
            case .horse: result.append("h")
            case .rook: result.append("r")
            case .cannon: result.append("c")
            case .soldier: result.append("s")
            }
        }
        return result
    }

    private func insidePalace(row: Int, col: Int, side: XiangqiSide) -> Bool {
        guard (3...5).contains(col) else { return false }
        return side == .red ? (7...9).contains(row) : (0...2).contains(row)
    }

    private func clearCountBetween(from: Int, to: Int) -> Int {
        let a = coordinates(from)
        let b = coordinates(to)
        guard a.row == b.row || a.col == b.col else { return Int.max }
        var count = 0
        if a.row == b.row {
            let lower = min(a.col, b.col) + 1
            let upper = max(a.col, b.col)
            if lower < upper {
                for col in lower..<upper where board[index(row: a.row, col: col)] != nil { count += 1 }
            }
        } else {
            let lower = min(a.row, b.row) + 1
            let upper = max(a.row, b.row)
            if lower < upper {
                for row in lower..<upper where board[index(row: row, col: a.col)] != nil { count += 1 }
            }
        }
        return count
    }
}

struct LudoState: Equatable {
    static let pieceCount = 4
    static let trackLength = 52
    static let finishProgress = 57
    private static let safeTrackSquares: Set<Int> = [0, 13, 26, 39]

    private(set) var hostPieces = Array(repeating: -1, count: pieceCount)
    private(set) var guestPieces = Array(repeating: -1, count: pieceCount)
    private(set) var currentPlayer: MiniGamePlayer = .host
    private(set) var winner: MiniGamePlayer?
    private(set) var turn = 0
    private(set) var lastDice = 1
    private(set) var lastMovedPiece: Int?
    private(set) var lastCapturedCount = 0
    private(set) var lastMoveGrantedExtraTurn = false

    func pieces(for player: MiniGamePlayer) -> [Int] { player == .host ? hostPieces : guestPieces }

    func finishedCount(for player: MiniGamePlayer) -> Int {
        pieces(for: player).filter { $0 == Self.finishProgress }.count
    }

    func trackPosition(player: MiniGamePlayer, progress: Int) -> Int? {
        trackSquare(player: player, progress: progress)
    }

    func expectedDice(sessionID: String) -> Int {
        Self.deterministicDice(sessionID: sessionID, turn: turn)
    }

    func legalPieces(sessionID: String) -> [Int] {
        let dice = expectedDice(sessionID: sessionID)
        return pieces(for: currentPlayer).indices.filter { canMove(progress: pieces(for: currentPlayer)[$0], dice: dice) }
    }

    mutating func apply(pieceIndex: Int, actor: MiniGamePlayer, sessionID: String) -> Bool {
        guard winner == nil, actor == currentPlayer else { return false }
        let dice = expectedDice(sessionID: sessionID)
        let legal = legalPieces(sessionID: sessionID)
        if pieceIndex == -1 {
            guard legal.isEmpty else { return false }
            lastDice = dice
            lastMovedPiece = nil
            lastCapturedCount = 0
            lastMoveGrantedExtraTurn = false
            turn += 1
            currentPlayer = actor.opponent
            return true
        }
        guard legal.contains(pieceIndex) else { return false }

        var own = pieces(for: actor)
        let old = own[pieceIndex]
        own[pieceIndex] = old == -1 ? 0 : old + dice
        if actor == .host { hostPieces = own } else { guestPieces = own }

        let capturedCount = captureOpponentIfNeeded(actor: actor, landingProgress: own[pieceIndex])
        lastDice = dice
        lastMovedPiece = pieceIndex
        lastCapturedCount = capturedCount
        lastMoveGrantedExtraTurn = dice == 6 || capturedCount > 0
        turn += 1

        if own.allSatisfy({ $0 == Self.finishProgress }) {
            winner = actor
        } else if !lastMoveGrantedExtraTurn {
            currentPlayer = actor.opponent
        }
        return true
    }

    private func canMove(progress: Int, dice: Int) -> Bool {
        if progress == Self.finishProgress { return false }
        if progress == -1 { return dice == 6 }
        return progress + dice <= Self.finishProgress
    }

    private mutating func captureOpponentIfNeeded(actor: MiniGamePlayer, landingProgress: Int) -> Int {
        guard landingProgress >= 0, landingProgress < Self.trackLength,
              let landingTrack = trackSquare(player: actor, progress: landingProgress),
              !Self.safeTrackSquares.contains(landingTrack) else { return 0 }

        var opponentPieces = pieces(for: actor.opponent)
        var capturedCount = 0
        for index in opponentPieces.indices {
            let progress = opponentPieces[index]
            guard progress >= 0, progress < Self.trackLength,
                  trackSquare(player: actor.opponent, progress: progress) == landingTrack else { continue }
            opponentPieces[index] = -1
            capturedCount += 1
        }
        if actor == .host { guestPieces = opponentPieces } else { hostPieces = opponentPieces }
        return capturedCount
    }

    private func trackSquare(player: MiniGamePlayer, progress: Int) -> Int? {
        guard progress >= 0, progress < Self.trackLength else { return nil }
        return (progress + (player == .host ? 0 : 26)) % Self.trackLength
    }

    private static func deterministicDice(sessionID: String, turn: Int) -> Int {
        var hash: UInt64 = 1469598103934665603
        for byte in Data("\(sessionID)|\(turn)".utf8) {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int(hash % 6) + 1
    }
}

struct MiniGameSessionSnapshot: Identifiable, Equatable {
    let id: String
    let game: MiniGameKind
    let hostIsLocal: Bool
    let status: MiniGameSessionStatus
    let invitedAt: Date
    let startedAt: Date?
    let lastActivity: Date
    let gomoku: GomokuState?
    let xiangqi: XiangqiState?
    let ludo: LudoState?
    let tactical: TacticalState?
    let endedByResignation: Bool

    init(
        id: String,
        game: MiniGameKind,
        hostIsLocal: Bool,
        status: MiniGameSessionStatus,
        invitedAt: Date,
        startedAt: Date?,
        lastActivity: Date,
        gomoku: GomokuState?,
        xiangqi: XiangqiState?,
        ludo: LudoState?,
        tactical: TacticalState? = nil,
        endedByResignation: Bool
    ) {
        self.id = id
        self.game = game
        self.hostIsLocal = hostIsLocal
        self.status = status
        self.invitedAt = invitedAt
        self.startedAt = startedAt
        self.lastActivity = lastActivity
        self.gomoku = gomoku
        self.xiangqi = xiangqi
        self.ludo = ludo
        self.tactical = tactical
        self.endedByResignation = endedByResignation
    }

    var localPlayer: MiniGamePlayer { hostIsLocal ? .host : .guest }

    var currentPlayer: MiniGamePlayer? {
        switch game {
        case .gomoku: return gomoku?.currentPlayer
        case .xiangqi: return xiangqi?.currentPlayer
        case .ludo: return ludo?.currentPlayer
        case .tactical: return tactical?.currentPlayer
        }
    }

    var moveCount: Int {
        switch game {
        case .gomoku: return gomoku?.moveCount ?? 0
        case .xiangqi: return xiangqi?.moveCount ?? 0
        case .ludo: return ludo?.turn ?? 0
        case .tactical: return tactical?.turn ?? 0
        }
    }

    var isLocalTurn: Bool { status == .active && currentPlayer == localPlayer }

    var duration: TimeInterval? {
        guard let startedAt else { return nil }
        return max(0, lastActivity.timeIntervalSince(startedAt))
    }

    var localOutcome: MiniGameOutcome? {
        guard case .finished(let winner) = status else { return nil }
        guard let winner else { return .draw }
        return winner == localPlayer ? .win : .loss
    }
}

enum MiniGameOutcome: String, Equatable {
    case win
    case loss
    case draw
}

struct MiniGameKindStatistics: Equatable {
    let game: MiniGameKind
    let completed: Int
    let wins: Int
    let losses: Int
    let draws: Int

    var winRate: Double { completed == 0 ? 0 : Double(wins) / Double(completed) }
}

struct MiniGameStatistics: Equatable {
    let completed: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let currentWinStreak: Int
    let byGame: [MiniGameKind: MiniGameKindStatistics]

    init(sessions: [MiniGameSessionSnapshot]) {
        let terminal = sessions.filter { $0.localOutcome != nil }
        completed = terminal.count
        wins = terminal.filter { $0.localOutcome == .win }.count
        losses = terminal.filter { $0.localOutcome == .loss }.count
        draws = terminal.filter { $0.localOutcome == .draw }.count

        var streak = 0
        for session in terminal.sorted(by: { $0.lastActivity > $1.lastActivity }) {
            guard session.localOutcome == .win else { break }
            streak += 1
        }
        currentWinStreak = streak

        var table: [MiniGameKind: MiniGameKindStatistics] = [:]
        for game in MiniGameKind.allCases {
            let matches = terminal.filter { $0.game == game }
            table[game] = MiniGameKindStatistics(
                game: game,
                completed: matches.count,
                wins: matches.filter { $0.localOutcome == .win }.count,
                losses: matches.filter { $0.localOutcome == .loss }.count,
                draws: matches.filter { $0.localOutcome == .draw }.count
            )
        }
        byGame = table
    }

    var winRate: Double { completed == 0 ? 0 : Double(wins) / Double(completed) }
}

struct MiniGameReplayFrame: Identifiable, Equatable {
    let id: String
    let index: Int
    let label: String
    let snapshot: MiniGameSessionSnapshot
}

enum MiniGameSessionBuilder {
    static func sessions(from messages: [ChatMessage]) -> [MiniGameSessionSnapshot] {
        let decoded: [(ChatMessage, MiniGamePacket)] = messages.compactMap { message in
            guard let packet = MiniGameCodec.decode(message.body) else { return nil }
            return (message, packet)
        }
        let grouped = Dictionary(grouping: decoded, by: { $0.1.sessionID })
        return grouped.compactMap { sessionID, events in
            build(sessionID: sessionID, events: events)
        }.sorted { $0.lastActivity > $1.lastActivity }
    }

    static func session(id: String, from messages: [ChatMessage]) -> MiniGameSessionSnapshot? {
        let events: [(ChatMessage, MiniGamePacket)] = messages.compactMap { message in
            guard let packet = MiniGameCodec.decode(message.body), packet.sessionID == id else { return nil }
            return (message, packet)
        }
        return build(sessionID: id, events: events)
    }

    static func sessionsByID(from messages: [ChatMessage]) -> [String: MiniGameSessionSnapshot] {
        Dictionary(uniqueKeysWithValues: sessions(from: messages).map { ($0.id, $0) })
    }

    static func replay(sessionID: String, from messages: [ChatMessage]) -> [MiniGameReplayFrame] {
        let ordered: [(ChatMessage, MiniGamePacket)] = messages.compactMap { message in
            guard let packet = MiniGameCodec.decode(message.body), packet.sessionID == sessionID else { return nil }
            return (message, packet)
        }.sorted(by: eventOrder)
        guard !ordered.isEmpty else { return [] }

        var frames: [MiniGameReplayFrame] = []
        var previous: MiniGameSessionSnapshot?
        for offset in ordered.indices {
            let prefix = Array(ordered.prefix(offset + 1))
            guard let snapshot = build(sessionID: sessionID, events: prefix) else { continue }
            let changed = previous == nil || previous?.status != snapshot.status || previous?.moveCount != snapshot.moveCount
            guard changed else { continue }
            let packet = ordered[offset].1
            let label: String
            switch packet.command {
            case .invite: label = "邀请对局"
            case .accept: label = "对局开始"
            case .decline: label = "邀请被拒绝"
            case .resign: label = snapshot.status == .cancelled ? "邀请已撤回" : "认输结束"
            case .move:
                let unit = snapshot.game == .tactical ? "道命令" : "手"
                if case .finished(let winner) = snapshot.status, winner == nil {
                    label = "第 \(snapshot.moveCount) \(unit) · 和棋"
                } else {
                    label = "第 \(snapshot.moveCount) \(unit)"
                }
            }
            frames.append(MiniGameReplayFrame(id: packet.actionID, index: frames.count, label: label, snapshot: snapshot))
            previous = snapshot
        }
        return frames
    }

    private static func build(sessionID: String, events: [(ChatMessage, MiniGamePacket)]) -> MiniGameSessionSnapshot? {
        let compatible = events.filter { $0.1.version == MiniGamePacket.currentVersion }
        let ordered = Dictionary(grouping: compatible, by: { $0.1.actionID })
            .values
            .compactMap { duplicates in duplicates.min(by: duplicatePreferenceOrder) }
            .sorted(by: eventOrder)
        guard let invite = ordered.first(where: { $0.1.command == .invite && $0.1.turn == 0 }) else { return nil }
        let game = invite.1.game
        let hostIsLocal = invite.0.isOutgoing
        let invitedAt = min(invite.0.sentAt, invite.1.createdAt)
        let actor: (ChatMessage) -> MiniGamePlayer = { message in
            message.isOutgoing == hostIsLocal ? .host : .guest
        }
        let valid = ordered.filter { $0.1.game == game && !eventOrder($0, invite) }
        let inviteActivity = max(invite.0.sentAt, invite.1.createdAt)
        let activity: ((ChatMessage, MiniGamePacket)) -> Date = { max($0.0.sentAt, $0.1.createdAt) }

        let lifecycleEvent = valid.first { event in
            let player = actor(event.0)
            if player == .guest && (event.1.command == .accept || event.1.command == .decline) { return true }
            if player == .host && event.1.command == .resign { return true }
            return false
        }

        let initialGomoku = game == .gomoku ? GomokuState() : nil
        let initialXiangqi = game == .xiangqi ? XiangqiState() : nil
        let initialLudo = game == .ludo ? LudoState() : nil
        let initialTactical = game == .tactical ? TacticalState() : nil

        guard let lifecycleEvent else {
            return MiniGameSessionSnapshot(
                id: sessionID, game: game, hostIsLocal: hostIsLocal, status: .invited,
                invitedAt: invitedAt, startedAt: nil, lastActivity: inviteActivity,
                gomoku: initialGomoku, xiangqi: initialXiangqi, ludo: initialLudo, tactical: initialTactical,
                endedByResignation: false
            )
        }
        if actor(lifecycleEvent.0) == .host && lifecycleEvent.1.command == .resign {
            return MiniGameSessionSnapshot(
                id: sessionID, game: game, hostIsLocal: hostIsLocal, status: .cancelled,
                invitedAt: invitedAt, startedAt: nil, lastActivity: activity(lifecycleEvent),
                gomoku: initialGomoku, xiangqi: initialXiangqi, ludo: initialLudo, tactical: initialTactical,
                endedByResignation: false
            )
        }
        if lifecycleEvent.1.command == .decline {
            return MiniGameSessionSnapshot(
                id: sessionID, game: game, hostIsLocal: hostIsLocal, status: .declined,
                invitedAt: invitedAt, startedAt: nil, lastActivity: activity(lifecycleEvent),
                gomoku: initialGomoku, xiangqi: initialXiangqi, ludo: initialLudo, tactical: initialTactical,
                endedByResignation: false
            )
        }

        let startedAt = max(lifecycleEvent.0.sentAt, lifecycleEvent.1.createdAt)
        let gameplayEvents = valid.filter { eventOrder(lifecycleEvent, $0) && ($0.1.command == .move || $0.1.command == .resign) }
        let gameplayEventsByTurn = Dictionary(grouping: gameplayEvents, by: { $0.1.turn })
        var gomoku = initialGomoku
        var xiangqi = initialXiangqi
        var ludo = initialLudo
        var tactical = initialTactical
        var resignationWinner: MiniGamePlayer?
        var usedActionIDs = Set<String>()
        var effectiveLastActivity = activity(lifecycleEvent)

        // Replay turn-by-turn instead of trusting arrival order. Duplicate/conflicting actions are
        // deterministically collapsed using the packet timestamp + action ID so both peers rebuild
        // the same board from the same encrypted history.
        replayLoop: while resignationWinner == nil {
            let turn: Int
            switch game {
            case .gomoku: turn = gomoku?.moveCount ?? 0
            case .xiangqi: turn = xiangqi?.moveCount ?? 0
            case .ludo: turn = ludo?.turn ?? 0
            case .tactical: turn = tactical?.turn ?? 0
            }

            let candidates = (gameplayEventsByTurn[turn] ?? [])
                .filter { !usedActionIDs.contains($0.1.actionID) }
                .sorted(by: gameplayOrder)
            guard !candidates.isEmpty else { break }

            var advanced = false
            for event in candidates {
                let packet = event.1
                guard usedActionIDs.insert(packet.actionID).inserted else { continue }
                let player = actor(event.0)
                if packet.command == .resign {
                    resignationWinner = player.opponent
                    effectiveLastActivity = max(effectiveLastActivity, activity(event))
                    break replayLoop
                }
                guard packet.command == .move, let move = packet.move else { continue }
                let applied: Bool
                switch game {
                case .gomoku:
                    applied = move.to.map { gomoku?.apply(index: $0, actor: player) ?? false } ?? false
                case .xiangqi:
                    if let from = move.from, let to = move.to {
                        applied = xiangqi?.apply(from: from, to: to, actor: player) ?? false
                    } else { applied = false }
                case .ludo:
                    applied = move.piece.map { ludo?.apply(pieceIndex: $0, actor: player, sessionID: sessionID) ?? false } ?? false
                case .tactical:
                    if move.piece == -1, move.from == nil, move.to == nil {
                        applied = tactical?.apply(from: nil, to: nil, actor: player, sessionID: sessionID) ?? false
                    } else {
                        applied = tactical?.apply(from: move.from, to: move.to, actor: player, sessionID: sessionID) ?? false
                    }
                }
                if applied {
                    effectiveLastActivity = max(effectiveLastActivity, activity(event))
                    advanced = true
                    break
                }
            }
            if !advanced { break }

            let hasWinner: Bool
            switch game {
            case .gomoku: hasWinner = gomoku?.winner != nil || gomoku?.isDraw == true
            case .xiangqi: hasWinner = xiangqi?.winner != nil
            case .ludo: hasWinner = ludo?.winner != nil
            case .tactical: hasWinner = tactical?.winner != nil || tactical?.isDraw == true
            }
            if hasWinner { break }
        }

        let boardWinner: MiniGamePlayer?
        let boardDraw: Bool
        switch game {
        case .gomoku:
            boardWinner = gomoku?.winner
            boardDraw = gomoku?.isDraw == true
        case .xiangqi:
            boardWinner = xiangqi?.winner
            boardDraw = xiangqi?.isDraw == true
        case .ludo:
            boardWinner = ludo?.winner
            boardDraw = false
        case .tactical:
            boardWinner = tactical?.winner
            boardDraw = tactical?.isDraw == true
        }

        let status: MiniGameSessionStatus
        if let winner = resignationWinner ?? boardWinner {
            status = .finished(winner: winner)
        } else if boardDraw {
            status = .finished(winner: nil)
        } else {
            status = .active
        }

        return MiniGameSessionSnapshot(
            id: sessionID, game: game, hostIsLocal: hostIsLocal, status: status,
            invitedAt: invitedAt, startedAt: startedAt, lastActivity: effectiveLastActivity,
            gomoku: gomoku, xiangqi: xiangqi, ludo: ludo, tactical: tactical,
            endedByResignation: resignationWinner != nil
        )
    }

    private static func duplicatePreferenceOrder(_ lhs: (ChatMessage, MiniGamePacket), _ rhs: (ChatMessage, MiniGamePacket)) -> Bool {
        if lhs.1.createdAt != rhs.1.createdAt { return lhs.1.createdAt < rhs.1.createdAt }
        if lhs.1.game.rawValue != rhs.1.game.rawValue { return lhs.1.game.rawValue < rhs.1.game.rawValue }
        if lhs.1.command.rawValue != rhs.1.command.rawValue { return lhs.1.command.rawValue < rhs.1.command.rawValue }
        if lhs.1.turn != rhs.1.turn { return lhs.1.turn < rhs.1.turn }
        let leftMove = [lhs.1.move?.from ?? -2, lhs.1.move?.to ?? -2, lhs.1.move?.piece ?? -2]
        let rightMove = [rhs.1.move?.from ?? -2, rhs.1.move?.to ?? -2, rhs.1.move?.piece ?? -2]
        if leftMove != rightMove {
            for (left, right) in zip(leftMove, rightMove) where left != right { return left < right }
        }
        return lhs.0.sentAt < rhs.0.sentAt
    }

    private static func eventOrder(_ lhs: (ChatMessage, MiniGamePacket), _ rhs: (ChatMessage, MiniGamePacket)) -> Bool {
        if lhs.0.sentAt != rhs.0.sentAt { return lhs.0.sentAt < rhs.0.sentAt }
        if lhs.1.createdAt != rhs.1.createdAt { return lhs.1.createdAt < rhs.1.createdAt }
        return lhs.1.actionID < rhs.1.actionID
    }

    private static func gameplayOrder(_ lhs: (ChatMessage, MiniGamePacket), _ rhs: (ChatMessage, MiniGamePacket)) -> Bool {
        if lhs.1.createdAt != rhs.1.createdAt { return lhs.1.createdAt < rhs.1.createdAt }
        return lhs.1.actionID < rhs.1.actionID
    }
}
