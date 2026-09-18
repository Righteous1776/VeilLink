import Foundation

struct GomokuAgentAdapter: AgentGameAdapter {
    let state: GomokuState
    let actor: MiniGamePlayer

    let gameKind: MiniGameKind = .gomoku
    let adapterVersion = "gomoku-agent-v1"

    func makeObservation() -> AgentGameObservation {
        var features: [AgentFeature] = []
        features.reserveCapacity(GomokuState.size * GomokuState.size + 3)
        let ownValue: Int8 = actor == .host ? 1 : 2
        for index in 0..<(GomokuState.size * GomokuState.size) {
            let value = state.value(at: index)
            let relative: Float = value == 0 ? 0 : (value == ownValue ? 1 : -1)
            features.append(AgentFeature(key: "c\(index)", value: relative))
        }
        features.append(AgentFeature(key: "turn.mine", value: state.currentPlayer == actor ? 1 : 0))
        features.append(AgentFeature(key: "move.count", value: Float(state.moveCount) / Float(GomokuState.size * GomokuState.size)))
        features.append(AgentFeature(key: "terminal", value: state.winner == nil && !state.isDraw ? 0 : 1))
        return AgentGameObservation(
            gameKind: .gomoku,
            gameVersion: adapterVersion,
            stateHash: AgentGameEncoding.stableHash(game: .gomoku, actor: actor, features: features),
            turn: state.moveCount,
            actor: actor,
            features: features
        )
    }

    func enumerateLegalActions() -> [AgentActionCandidate] {
        guard state.winner == nil, !state.isDraw, state.currentPlayer == actor else { return [] }
        return (0..<(GomokuState.size * GomokuState.size)).compactMap { index in
            guard state.value(at: index) == 0 else { return nil }
            let row = index / GomokuState.size
            let col = index % GomokuState.size
            let center = Float(GomokuState.size - 1) / 2
            let distance = abs(Float(row) - center) + abs(Float(col) - center)
            return AgentActionCandidate(
                actionID: "gomoku:\(index)",
                encodedAction: AgentGameEncoding.encodeInts([index]),
                metadata: ["index": "\(index)"],
                features: [
                    AgentFeature(key: "row", value: Float(row) / 14),
                    AgentFeature(key: "col", value: Float(col) / 14),
                    AgentFeature(key: "centrality", value: max(0, 1 - distance / 14))
                ]
            )
        }
    }

    func validate(_ action: AgentActionCandidate) -> Bool {
        enumerateLegalActions().contains(where: { $0.actionID == action.actionID })
    }
}
