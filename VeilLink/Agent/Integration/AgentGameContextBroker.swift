import Combine
import Foundation

@MainActor
final class AgentGameContextBroker: ObservableObject {
    @Published private(set) var context: AgentGameContext?

    private var suggestedAction: AgentSuggestedGameAction?
    private var recommendationTask: Task<Void, Never>?
    private var lastExecutedStateAction: String?
    private var lastSession: MiniGameSessionSnapshot?
    private var lastConversationTitle: String?
    private var lastPeerIdentityID: String?

    // R4 Core is source-isolated from MaleCNS and trained-policy implementations.
    init() {}

    func update(
        session: MiniGameSessionSnapshot,
        conversationTitle: String,
        peerIdentityID: String
    ) {
        recommendationTask?.cancel()
        recommendationTask = nil
        suggestedAction = nil
        lastSession = session
        lastConversationTitle = conversationTitle
        lastPeerIdentityID = peerIdentityID

        let status = Self.statusText(session.status)
        let capturedAt = Date()
        let localPlayer = session.localPlayer

        guard let adapter = Self.adapter(for: session) else {
            context = AgentGameContext(
                capturedAt: capturedAt,
                sessionID: session.id,
                gameID: session.game.rawValue,
                gameTitle: session.game.title,
                conversationTitle: conversationTitle,
                peerIdentityID: peerIdentityID,
                status: status,
                stateHash: "tactical:\(session.id):\(session.moveCount):\(status)",
                turn: session.moveCount,
                localPlayer: localPlayer.rawValue,
                isLocalTurn: session.isLocalTurn,
                policyMode: "high-level-only",
                stateDescription: Self.stateDescription(for: session),
                recommendations: [],
                note: "三国兵棋当前只提供局面摘要；TacticalBot 在后续专项迭代中接入。",
                maleCNS: nil
            )
            return
        }

        let stateHash = adapter.makeObservation().stateHash
        context = AgentGameContext(
            capturedAt: capturedAt,
            sessionID: session.id,
            gameID: session.game.rawValue,
            gameTitle: session.game.title,
            conversationTitle: conversationTitle,
            peerIdentityID: peerIdentityID,
            status: status,
            stateHash: stateHash,
            turn: session.moveCount,
            localPlayer: localPlayer.rawValue,
            isLocalTurn: session.isLocalTurn,
            policyMode: "native-bot",
            stateDescription: Self.stateDescription(for: session),
            recommendations: [],
            note: session.isLocalTurn ? "正在使用原生规则 Bot 计算建议着法。" : "等待对方行动；Core 不运行神经策略模型。",
            maleCNS: nil
        )

        guard session.status == .active, session.isLocalTurn else { return }
        scheduleNativeRecommendation(
            session: session,
            stateHash: stateHash,
            conversationTitle: conversationTitle,
            peerIdentityID: peerIdentityID
        )
    }

    func clear(sessionID: String? = nil) {
        if let sessionID, context?.sessionID != sessionID { return }
        recommendationTask?.cancel()
        recommendationTask = nil
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

    func currentSuggestedAction(
        validating session: MiniGameSessionSnapshot,
        maximumAge: TimeInterval = 25
    ) -> AgentSuggestedGameAction? {
        guard let action = currentSuggestedAction(maximumAge: maximumAge),
              let context,
              context.sessionID == session.id,
              let adapter = Self.adapter(for: session),
              adapter.makeObservation().stateHash == context.stateHash,
              Self.suggestedActionRemainsLegal(action, in: session) else {
            return nil
        }
        return action
    }

    static func suggestedActionRemainsLegal(
        _ action: AgentSuggestedGameAction,
        in session: MiniGameSessionSnapshot
    ) -> Bool {
        guard session.status == .active,
              session.isLocalTurn,
              action.sessionID == session.id,
              action.gameID == session.game.rawValue,
              action.turn == session.moveCount,
              let adapter = Self.adapter(for: session) else {
            return false
        }

        return adapter.enumerateLegalActions()
            .filter(adapter.validate)
            .contains { candidate in
                Self.move(for: candidate, game: session.game) == action.move
            }
    }

    func markSuggestedActionExecuted(_ action: AgentSuggestedGameAction) {
        guard let context else { return }
        lastExecutedStateAction = "\(context.stateHash)|\(action.actionID)"
        suggestedAction = nil
    }

    var hasCurrentGame: Bool { context != nil }

    private func scheduleNativeRecommendation(
        session: MiniGameSessionSnapshot,
        stateHash: String,
        conversationTitle: String,
        peerIdentityID: String
    ) {
        let game = session.game
        let localPlayer = session.localPlayer
        let sessionID = session.id
        let turn = session.moveCount

        switch game {
        case .gomoku:
            guard let state = session.gomoku else { return }
            let budget = GomokuBotBudget.standard(profileLabel: VeilDevicePerformance.current.label)
            recommendationTask = Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .utility) {
                    GomokuBot.chooseMove(in: state, for: localPlayer, budget: budget)
                }.value
                guard !Task.isCancelled, let result else { return }
                self?.publish(
                    candidate: AgentActionCandidate(
                        actionID: "gomoku:\(result.index)",
                        encodedAction: AgentGameEncoding.encodeInts([result.index]),
                        metadata: ["index": String(result.index), "score": String(result.score), "nodes": String(result.nodes)],
                        features: []
                    ),
                    score: Float(result.score),
                    sessionID: sessionID,
                    game: game,
                    turn: turn,
                    stateHash: stateHash,
                    peerIdentityID: peerIdentityID
                )
            }

        case .xiangqi:
            guard let state = session.xiangqi else { return }
            let budget = XiangqiBotBudget.standard(profileLabel: VeilDevicePerformance.current.label)
            recommendationTask = Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .utility) {
                    XiangqiBot.chooseMove(in: state, for: localPlayer, budget: budget)
                }.value
                guard !Task.isCancelled, let result else { return }
                self?.publish(
                    candidate: AgentActionCandidate(
                        actionID: "xiangqi:\(result.from):\(result.to)",
                        encodedAction: AgentGameEncoding.encodeInts([result.from, result.to]),
                        metadata: [
                            "from": String(result.from), "to": String(result.to),
                            "score": String(result.score), "depth": String(result.completedDepth), "nodes": String(result.nodes)
                        ],
                        features: []
                    ),
                    score: Float(result.score),
                    sessionID: sessionID,
                    game: game,
                    turn: turn,
                    stateHash: stateHash,
                    peerIdentityID: peerIdentityID
                )
            }

        case .ludo:
            guard let state = session.ludo else { return }
            recommendationTask = Task { @MainActor [weak self] in
                let result = await Task.detached(priority: .utility) {
                    LudoBot.chooseMove(in: state, for: localPlayer, sessionID: sessionID)
                }.value
                guard !Task.isCancelled, let result else { return }
                self?.publish(
                    candidate: AgentActionCandidate(
                        actionID: "ludo:\(result.pieceIndex)",
                        encodedAction: AgentGameEncoding.encodeInts([result.pieceIndex]),
                        metadata: ["piece": String(result.pieceIndex), "score": String(result.score)],
                        features: []
                    ),
                    score: Float(result.score),
                    sessionID: sessionID,
                    game: game,
                    turn: turn,
                    stateHash: stateHash,
                    peerIdentityID: peerIdentityID
                )
            }

        case .tactical:
            break
        }
        _ = conversationTitle
    }

    private func publish(
        candidate: AgentActionCandidate,
        score: Float,
        sessionID: String,
        game: MiniGameKind,
        turn: Int,
        stateHash: String,
        peerIdentityID: String
    ) {
        guard var current = context,
              current.sessionID == sessionID,
              current.stateHash == stateHash,
              current.turn == turn,
              current.isLocalTurn,
              let move = Self.move(for: candidate, game: game) else { return }

        current.policyMode = "native-bot"
        current.recommendations = [AgentGameRecommendation(
            actionID: candidate.actionID,
            label: Self.label(for: candidate, game: game),
            score: score,
            metadata: candidate.metadata
        )]
        current.note = "建议来自 Core 原生规则 Bot；合法性仍由游戏规则引擎最终校验。"
        current.maleCNS = nil
        context = current

        let key = "\(stateHash)|\(candidate.actionID)"
        guard key != lastExecutedStateAction else { return }
        suggestedAction = AgentSuggestedGameAction(
            sessionID: sessionID,
            peerIdentityID: peerIdentityID,
            gameID: game.rawValue,
            gameTitle: game.title,
            turn: turn,
            move: move,
            actionID: candidate.actionID,
            label: Self.label(for: candidate, game: game)
        )
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
                return piece.side == ownSide ? raw : Character(String(raw).lowercased())
            }
            let rows = (0..<XiangqiState.rows).map { row in
                (0..<XiangqiState.columns).map { col in code(state.piece(at: row * XiangqiState.columns + col)) }
                    .reduce(into: "") { $0.append($1) }
            }
            return "uppercase=local,lowercase=opponent; board_rows=" + rows.joined(separator: "/")
                + "; local_check=\(state.isInCheck(player: session.localPlayer)); opponent_check=\(state.isInCheck(player: session.localPlayer.opponent))"
        case .ludo:
            guard let state = session.ludo else { return "ludo_state=missing" }
            let own = state.pieces(for: session.localPlayer).map(String.init).joined(separator: ",")
            let opp = state.pieces(for: session.localPlayer.opponent).map(String.init).joined(separator: ",")
            let legal = state.currentPlayer == session.localPlayer
                ? state.legalPieces(sessionID: session.id).map(String.init).joined(separator: ",") : ""
            return "own_progress=[\(own)]; opponent_progress=[\(opp)]; next_dice=\(state.expectedDice(sessionID: session.id)); legal_local_pieces=[\(legal)]"
        case .tactical:
            return "tactical_turn=\(session.moveCount); native_bot=unavailable; use high-level explanation only"
        }
    }

    private static func label(for candidate: AgentActionCandidate, game: MiniGameKind) -> String {
        switch game {
        case .gomoku:
            if let index = candidate.metadata["index"].flatMap(Int.init) {
                return "落子 \(index / GomokuState.size + 1)行\(index % GomokuState.size + 1)列"
            }
        case .xiangqi:
            if let from = candidate.metadata["from"].flatMap(Int.init),
               let to = candidate.metadata["to"].flatMap(Int.init) {
                return "\(from / XiangqiState.columns + 1)行\(from % XiangqiState.columns + 1)列 → \(to / XiangqiState.columns + 1)行\(to % XiangqiState.columns + 1)列"
            }
        case .ludo:
            if let piece = candidate.metadata["piece"].flatMap(Int.init) {
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
