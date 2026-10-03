import Foundation

extension TacticalV2 {
    enum SoloRuntimeErrorV2: Error, Equatable {
        case wrongHumanActor
        case wrongTurn
    }

    struct SoloTurnResultV2 {
        let state: TruthStateV2
        let frame: RuntimeFrameV2
        let botOrder: OrderV2
    }

    enum SoloRuntimeV2 {
        static func resolveTurn(
            state: TruthStateV2,
            map: Map,
            humanOrder: OrderV2
        ) throws -> SoloTurnResultV2 {
            guard humanOrder.actor == .cao else {
                throw SoloRuntimeErrorV2.wrongHumanActor
            }
            guard humanOrder.issuedTurn == state.simulationTurn else {
                throw SoloRuntimeErrorV2.wrongTurn
            }

            try humanOrder.validate(map: map)
            let botOrder = makeBotOrder(
                state: state,
                map: map,
                actor: .yuan
            )

            let humanReveal = RevealV2(
                actor: .cao,
                turn: state.simulationTurn,
                batch: OrderBatchV2(orders: [humanOrder]),
                nonce: StableHash64.fnv1a(
                    "solo-cao|\(state.seed)|\(state.simulationTurn)|\(humanOrder.stableHash64())"
                )
            )
            let botReveal = RevealV2(
                actor: .yuan,
                turn: state.simulationTurn,
                batch: OrderBatchV2(orders: [botOrder]),
                nonce: StableHash64.fnv1a(
                    "solo-yuan|\(state.seed)|\(state.simulationTurn)|\(botOrder.stableHash64())"
                )
            )

            var round = WEGORoundV2(turn: state.simulationTurn)
            try round.commit(humanReveal.commitment())
            try round.commit(botReveal.commitment())
            try round.beginReveal()
            try round.reveal(humanReveal, map: map)
            try round.reveal(botReveal, map: map)

            var next = state
            let frame = try WEGOResolverV2.resolve(
                state: &next,
                map: map,
                round: &round
            )
            try round.markObserved()

            return SoloTurnResultV2(
                state: next,
                frame: frame,
                botOrder: botOrder
            )
        }

        static func makeBotOrder(
            state: TruthStateV2,
            map: Map,
            actor: Faction
        ) -> OrderV2 {
            let friendly = state.units
                .filter { $0.faction == actor && $0.steps > 0 }
                .sorted { $0.id < $1.id }
            let enemy = state.units
                .filter { $0.faction != actor && $0.steps > 0 }
                .sorted { $0.id < $1.id }

            guard !friendly.isEmpty, !enemy.isEmpty else {
                return passOrder(actor: actor, turn: state.simulationTurn)
            }

            let friendlyOccupied = Set(friendly.map(\.cell))
            var best: (unit: Unit, target: Int, score: Int)?

            for unit in friendly {
                for target in map.neighbors(of: unit.cell) {
                    if friendlyOccupied.contains(target) { continue }
                    let distance = enemy
                        .map { map.distance(target, $0.cell) }
                        .min() ?? Int.max / 8
                    let cell = map.cell(target)
                    let movement = Int(cell?.movementCostMilli ?? 1000)
                    let roadBonus = cell?.road == true ? -220 : 0
                    let kindBias: Int
                    switch unit.kind {
                    case .cavalry: kindBias = -90
                    case .infantry: kindBias = -50
                    case .ranged: kindBias = -25
                    case .command: kindBias = 40
                    case .supply: kindBias = 120
                    }
                    let score = distance * 10_000 + movement + roadBonus + kindBias + target
                    if best == nil || score < best!.score {
                        best = (unit, target, score)
                    }
                }
            }

            guard let best else {
                return passOrder(actor: actor, turn: state.simulationTurn)
            }

            let enemyOccupiesTarget = enemy.contains { $0.cell == best.target }
            return OrderV2(
                id: "solo-bot-\(state.simulationTurn)-\(best.unit.id)-\(best.target)",
                kind: enemyOccupiesTarget ? .attack : .march,
                actor: actor,
                issuedTurn: state.simulationTurn,
                unitID: best.unit.id,
                routeCells: [UInt16(best.unit.cell), UInt16(best.target)]
            )
        }

        private static func passOrder(
            actor: Faction,
            turn: Int32
        ) -> OrderV2 {
            OrderV2(
                id: "solo-pass-\(actor.rawValue)-\(turn)",
                kind: .pass,
                actor: actor,
                issuedTurn: turn,
                unitID: nil,
                routeCells: []
            )
        }
    }
}
