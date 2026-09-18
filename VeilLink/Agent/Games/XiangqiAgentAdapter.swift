import Foundation

struct XiangqiAgentAdapter: AgentGameAdapter {
    let state: XiangqiState
    let actor: MiniGamePlayer

    let gameKind: MiniGameKind = .xiangqi
    let adapterVersion = "xiangqi-agent-v1"

    private func pieceValue(_ piece: XiangqiPiece) -> Int {
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

    func makeObservation() -> AgentGameObservation {
        var features: [AgentFeature] = []
        features.reserveCapacity(XiangqiState.rows * XiangqiState.columns + 5)
        let ownSide: XiangqiSide = actor == .host ? .red : .black
        for index in state.board.indices {
            guard let piece = state.board[index] else {
                features.append(AgentFeature(key: "c\(index)", value: 0)); continue
            }
            let sign: Float = piece.side == ownSide ? 1 : -1
            features.append(AgentFeature(key: "c\(index)", value: sign * Float(pieceValue(piece)) / 7))
        }
        features.append(AgentFeature(key: "turn.mine", value: state.currentPlayer == actor ? 1 : 0))
        features.append(AgentFeature(key: "check.mine", value: state.isInCheck(player: actor) ? 1 : 0))
        features.append(AgentFeature(key: "check.enemy", value: state.isInCheck(player: actor.opponent) ? 1 : 0))
        features.append(AgentFeature(key: "repetition", value: Float(state.currentPositionRepetitionCount) / 3))
        features.append(AgentFeature(key: "terminal", value: state.winner == nil && !state.isDraw ? 0 : 1))
        return AgentGameObservation(
            gameKind: .xiangqi,
            gameVersion: adapterVersion,
            stateHash: AgentGameEncoding.stableHash(game: .xiangqi, actor: actor, features: features),
            turn: state.moveCount,
            actor: actor,
            features: features
        )
    }

    func enumerateLegalActions() -> [AgentActionCandidate] {
        guard state.winner == nil, !state.isDraw, state.currentPlayer == actor else { return [] }
        var result: [AgentActionCandidate] = []
        for source in state.board.indices {
            guard let piece = state.piece(at: source) else { continue }
            let owns = actor == .host ? piece.side == .red : piece.side == .black
            guard owns else { continue }
            for destination in state.legalDestinations(from: source, actor: actor) {
                let captured = state.piece(at: destination).map(pieceValue) ?? 0
                result.append(AgentActionCandidate(
                    actionID: "xiangqi:\(source)-\(destination)",
                    encodedAction: AgentGameEncoding.encodeInts([source, destination]),
                    metadata: ["from": "\(source)", "to": "\(destination)"],
                    features: [
                        AgentFeature(key: "from", value: Float(source) / 89),
                        AgentFeature(key: "to", value: Float(destination) / 89),
                        AgentFeature(key: "capture", value: Float(captured) / 7),
                        AgentFeature(key: "piece", value: Float(pieceValue(piece)) / 7)
                    ]
                ))
            }
        }
        return result
    }

    func validate(_ action: AgentActionCandidate) -> Bool {
        enumerateLegalActions().contains(where: { $0.actionID == action.actionID })
    }
}
