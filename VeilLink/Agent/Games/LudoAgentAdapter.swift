import Foundation

struct LudoAgentAdapter: AgentGameAdapter {
    let state: LudoState
    let actor: MiniGamePlayer
    let sessionID: String

    let gameKind: MiniGameKind = .ludo
    let adapterVersion = "ludo-agent-v1"

    func makeObservation() -> AgentGameObservation {
        var features: [AgentFeature] = []
        let own = state.pieces(for: actor)
        let opponent = state.pieces(for: actor.opponent)
        for (index, progress) in own.enumerated() {
            features.append(AgentFeature(key: "own\(index)", value: Float(progress + 1) / Float(LudoState.finishProgress + 1)))
        }
        for (index, progress) in opponent.enumerated() {
            features.append(AgentFeature(key: "opp\(index)", value: Float(progress + 1) / Float(LudoState.finishProgress + 1)))
        }
        features.append(AgentFeature(key: "dice", value: Float(state.expectedDice(sessionID: sessionID)) / 6))
        features.append(AgentFeature(key: "turn.mine", value: state.currentPlayer == actor ? 1 : 0))
        features.append(AgentFeature(key: "terminal", value: state.winner == nil ? 0 : 1))
        return AgentGameObservation(
            gameKind: .ludo,
            gameVersion: adapterVersion,
            stateHash: AgentGameEncoding.stableHash(game: .ludo, actor: actor, features: features),
            turn: state.turn,
            actor: actor,
            features: features
        )
    }

    func enumerateLegalActions() -> [AgentActionCandidate] {
        guard state.winner == nil, state.currentPlayer == actor else { return [] }
        let legal = state.legalPieces(sessionID: sessionID)
        if legal.isEmpty {
            return [AgentActionCandidate(
                actionID: "ludo:pass",
                encodedAction: AgentGameEncoding.encodeInts([-1]),
                metadata: ["piece": "-1"],
                features: [AgentFeature(key: "pass", value: 1)]
            )]
        }
        let pieces = state.pieces(for: actor)
        return legal.map { index in
            AgentActionCandidate(
                actionID: "ludo:\(index)",
                encodedAction: AgentGameEncoding.encodeInts([index]),
                metadata: ["piece": "\(index)"],
                features: [
                    AgentFeature(key: "piece", value: Float(index) / 3),
                    AgentFeature(key: "progress", value: Float(pieces[index] + 1) / Float(LudoState.finishProgress + 1)),
                    AgentFeature(key: "dice", value: Float(state.expectedDice(sessionID: sessionID)) / 6)
                ]
            )
        }
    }

    func validate(_ action: AgentActionCandidate) -> Bool {
        enumerateLegalActions().contains(where: { $0.actionID == action.actionID })
    }
}
