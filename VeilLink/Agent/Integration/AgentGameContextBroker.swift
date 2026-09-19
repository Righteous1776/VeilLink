import Combine
import Foundation

@MainActor
final class AgentGameContextBroker: ObservableObject {
    @Published private(set) var context: AgentGameContext?

    private let maleCNS: MaleCNSGraphManager
    private let controls: AgentControlCenterSettings
    private let policyRuntime: TrainedGamePolicyRuntime?
    private var suggestedAction: AgentSuggestedGameAction?
    private var probeTask: Task<Void, Never>?
    private var lastExecutedStateAction: String?
    private var lastSession: MiniGameSessionSnapshot?
    private var lastConversationTitle: String?
    private var lastPeerIdentityID: String?

    init(maleCNS: MaleCNSGraphManager, controls: AgentControlCenterSettings) {
        self.maleCNS = maleCNS
        self.controls = controls
        policyRuntime = try? TrainedGamePolicyRuntime.loadBundled()
    }

    func update(
        session: MiniGameSessionSnapshot,
        conversationTitle: String,
        peerIdentityID: String
    ) {
        probeTask?.cancel()
        suggestedAction = nil
        lastSession = session
        lastConversationTitle = conversationTitle
        lastPeerIdentityID = peerIdentityID

        let status = Self.statusText(session.status)
        let localPlayer = session.localPlayer
        let capturedAt = Date()

        guard let adapter = Self.adapter(for: session) else {
            let tacticalHash = "tactical:\(session.id):\(session.moveCount):\(status)"
            context = AgentGameContext(
                capturedAt: capturedAt,
                sessionID: session.id,
                gameID: session.game.rawValue,
                gameTitle: session.game.title,
                conversationTitle: conversationTitle,
                peerIdentityID: peerIdentityID,
                status: status,
                stateHash: tacticalHash,
                turn: session.moveCount,
                localPlayer: localPlayer.rawValue,
                isLocalTurn: session.isLocalTurn,
                policyMode: "high-level-only",
                stateDescription: Self.stateDescription(for: session),
                recommendations: [],
                note: AgentGameRegistry.exclusionReason(for: session.game) ?? "No trained policy is available for this game.",
                maleCNS: nil
            )
            return
        }

        let observation = adapter.makeObservation()
        let legal = adapter.enumerateLegalActions().filter(adapter.validate)
        let rankedScores: [AgentActionScore]
        if AgentGameRegistry.isTrainingEnabled(session.game), let policyRuntime {
            rankedScores = (try? policyRuntime.rankedLegalActions(adapter: adapter)) ?? []
        } else {
            rankedScores = []
        }
        let scoreByID = Dictionary(uniqueKeysWithValues: rankedScores.map { ($0.actionID, $0.score) })
        let ordered: [AgentActionCandidate]
        if rankedScores.isEmpty {
            ordered = legal.sorted { $0.actionID < $1.actionID }
        } else {
            let rank = Dictionary(uniqueKeysWithValues: rankedScores.enumerated().map { ($0.element.actionID, $0.offset) })
            ordered = legal.sorted {
                (rank[$0.actionID] ?? Int.max) < (rank[$1.actionID] ?? Int.max)
            }
        }

        let recommendations = ordered.prefix(4).map { candidate in
            AgentGameRecommendation(
                actionID: candidate.actionID,
                label: Self.label(for: candidate, game: session.game),
                score: scoreByID[candidate.actionID],
                metadata: candidate.metadata
            )
        }

        context = AgentGameContext(
            capturedAt: capturedAt,
            sessionID: session.id,
            gameID: session.game.rawValue,
            gameTitle: session.game.title,
            conversationTitle: conversationTitle,
            peerIdentityID: peerIdentityID,
            status: status,
            stateHash: observation.stateHash,
            turn: session.moveCount,
            localPlayer: localPlayer.rawValue,
            isLocalTurn: session.isLocalTurn,
            policyMode: rankedScores.isEmpty ? "legal-state-only" : "trained-candidate-ranker",
            stateDescription: Self.stateDescription(for: session),
            recommendations: recommendations,
            note: rankedScores.isEmpty && AgentGameRegistry.isTrainingEnabled(session.game)
                ? "The bundled game policy could not be loaded; no move is auto-recommended."
                : nil,
            maleCNS: nil
        )

        if session.isLocalTurn, !rankedScores.isEmpty,
           let best = ordered.first,
           let move = Self.move(for: best, game: session.game) {
            let key = "\(observation.stateHash)|\(best.actionID)"
            if key != lastExecutedStateAction {
                suggestedAction = AgentSuggestedGameAction(
                    sessionID: session.id,
                    peerIdentityID: peerIdentityID,
                    gameID: session.game.rawValue,
                    gameTitle: session.game.title,
                    turn: session.moveCount,
                    move: move,
                    actionID: best.actionID,
                    label: Self.label(for: best, game: session.game)
                )
            }
            if controls.gameDecisionMode.usesMaleCNSRerank {
                scheduleMaleCNSDecisionRerank(
                    stateHash: observation.stateHash,
                    session: session,
                    candidates: Array(ordered.prefix(3))
                )
            } else if var current = context {
                current.policyMode = current.policyMode + "+user-baseline-only"
                current.note = "MaleCNS game rerank is disabled in AI Control Center. The stable baseline policy remains active."
                context = current
            }
        }
    }

    func clear(sessionID: String? = nil) {
        if let sessionID, context?.sessionID != sessionID { return }
        probeTask?.cancel()
        probeTask = nil
        context = nil
        suggestedAction = nil
        lastSession = nil
        lastConversationTitle = nil
        lastPeerIdentityID = nil
    }

    func reconfigure() {
        guard let session = lastSession,
              let conversationTitle = lastConversationTitle,
              let peerIdentityID = lastPeerIdentityID else { return }
        update(session: session, conversationTitle: conversationTitle, peerIdentityID: peerIdentityID)
    }

    func currentSuggestedAction(maximumAge: TimeInterval = 25) -> AgentSuggestedGameAction? {
        guard let context, context.isLocalTurn,
              Date().timeIntervalSince(context.capturedAt) <= maximumAge else { return nil }
        return suggestedAction
    }

    func markSuggestedActionExecuted(_ action: AgentSuggestedGameAction) {
        guard let context else { return }
        lastExecutedStateAction = "\(context.stateHash)|\(action.actionID)"
        suggestedAction = nil
    }

    var hasCurrentGame: Bool { context != nil }

    private func scheduleMaleCNSDecisionRerank(
        stateHash: String,
        session: MiniGameSessionSnapshot,
        candidates: [AgentActionCandidate]
    ) {
        guard !candidates.isEmpty, controls.gameDecisionMode.usesMaleCNSRerank else { return }
        maleCNS.prepareFromBundle()
        probeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<20 {
                guard !Task.isCancelled else { return }
                if case .ready = self.maleCNS.state { break }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            guard !Task.isCancelled,
                  case .ready(let profile) = self.maleCNS.state else { return }

            do {
                let ranker = try MaleCNSGameRankerModel.loadBundled(
                    for: profile.tier,
                    allowExperimental: self.controls.gameDecisionMode.allowsExperimentalRanker
                )
                try ranker.validate(profile: profile)
                var scored: [(AgentActionCandidate, Float, MaleCNSNativeEpisodeReadoutResult, [Float])] = []
                scored.reserveCapacity(candidates.count)
                for candidate in candidates {
                    guard !Task.isCancelled,
                          let task = MaleCNSGameDecisionEncoder.taskVector(session: session, candidate: candidate),
                          let channels = MaleCNSGameDecisionEncoder.channels(task: task, game: session.game) else { continue }
                    let episode = try await self.maleCNS.runGameChannels(channels, requestedSteps: 6)
                    let result = try ranker.score(game: session.game, stimulus: channels, episode: episode)
                    scored.append((candidate, result.score, episode, channels))
                }
                guard !Task.isCancelled, !scored.isEmpty else { return }
                scored.sort {
                    if $0.1 == $1.1 { return $0.0.actionID < $1.0.actionID }
                    return $0.1 > $1.1
                }
                guard var current = self.context, current.stateHash == stateHash else { return }
                current.policyMode = self.controls.gameDecisionMode == .experimentalCore
                    ? "trained-candidate-ranker+malecns-r7-core-experimental"
                    : "trained-candidate-ranker+malecns-r7-residual"
                current.recommendations = scored.prefix(4).map { item in
                    AgentGameRecommendation(
                        actionID: item.0.actionID,
                        label: Self.label(for: item.0, game: session.game),
                        score: item.1,
                        metadata: item.0.metadata
                    )
                }
                current.note = self.controls.gameDecisionMode == .experimentalCore
                    ? "R8 manual experimental Core authorization is active. R7 Core residual ranker is still small-sample and only reranks baseline Top-3 legal candidates; the game engine remains authoritative."
                    : "R7 MaleCNS residual rerank is limited to baseline Top-3 legal candidates. The original game engine remains authoritative."
                if let best = scored.first {
                    let pairs = zip(best.2.readout.names, best.2.readout.spikeCounts)
                        .filter { $0.1 > 0 }
                        .sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0 < rhs.0 : lhs.1 > rhs.1 }
                        .prefix(4)
                        .map { "\($0.0)=\($0.1)" }
                    current.maleCNS = AgentMaleCNSContext(
                        stimulusLabel: "game-r7-8ch-residual score=\(String(format: "%.4f", best.1))",
                        executedSteps: best.2.summary.executedSteps,
                        totalSpikeCount: best.2.summary.totalSpikeCount,
                        topReadouts: Array(pairs),
                        learnedLabel: "game-ranker-r7",
                        learnedConfidence: nil
                    )
                    if session.isLocalTurn,
                       let move = Self.move(for: best.0, game: session.game) {
                        let key = "\(stateHash)|\(best.0.actionID)"
                        if key != self.lastExecutedStateAction {
                            self.suggestedAction = AgentSuggestedGameAction(
                                sessionID: session.id,
                                peerIdentityID: current.peerIdentityID,
                                gameID: session.game.rawValue,
                                gameTitle: session.game.title,
                                turn: session.moveCount,
                                move: move,
                                actionID: best.0.actionID,
                                label: Self.label(for: best.0, game: session.game)
                            )
                        }
                    }
                }
                self.context = current
            } catch {
                // Core R7 is deliberately guarded until its validation set is larger. If no
                // deployable ranker exists, keep the stable baseline recommendation and run only
                // the older single-candidate probe for auxiliary context.
                guard let best = candidates.first,
                      let stimulus = Self.stimulus(for: best, game: session.game) else { return }
                do {
                    let result = try await self.maleCNS.runProbe(stimulus.value, requestedSteps: 6)
                    guard !Task.isCancelled, var current = self.context, current.stateHash == stateHash else { return }
                    let pairs = zip(result.readout.names, result.readout.spikeCounts)
                        .filter { $0.1 > 0 }
                        .sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0 < rhs.0 : lhs.1 > rhs.1 }
                        .prefix(4)
                        .map { "\($0.0)=\($0.1)" }
                    let learned = self.maleCNS.lastLearnedReadout
                    current.maleCNS = AgentMaleCNSContext(
                        stimulusLabel: stimulus.label,
                        executedSteps: result.summary.executedSteps,
                        totalSpikeCount: result.summary.totalSpikeCount,
                        topReadouts: Array(pairs),
                        learnedLabel: learned?.label,
                        learnedConfidence: learned?.confidence
                    )
                    current.note = (current.note.map { $0 + " " } ?? "") + "R7 game residual ranker unavailable for this graph tier; baseline policy retained."
                    self.context = current
                } catch {
                    DiagnosticLogStore.shared.log(
                        .warning, .agent,
                        event: "agent.game.malecns_r7.failed",
                        message: error.localizedDescription,
                        metadata: ["game": session.game.rawValue, "tier": profile.tier.rawValue]
                    )
                }
            }
        }
    }

    private static func adapter(for session: MiniGameSessionSnapshot) -> (any AgentGameAdapter)? {
        switch session.game {
        case .gomoku:
            guard let state = session.gomoku else { return nil }
            return GomokuAgentAdapter(state: state, actor: session.localPlayer)
        case .xiangqi:
            guard let state = session.xiangqi else { return nil }
            return XiangqiAgentAdapter(state: state, actor: session.localPlayer)
        case .ludo:
            guard let state = session.ludo else { return nil }
            return LudoAgentAdapter(state: state, actor: session.localPlayer, sessionID: session.id)
        case .tactical:
            return nil
        }
    }

    private static func stateDescription(for session: MiniGameSessionSnapshot) -> String {
        switch session.game {
        case .gomoku:
            guard let state = session.gomoku else { return "gomoku_state=missing" }
            let ownValue: Int8 = session.localPlayer == .host ? 1 : 2
            let rows = (0..<GomokuState.size).map { row in
                (0..<GomokuState.size).map { col -> Character in
                    let value = state.value(at: row * GomokuState.size + col)
                    if value == 0 { return "." }
                    return value == ownValue ? "X" : "O"
                }.reduce(into: "") { $0.append($1) }
            }
            return "X=local,O=opponent; board_rows=" + rows.joined(separator: "/")
        case .xiangqi:
            guard let state = session.xiangqi else { return "xiangqi_state=missing" }
            let ownSide: XiangqiSide = session.localPlayer == .host ? .red : .black
            func code(_ piece: XiangqiPiece?) -> Character {
                guard let piece else { return "." }
                let raw: Character
                switch piece.kind {
                case .general: raw = "G"
                case .advisor: raw = "A"
                case .elephant: raw = "E"
                case .horse: raw = "H"
                case .rook: raw = "R"
                case .cannon: raw = "C"
                case .soldier: raw = "S"
                }
                if piece.side == ownSide { return raw }
                return Character(String(raw).lowercased())
            }
            let rows = (0..<XiangqiState.rows).map { row in
                (0..<XiangqiState.columns).map { col in
                    code(state.piece(at: row * XiangqiState.columns + col))
                }.reduce(into: "") { $0.append($1) }
            }
            return "uppercase=local,lowercase=opponent; board_rows=" + rows.joined(separator: "/") + "; local_check=\(state.isInCheck(player: session.localPlayer)); opponent_check=\(state.isInCheck(player: session.localPlayer.opponent))"
        case .ludo:
            guard let state = session.ludo else { return "ludo_state=missing" }
            let own = state.pieces(for: session.localPlayer).map(String.init).joined(separator: ",")
            let opp = state.pieces(for: session.localPlayer.opponent).map(String.init).joined(separator: ",")
            let legal = state.currentPlayer == session.localPlayer ? state.legalPieces(sessionID: session.id).map(String.init).joined(separator: ",") : ""
            return "own_progress=[\(own)]; opponent_progress=[\(opp)]; next_dice=\(state.expectedDice(sessionID: session.id)); legal_local_pieces=[\(legal)]"
        case .tactical:
            return "tactical_turn=\(session.moveCount); trained_policy=unavailable; use high-level explanation only"
        }
    }

    private static func label(for candidate: AgentActionCandidate, game: MiniGameKind) -> String {
        switch game {
        case .gomoku:
            if let raw = candidate.metadata["index"], let index = Int(raw) {
                return "落子 \(index / GomokuState.size + 1)行\(index % GomokuState.size + 1)列"
            }
        case .xiangqi:
            if let a = candidate.metadata["from"].flatMap(Int.init),
               let b = candidate.metadata["to"].flatMap(Int.init) {
                return "\(a / XiangqiState.columns + 1)行\(a % XiangqiState.columns + 1)列 → \(b / XiangqiState.columns + 1)行\(b % XiangqiState.columns + 1)列"
            }
        case .ludo:
            if let raw = candidate.metadata["piece"], let piece = Int(raw) {
                return piece < 0 ? "无合法棋子，跳过" : "移动第 \(piece + 1) 枚棋子"
            }
        case .tactical:
            break
        }
        return candidate.actionID
    }

    private static func move(for candidate: AgentActionCandidate, game: MiniGameKind) -> MiniGameMove? {
        switch game {
        case .gomoku:
            guard let value = candidate.metadata["index"].flatMap(Int.init) else { return nil }
            return .gomoku(index: value)
        case .xiangqi:
            guard let from = candidate.metadata["from"].flatMap(Int.init),
                  let to = candidate.metadata["to"].flatMap(Int.init) else { return nil }
            return .xiangqi(from: from, to: to)
        case .ludo:
            guard let piece = candidate.metadata["piece"].flatMap(Int.init) else { return nil }
            return .ludo(piece: piece)
        case .tactical:
            return nil
        }
    }

    private static func stimulus(
        for candidate: AgentActionCandidate,
        game: MiniGameKind
    ) -> (value: MaleCNSStimulus, label: String)? {
        let side: MaleCNSSide
        switch game {
        case .gomoku:
            guard let index = candidate.metadata["index"].flatMap(Int.init) else { return nil }
            side = index % GomokuState.size < GomokuState.size / 2 ? .left : .right
            return (.smallApproach(side: side, strength: 0.55), "game-spatial-small-approach-\(side.rawValue)")
        case .xiangqi:
            guard let destination = candidate.metadata["to"].flatMap(Int.init) else { return nil }
            side = destination % XiangqiState.columns < XiangqiState.columns / 2 ? .left : .right
            return (.chaseTarget(side: side, strength: 0.60), "game-spatial-chase-\(side.rawValue)")
        case .ludo:
            guard let piece = candidate.metadata["piece"].flatMap(Int.init), piece >= 0 else { return nil }
            side = piece < 2 ? .left : .right
            return (.looming(side: side, strength: 0.45), "game-piece-looming-\(side.rawValue)")
        case .tactical:
            return nil
        }
    }

    private static func statusText(_ status: MiniGameSessionStatus) -> String {
        switch status {
        case .invited: return "invited"
        case .active: return "active"
        case .declined: return "declined"
        case .cancelled: return "cancelled"
        case .finished(let winner): return winner.map { "finished_winner_\($0.rawValue)" } ?? "finished_draw"
        }
    }
}
