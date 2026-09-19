import Foundation

extension TacticalV2 {
    struct WireRecordV2: Hashable {
        let body: String
        let isOutgoing: Bool
        let sentAt: Date
    }

    enum NegotiationStateV2: String, Codable, Hashable {
        case awaitingPeer
        case compatible
        case incompatible
    }

    struct RoundProgressV2: Codable, Hashable {
        let turn: Int32
        let localCommitted: Bool
        let remoteCommitted: Bool
        let localRevealed: Bool
        let remoteRevealed: Bool
        let localDigest: Bool
        let remoteDigest: Bool
    }

    struct ChatSessionSnapshotV2: Hashable {
        let negotiation: NegotiationStateV2
        let state: TruthStateV2
        let frames: [RuntimeFrameV2]
        let replayHash: UInt64
        let currentRound: RoundProgressV2
        let divergenceTurns: Set<Int32>
        let acceptedEnvelopeCount: Int

        var isV2Active: Bool {
            negotiation == .compatible
        }
    }

    enum ChatSessionBuilderV2 {
        static func rebuild(
            sessionID: String,
            hostIsLocal: Bool,
            records: [WireRecordV2],
            map: Map,
            initialState: TruthStateV2
        ) -> ChatSessionSnapshotV2 {
            let localActor: Faction = hostIsLocal ? .cao : .yuan
            let remoteActor: Faction = localActor == .cao ? .yuan : .cao

            let decoded: [(WireRecordV2, WireEnvelopeV2)] = records.compactMap { record in
                guard let envelope = WireCodecV2.decode(record.body),
                      envelope.sessionID == sessionID else {
                    return nil
                }

                let expectedActor: Faction = record.isOutgoing ? localActor : remoteActor
                guard envelope.actor == expectedActor else {
                    return nil
                }
                return (record, envelope)
            }

            let unique = Dictionary(grouping: decoded, by: { $0.1.actionID })
                .values
                .compactMap { duplicates in
                    duplicates.sorted(by: eventOrder).first
                }
                .sorted(by: eventOrder)

            let localHello = unique
                .map(\.1)
                .first { $0.kind == .hello && $0.actor == localActor }?
                .hello
            let remoteHello = unique
                .map(\.1)
                .first { $0.kind == .hello && $0.actor == remoteActor }?
                .hello

            let negotiation: NegotiationStateV2
            if let localHello, let remoteHello {
                negotiation = localHello.isCompatible(with: remoteHello)
                    ? .compatible
                    : .incompatible
            } else {
                negotiation = .awaitingPeer
            }

            var state = initialState
            var frames: [RuntimeFrameV2] = []
            var log = ReplayLogV2(
                scenarioID: initialState.scenarioID,
                mapID: initialState.mapID,
                rulesVersion: initialState.rulesVersion,
                scenarioVersion: initialState.scenarioVersion,
                seed: initialState.seed
            )
            var divergenceTurns = Set<Int32>()

            if negotiation == .compatible {
                var turn: Int32 = 0

                while true {
                    let turnEvents = unique
                        .map(\.1)
                        .filter { $0.turn == turn }

                    let caoCommit = turnEvents
                        .first { $0.kind == .commitment && $0.actor == .cao }?
                        .commitment
                    let yuanCommit = turnEvents
                        .first { $0.kind == .commitment && $0.actor == .yuan }?
                        .commitment
                    let caoReveal = turnEvents
                        .first { $0.kind == .reveal && $0.actor == .cao }?
                        .reveal
                    let yuanReveal = turnEvents
                        .first { $0.kind == .reveal && $0.actor == .yuan }?
                        .reveal

                    guard let caoCommit,
                          let yuanCommit,
                          let caoReveal,
                          let yuanReveal else {
                        break
                    }

                    do {
                        var round = WEGORoundV2(turn: turn)
                        try round.commit(caoCommit)
                        try round.commit(yuanCommit)
                        try round.beginReveal()
                        try round.reveal(caoReveal, map: map)
                        try round.reveal(yuanReveal, map: map)

                        let frame = try WEGOResolverV2.resolve(
                            state: &state,
                            map: map,
                            round: &round
                        )
                        try round.markObserved()
                        try log.append(frame)
                        frames.append(frame)

                        let digest = PrivacyBoundaryV2.digest(frame)
                        var divergedThisTurn = false
                        for envelope in turnEvents where envelope.kind == .frameDigest {
                            if let peerDigest = envelope.frameDigest,
                               peerDigest != digest {
                                divergenceTurns.insert(turn)
                                divergedThisTurn = true
                            }
                        }
                        if divergedThisTurn {
                            break
                        }
                    } catch {
                        divergenceTurns.insert(turn)
                        break
                    }

                    turn += 1
                }
            }

            let currentTurn = state.simulationTurn
            let current = unique.map(\.1).filter { $0.turn == currentTurn }

            return ChatSessionSnapshotV2(
                negotiation: negotiation,
                state: state,
                frames: frames,
                replayHash: log.stableHash64(),
                currentRound: RoundProgressV2(
                    turn: currentTurn,
                    localCommitted: current.contains {
                        $0.kind == .commitment && $0.actor == localActor
                    },
                    remoteCommitted: current.contains {
                        $0.kind == .commitment && $0.actor == remoteActor
                    },
                    localRevealed: current.contains {
                        $0.kind == .reveal && $0.actor == localActor
                    },
                    remoteRevealed: current.contains {
                        $0.kind == .reveal && $0.actor == remoteActor
                    },
                    localDigest: current.contains {
                        $0.kind == .frameDigest && $0.actor == localActor
                    },
                    remoteDigest: current.contains {
                        $0.kind == .frameDigest && $0.actor == remoteActor
                    }
                ),
                divergenceTurns: divergenceTurns,
                acceptedEnvelopeCount: unique.count
            )
        }

        static func hasLocalHello(
            sessionID: String,
            hostIsLocal: Bool,
            records: [WireRecordV2]
        ) -> Bool {
            let localActor: Faction = hostIsLocal ? .cao : .yuan
            return records.contains { record in
                guard record.isOutgoing,
                      let envelope = WireCodecV2.decode(record.body),
                      envelope.sessionID == sessionID else {
                    return false
                }
                return envelope.kind == .hello && envelope.actor == localActor
            }
        }

        private static func eventOrder(
            _ lhs: (WireRecordV2, WireEnvelopeV2),
            _ rhs: (WireRecordV2, WireEnvelopeV2)
        ) -> Bool {
            if lhs.1.turn != rhs.1.turn {
                return lhs.1.turn < rhs.1.turn
            }
            if lhs.1.kind.rawValue != rhs.1.kind.rawValue {
                return lhs.1.kind.rawValue < rhs.1.kind.rawValue
            }
            if lhs.1.createdAt != rhs.1.createdAt {
                return lhs.1.createdAt < rhs.1.createdAt
            }
            if lhs.0.sentAt != rhs.0.sentAt {
                return lhs.0.sentAt < rhs.0.sentAt
            }
            return lhs.1.actionID < rhs.1.actionID
        }
    }
}
