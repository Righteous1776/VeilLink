import Combine
import Foundation

@MainActor
final class LocalAIGameController: ObservableObject {
    enum Outcome: Equatable {
        case playing
        case humanWon
        case aiWon
        case draw
    }

    @Published private(set) var gomoku = GomokuState()
    @Published private(set) var xiangqi = XiangqiState()
    @Published private(set) var ludo = LudoState()
    @Published private(set) var outcome: Outcome = .playing
    @Published private(set) var isAIThinking = false
    @Published private(set) var lastDecisionMode = "基础策略"
    @Published private(set) var lastDecisionMilliseconds: Int?

    let game: MiniGameKind
    let humanPlayer: MiniGamePlayer = .host
    let aiPlayer: MiniGamePlayer = .guest
    @Published private(set) var sessionID: String

    private var aiTask: Task<Void, Never>?

    init(game: MiniGameKind) {
        self.game = game
        sessionID = UUID().uuidString
    }

    var canHumanAct: Bool {
        guard outcome == .playing, !isAIThinking else { return false }
        switch game {
        case .gomoku: return gomoku.currentPlayer == humanPlayer
        case .xiangqi: return xiangqi.currentPlayer == humanPlayer
        case .ludo: return ludo.currentPlayer == humanPlayer
        case .tactical: return false
        }
    }

    var statusText: String {
        switch outcome {
        case .humanWon: return "你赢了"
        case .aiWon: return "本地电脑获胜"
        case .draw: return "和局"
        case .playing:
            if isAIThinking { return "本地电脑正在计算…" }
            return canHumanAct ? "轮到你" : "等待电脑"
        }
    }

    func restart() {
        aiTask?.cancel(); aiTask = nil
        gomoku = GomokuState()
        xiangqi = XiangqiState()
        ludo = LudoState()
        sessionID = UUID().uuidString
        outcome = .playing
        isAIThinking = false
        lastDecisionMode = "规则 Bot"
        lastDecisionMilliseconds = nil
    }

    func humanGomokuMove(_ index: Int) {
        guard game == .gomoku, canHumanAct else { return }
        var state = gomoku
        guard state.apply(index: index, actor: humanPlayer) else { return }
        gomoku = state
        finishOrScheduleAI()
    }

    func humanXiangqiMove(from: Int, to: Int) {
        guard game == .xiangqi, canHumanAct else { return }
        var state = xiangqi
        guard state.apply(from: from, to: to, actor: humanPlayer) else { return }
        xiangqi = state
        finishOrScheduleAI()
    }

    func humanLudoMove(piece: Int) {
        guard game == .ludo, canHumanAct else { return }
        var state = ludo
        guard state.apply(pieceIndex: piece, actor: humanPlayer, sessionID: sessionID) else { return }
        ludo = state
        finishOrScheduleAI()
    }

    func cancelAI() {
        aiTask?.cancel(); aiTask = nil
        isAIThinking = false
    }

    private func finishOrScheduleAI() {
        updateOutcome()
        guard outcome == .playing else { return }
        scheduleAIIfNeeded()
    }

    private func updateOutcome() {
        switch game {
        case .gomoku:
            if let winner = gomoku.winner { outcome = winner == humanPlayer ? .humanWon : .aiWon }
            else if gomoku.isDraw { outcome = .draw }
        case .xiangqi:
            if let winner = xiangqi.winner { outcome = winner == humanPlayer ? .humanWon : .aiWon }
            else if xiangqi.isDraw { outcome = .draw }
        case .ludo:
            if let winner = ludo.winner { outcome = winner == humanPlayer ? .humanWon : .aiWon }
        case .tactical:
            break
        }
    }

    private func scheduleAIIfNeeded() {
        guard outcome == .playing else { return }
        let current: MiniGamePlayer?
        switch game {
        case .gomoku: current = gomoku.currentPlayer
        case .xiangqi: current = xiangqi.currentPlayer
        case .ludo: current = ludo.currentPlayer
        case .tactical: current = nil
        }
        guard current == aiPlayer else { return }
        aiTask?.cancel()
        isAIThinking = true
        aiTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            let started = Date()
            let selected = await self.selectAIMove()
            guard !Task.isCancelled else { return }
            if let selected { self.applyAI(selected) }
            self.lastDecisionMilliseconds = Int(Date().timeIntervalSince(started) * 1_000)
            self.isAIThinking = false
            self.aiTask = nil
            self.updateOutcome()
            if self.outcome == .playing { self.scheduleAIIfNeeded() }
        }
    }

    private func selectAIMove() async -> AgentActionCandidate? {
        switch game {
        case .gomoku:
            let snapshot = gomoku
            let budget = GomokuBotBudget.standard(
                profileLabel: VeilDevicePerformance.current.label
            )
            let result = await Task.detached(priority: .userInitiated) {
                GomokuBot.chooseMove(in: snapshot, for: .guest, budget: budget)
            }.value
            guard let result else { return nil }

            var ruleGate = gomoku
            guard ruleGate.apply(index: result.index, actor: .guest) else { return nil }
            lastDecisionMode = "五子棋 Bot"
            return AgentActionCandidate(
                actionID: "gomoku:\(result.index)",
                encodedAction: AgentGameEncoding.encodeInts([result.index]),
                metadata: [
                    "index": String(result.index),
                    "score": String(result.score),
                    "nodes": String(result.nodes)
                ],
                features: []
            )

        case .xiangqi:
            let snapshot = xiangqi
            let budget = XiangqiBotBudget.standard(
                profileLabel: VeilDevicePerformance.current.label
            )
            let result = await Task.detached(priority: .userInitiated) {
                XiangqiBot.chooseMove(in: snapshot, for: .guest, budget: budget)
            }.value
            guard let result else { return nil }

            var ruleGate = xiangqi
            guard ruleGate.apply(from: result.from, to: result.to, actor: .guest) else { return nil }
            lastDecisionMode = result.completedDepth > 0
                ? "象棋 Bot D\(result.completedDepth)"
                : "象棋 Bot 快速着"
            return AgentActionCandidate(
                actionID: "xiangqi:\(result.from):\(result.to)",
                encodedAction: AgentGameEncoding.encodeInts([result.from, result.to]),
                metadata: [
                    "from": String(result.from),
                    "to": String(result.to),
                    "score": String(result.score),
                    "depth": String(result.completedDepth),
                    "nodes": String(result.nodes)
                ],
                features: []
            )

        case .ludo:
            let snapshot = ludo
            let currentSessionID = sessionID
            let result = await Task.detached(priority: .userInitiated) {
                LudoBot.chooseMove(in: snapshot, for: .guest, sessionID: currentSessionID)
            }.value
            guard let result else { return nil }

            var ruleGate = ludo
            guard ruleGate.apply(
                pieceIndex: result.pieceIndex,
                actor: .guest,
                sessionID: sessionID
            ) else { return nil }
            lastDecisionMode = "飞行棋 Bot"
            return AgentActionCandidate(
                actionID: "ludo:\(result.pieceIndex)",
                encodedAction: AgentGameEncoding.encodeInts([result.pieceIndex]),
                metadata: [
                    "piece": String(result.pieceIndex),
                    "score": String(result.score)
                ],
                features: []
            )

        case .tactical:
            return nil
        }
    }

    private func aiAdapter() -> (any AgentGameAdapter)? {
        switch game {
        case .gomoku: return GomokuAgentAdapter(state: gomoku, actor: aiPlayer)
        case .xiangqi: return XiangqiAgentAdapter(state: xiangqi, actor: aiPlayer)
        case .ludo: return LudoAgentAdapter(state: ludo, actor: aiPlayer, sessionID: sessionID)
        case .tactical: return nil
        }
    }

    private func syntheticAISnapshot() -> MiniGameSessionSnapshot? {
        let now = Date()
        return MiniGameSessionSnapshot(
            id: sessionID,
            game: game,
            hostIsLocal: false,
            status: .active,
            invitedAt: now,
            startedAt: now,
            lastActivity: now,
            gomoku: game == .gomoku ? gomoku : nil,
            xiangqi: game == .xiangqi ? xiangqi : nil,
            ludo: game == .ludo ? ludo : nil,
            tactical: nil,
            endedByResignation: false
        )
    }

    private func applyAI(_ candidate: AgentActionCandidate) {
        switch game {
        case .gomoku:
            guard let index = candidate.metadata["index"].flatMap(Int.init) else { return }
            var state = gomoku
            guard state.apply(index: index, actor: aiPlayer) else { return }
            gomoku = state
        case .xiangqi:
            guard let from = candidate.metadata["from"].flatMap(Int.init),
                  let to = candidate.metadata["to"].flatMap(Int.init) else { return }
            var state = xiangqi
            guard state.apply(from: from, to: to, actor: aiPlayer) else { return }
            xiangqi = state
        case .ludo:
            guard let piece = candidate.metadata["piece"].flatMap(Int.init) else { return }
            var state = ludo
            guard state.apply(pieceIndex: piece, actor: aiPlayer, sessionID: sessionID) else { return }
            ludo = state
        case .tactical:
            break
        }
    }
}
