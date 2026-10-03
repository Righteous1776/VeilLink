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
            let enemyCommand = enemy.first { $0.kind == .command }
            let enemySupply = enemy.first { $0.kind == .supply }

            struct Candidate {
                let unit: Unit
                let target: Unit
                let route: RoutePlanV2
                let score: Int64
            }

            var best: Candidate?

            for unit in friendly {
                // Keep the logistics tail conservative. It may still move when every
                // combat formation is blocked, but it should not lead the offensive.
                let targetPreference: [Unit]
                switch unit.kind {
                case .cavalry:
                    targetPreference = [enemySupply, enemyCommand]
                        .compactMap { $0 } + enemy
                case .ranged:
                    targetPreference = enemy.sorted {
                        map.distance(unit.cell, $0.cell) < map.distance(unit.cell, $1.cell)
                    }
                case .infantry:
                    targetPreference = [enemyCommand, enemySupply]
                        .compactMap { $0 } + enemy
                case .command:
                    targetPreference = [enemyCommand].compactMap { $0 } + enemy
                case .supply:
                    targetPreference = [enemySupply].compactMap { $0 } + enemy
                }

                var seenTargets = Set<String>()
                for target in targetPreference where seenTargets.insert(target.id).inserted {
                    var blocked = friendlyOccupied
                    blocked.remove(unit.cell)

                    guard let route = RoutePlannerV2.plan(
                        map: map,
                        from: unit.cell,
                        to: target.cell,
                        blocked: blocked,
                        maxExpandedNodes: 2_048
                    ), route.cells.count >= 2 else {
                        continue
                    }

                    let strategicTargetBonus: Int64
                    switch target.kind {
                    case .command: strategicTargetBonus = -85_000
                    case .supply: strategicTargetBonus = -62_000
                    case .ranged: strategicTargetBonus = -28_000
                    case .cavalry: strategicTargetBonus = -24_000
                    case .infantry: strategicTargetBonus = -20_000
                    }

                    let roleBias: Int64
                    switch unit.kind {
                    case .cavalry: roleBias = -18_000
                    case .infantry: roleBias = -11_000
                    case .ranged: roleBias = -8_000
                    case .command: roleBias = 8_000
                    case .supply: roleBias = 26_000
                    }

                    let firstStep = route.cells[1]
                    let roadBonus: Int64 = map.cell(firstStep)?.road == true ? -4_000 : 0
                    let score = route.totalCostMilli
                        + strategicTargetBonus
                        + roleBias
                        + roadBonus
                        + Int64(firstStep)

                    let candidate = Candidate(
                        unit: unit,
                        target: target,
                        route: route,
                        score: score
                    )
                    if best == nil || candidate.score < best!.score {
                        best = candidate
                    }

                    // The first viable preferred target is enough for this formation;
                    // later fallback targets are intentionally lower priority.
                    break
                }
            }

            guard let best, best.route.cells.count >= 2 else {
                return passOrder(actor: actor, turn: state.simulationTurn)
            }

            let next = best.route.cells[1]
            let enemyOccupiesNext = enemy.contains { $0.cell == next }
            let kind: OrderKindV2
            if enemyOccupiesNext {
                kind = .attack
            } else if best.unit.kind == .cavalry && best.target.kind == .supply {
                kind = .probe
            } else {
                kind = .march
            }

            return OrderV2(
                id: "solo-bot-\(state.simulationTurn)-\(best.unit.id)-\(next)",
                kind: kind,
                actor: actor,
                issuedTurn: state.simulationTurn,
                unitID: best.unit.id,
                routeCells: [UInt16(best.unit.cell), UInt16(next)]
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
