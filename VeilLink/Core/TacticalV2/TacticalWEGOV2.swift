import Foundation

extension TacticalV2 {
    enum WEGORoundPhaseV2: UInt8, Codable, Hashable {
        case planning = 0
        case committed = 1
        case reveal = 2
        case resolving = 3
        case observing = 4
        case complete = 5
    }

    struct CommitmentV2: Codable, Hashable {
        let actor: Faction
        let turn: Int32
        let orderBatchHash: UInt64
        let nonceHash: UInt64
        let commitmentHash: UInt64
    }

    struct RevealV2: Codable, Hashable {
        let actor: Faction
        let turn: Int32
        let batch: OrderBatchV2
        let nonce: UInt64

        func commitment() -> CommitmentV2 {
            let batchHash = batch.stableHash64()
            let nonceHash = StableHash64.fnv1a("nonce|\(nonce)")
            let combined = StableHash64.fnv1a(
                "commit|\(actor.rawValue)|\(turn)|\(batchHash)|\(nonceHash)"
            )
            return CommitmentV2(
                actor: actor,
                turn: turn,
                orderBatchHash: batchHash,
                nonceHash: nonceHash,
                commitmentHash: combined
            )
        }
    }

    enum WEGOErrorV2: Error, Equatable {
        case invalidPhase
        case wrongTurn
        case missingCommitment
        case duplicateCommitment
        case duplicateReveal
        case commitmentMismatch
        case wrongActor
        case invalidOrders
        case unresolvedRound
    }

    struct WEGORoundV2: Codable, Hashable {
        let turn: Int32
        private(set) var phase: WEGORoundPhaseV2 = .planning
        private(set) var commitments: [Faction: CommitmentV2] = [:]
        private(set) var reveals: [Faction: RevealV2] = [:]

        init(turn: Int32) {
            self.turn = turn
        }

        mutating func commit(_ commitment: CommitmentV2) throws {
            guard phase == .planning || phase == .committed else {
                throw WEGOErrorV2.invalidPhase
            }
            guard commitment.turn == turn else { throw WEGOErrorV2.wrongTurn }
            guard commitments[commitment.actor] == nil else {
                throw WEGOErrorV2.duplicateCommitment
            }
            commitments[commitment.actor] = commitment
            phase = commitments.count == 2 ? .committed : .planning
        }

        mutating func beginReveal() throws {
            guard commitments.count == 2 && phase == .committed else {
                throw WEGOErrorV2.missingCommitment
            }
            phase = .reveal
        }

        mutating func reveal(_ reveal: RevealV2, map: Map) throws {
            guard phase == .reveal else { throw WEGOErrorV2.invalidPhase }
            guard reveal.turn == turn else { throw WEGOErrorV2.wrongTurn }
            guard reveals[reveal.actor] == nil else { throw WEGOErrorV2.duplicateReveal }
            guard let expected = commitments[reveal.actor] else {
                throw WEGOErrorV2.missingCommitment
            }

            for order in reveal.batch.orders {
                guard order.actor == reveal.actor else { throw WEGOErrorV2.wrongActor }
                do {
                    try order.validate(map: map)
                } catch {
                    throw WEGOErrorV2.invalidOrders
                }
            }

            let actual = reveal.commitment()
            guard actual.commitmentHash == expected.commitmentHash,
                  actual.orderBatchHash == expected.orderBatchHash,
                  actual.nonceHash == expected.nonceHash else {
                throw WEGOErrorV2.commitmentMismatch
            }

            reveals[reveal.actor] = reveal
            if reveals.count == 2 {
                phase = .resolving
            }
        }

        mutating func markResolved() throws {
            guard phase == .resolving else { throw WEGOErrorV2.invalidPhase }
            phase = .observing
        }

        mutating func markObserved() throws {
            guard phase == .observing else { throw WEGOErrorV2.invalidPhase }
            phase = .complete
        }

        func canonicalOrderBatch() throws -> OrderBatchV2 {
            guard reveals.count == 2 else { throw WEGOErrorV2.unresolvedRound }
            let all = reveals.values
                .flatMap { $0.batch.orders }
            return OrderBatchV2(orders: all)
        }
    }

    enum WEGOResolverV2 {
        static func resolve(
            state: inout TruthStateV2,
            map: Map,
            round: inout WEGORoundV2
        ) throws -> RuntimeFrameV2 {
            guard round.phase == .resolving else { throw WEGOErrorV2.invalidPhase }

            let preHash = state.stableHash64()
            let batch = try round.canonicalOrderBatch()
            let batchHash = batch.stableHash64()
            let sortedOrders = batch.canonicalOrders()

            var events: [RuntimeEventV2] = []
            var sequence: UInt32 = 0

            func appendEvent(
                _ kind: RuntimeEventKindV2,
                actor: Faction?,
                unitID: String?,
                from: Int?,
                to: Int?,
                publicCell: Int?,
                detail: UInt16
            ) {
                events.append(RuntimeEventV2(
                    sequence: sequence,
                    kind: kind,
                    actor: actor,
                    unitID: unitID,
                    fromCell: from,
                    toCell: to,
                    publicCell: publicCell,
                    detailCode: detail
                ))
                sequence &+= 1
            }

            // Deterministic intent table. Each order may advance at most one route segment
            // per resolution tick in V1; long routes persist at a higher command layer later.
            struct Intent {
                let order: OrderV2
                let unitIndex: Int
                let from: Int
                let to: Int
            }

            var intents: [Intent] = []

            for order in sortedOrders {
                if order.kind == .pass {
                    appendEvent(.unitHeld, actor: order.actor, unitID: nil, from: nil, to: nil, publicCell: nil, detail: 10)
                    continue
                }

                guard let unitID = order.unitID,
                      let idx = state.unitIndex(id: unitID) else {
                    appendEvent(.blocked, actor: order.actor, unitID: order.unitID, from: nil, to: nil, publicCell: nil, detail: 20)
                    continue
                }

                let unit = state.units[idx]
                guard unit.faction == order.actor else {
                    appendEvent(.blocked, actor: order.actor, unitID: unitID, from: unit.cell, to: nil, publicCell: unit.cell, detail: 21)
                    continue
                }

                if order.kind == .hold {
                    appendEvent(.unitHeld, actor: order.actor, unitID: unitID, from: unit.cell, to: unit.cell, publicCell: unit.cell, detail: 11)
                    continue
                }

                guard order.routeCells.count >= 2,
                      Int(order.routeCells[0]) == unit.cell else {
                    appendEvent(.blocked, actor: order.actor, unitID: unitID, from: unit.cell, to: nil, publicCell: unit.cell, detail: 22)
                    continue
                }

                let target = Int(order.routeCells[1])
                guard map.neighbors(of: unit.cell).contains(target) else {
                    appendEvent(.blocked, actor: order.actor, unitID: unitID, from: unit.cell, to: target, publicCell: unit.cell, detail: 23)
                    continue
                }

                intents.append(Intent(order: order, unitIndex: idx, from: unit.cell, to: target))
            }

            // Resolve contested destinations deterministically.
            var byTarget: [Int: [Intent]] = [:]
            for intent in intents {
                byTarget[intent.to, default: []].append(intent)
            }

            for target in byTarget.keys.sorted() {
                guard var candidates = byTarget[target] else { continue }

                candidates.sort {
                    if $0.order.actor.rawValue != $1.order.actor.rawValue {
                        return $0.order.actor.rawValue < $1.order.actor.rawValue
                    }
                    return ($0.order.unitID ?? "") < ($1.order.unitID ?? "")
                }

                let currentOccupant = state.units.first {
                    $0.steps > 0 && $0.cell == target
                }

                if candidates.count == 1 {
                    let intent = candidates[0]
                    if let occupant = currentOccupant,
                       occupant.id != state.units[intent.unitIndex].id {
                        appendEvent(.contact, actor: intent.order.actor, unitID: intent.order.unitID,
                                    from: intent.from, to: intent.to, publicCell: target, detail: 30)
                        continue
                    }

                    state.units[intent.unitIndex].cell = target
                    appendEvent(.unitAdvanced, actor: intent.order.actor, unitID: intent.order.unitID,
                                from: intent.from, to: target, publicCell: target, detail: 0)
                    continue
                }

                // Multiple intents entering same empty/contested cell: deterministic tie-break
                // only decides who advances in this prototype. No combat result is invented here.
                let salt = StableHash64.fnv1a("contest|\(target)|\(round.turn)|\(batchHash)")
                let pick = Int(DeterministicRNGV2.bounded(
                    seed: state.seed,
                    index: state.rngIndex,
                    upperBound: UInt64(candidates.count),
                    salt: salt
                ))
                state.rngIndex &+= 1

                for (i, intent) in candidates.enumerated() {
                    if i == pick && currentOccupant == nil {
                        state.units[intent.unitIndex].cell = target
                        appendEvent(.unitAdvanced, actor: intent.order.actor, unitID: intent.order.unitID,
                                    from: intent.from, to: target, publicCell: target, detail: 1)
                    } else {
                        appendEvent(.contact, actor: intent.order.actor, unitID: intent.order.unitID,
                                    from: intent.from, to: intent.to, publicCell: target, detail: 31)
                    }
                }
            }

            state.simulationTurn &+= 1
            state.revision = Revision(
                map: state.revision.map,
                terrain: state.revision.terrain,
                unit: state.revision.unit &+ 1,
                supply: state.revision.supply &+ 1
            )

            appendEvent(.turnResolved, actor: nil, unitID: nil, from: nil, to: nil, publicCell: nil, detail: 100)

            let postHash = state.stableHash64()
            try round.markResolved()

            return RuntimeFrameV2(
                preStateHash: preHash,
                orderBatchHash: batchHash,
                events: events,
                postStateHash: postHash,
                resolvedTurn: round.turn
            )
        }
    }
}
