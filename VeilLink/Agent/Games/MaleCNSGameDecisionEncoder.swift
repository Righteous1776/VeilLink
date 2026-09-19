import Foundation

enum MaleCNSGameDecisionEncoder {
    static let channelCount = 8

    static func taskVector(session: MiniGameSessionSnapshot, candidate: AgentActionCandidate) -> [Float]? {
        switch session.game {
        case .gomoku:
            guard let state = session.gomoku,
                  let index = candidate.metadata["index"].flatMap(Int.init) else { return nil }
            let actor = session.localPlayer
            let row = index / GomokuState.size, col = index % GomokuState.size
            let center = Float(GomokuState.size - 1) / 2
            let distance = abs(Float(row) - center) + abs(Float(col) - center)
            let ownValue: Int8 = actor == .host ? 1 : 2
            let oppValue: Int8 = actor == .host ? 2 : 1
            var own = 0, opponent = 0
            for dr in -2...2 {
                for dc in -2...2 where !(dr == 0 && dc == 0) {
                    let r = row + dr, c = col + dc
                    guard (0..<GomokuState.size).contains(r), (0..<GomokuState.size).contains(c) else { continue }
                    let value = state.value(at: r * GomokuState.size + c)
                    let multiplier = abs(dr) <= 1 && abs(dc) <= 1 ? 2 : 1
                    if value == ownValue { own += multiplier }
                    if value == oppValue { opponent += multiplier }
                }
            }
            var simulated = state
            let didApply = simulated.apply(index: index, actor: actor)
            let immediateWin: Float = didApply && simulated.winner == actor ? 1 : 0
            return [
                Float(row) / 14, Float(col) / 14, max(0, 1 - distance / 14),
                min(1, Float(own) / 16), min(1, Float(opponent) / 16),
                Float(state.moveCount) / 225, immediateWin, 1
            ]

        case .xiangqi:
            guard let state = session.xiangqi,
                  let from = candidate.metadata["from"].flatMap(Int.init),
                  let to = candidate.metadata["to"].flatMap(Int.init),
                  let piece = state.piece(at: from) else { return nil }
            let actor = session.localPlayer
            let capture = state.piece(at: to).map(pieceValue) ?? 0
            let fromRow = from / XiangqiState.columns, fromCol = from % XiangqiState.columns
            let toRow = to / XiangqiState.columns, toCol = to % XiangqiState.columns
            var simulated = state
            let didApply = simulated.apply(from: from, to: to, actor: actor)
            let givesCheck: Float = didApply && simulated.isInCheck(player: actor.opponent) ? 1 : 0
            return [
                Float(from) / 89, Float(to) / 89, Float(capture) / 7, Float(pieceValue(piece)) / 7,
                Float(abs(toRow - fromRow)) / 9, Float(abs(toCol - fromCol)) / 8,
                givesCheck, 1
            ]

        case .ludo:
            guard let state = session.ludo,
                  let piece = candidate.metadata["piece"].flatMap(Int.init) else { return nil }
            let actor = session.localPlayer
            let dice = state.expectedDice(sessionID: session.id)
            if piece < 0 { return [0, 0, 0, 0, Float(dice) / 6, 0, 0, 1] }
            let before = state.pieces(for: actor)[piece]
            var simulated = state
            guard simulated.apply(pieceIndex: piece, actor: actor, sessionID: session.id) else { return nil }
            let after = simulated.pieces(for: actor)[piece]
            return [
                Float(piece) / 3, progress(before), progress(after), before == -1 ? 1 : 0,
                Float(dice) / 6, min(1, Float(simulated.lastCapturedCount) / 2),
                after == LudoState.finishProgress ? 1 : 0, 1
            ]

        case .tactical:
            return nil
        }
    }

    static func channels(task: [Float], game: MiniGameKind) -> [Float]? {
        guard task.count == 8 else { return nil }
        let gameIndex: Float
        switch game {
        case .gomoku: gameIndex = 0
        case .xiangqi: gameIndex = 1
        case .ludo: gameIndex = 2
        case .tactical: return nil
        }
        let phase = (gameIndex + 1) * 0.37
        let offsets: [Float] = [0.05, -0.03, 0.04, -0.02, 0.03, -0.04, 0.02, -0.01]
        var z: [Float] = [
            task[0] * 0.9 + task[4] * 0.4,
            (1 - task[0]) * 0.7 + task[5] * 0.5,
            task[1] * 0.8 + task[2] * 0.5,
            (1 - task[1]) * 0.6 + task[3] * 0.5,
            task[2] * 0.7 + task[6] * 0.8,
            task[3] * 0.8 + (1 - task[2]) * 0.3,
            task[4] * 0.5 + task[6] * 0.9,
            task[5] * 0.6 + task[7] * 0.4
        ]
        for i in z.indices {
            z[i] = Float(tanh(Double(z[i] + phase * offsets[i])))
            z[i] = min(1.55, max(0, 0.10 + 1.25 * z[i]))
        }
        return z
    }

    private static func pieceValue(_ piece: XiangqiPiece) -> Int {
        switch piece.kind {
        case .general: return 7
        case .rook: return 6
        case .cannon: return 5
        case .horse: return 4
        case .elephant: return 3
        case .advisor: return 2
        case .soldier: return 1
        }
    }

    private static func progress(_ value: Int) -> Float {
        Float(value + 1) / Float(LudoState.finishProgress + 1)
    }
}
