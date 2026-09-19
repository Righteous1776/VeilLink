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

    private let maleCNS: MaleCNSGraphManager
    private let controls: AgentControlCenterSettings
    private var aiTask: Task<Void, Never>?
    private var policy: TrainedGamePolicyRuntime?

    init(game: MiniGameKind, maleCNS: MaleCNSGraphManager, controls: AgentControlCenterSettings) {
        self.game = game
        self.maleCNS = maleCNS
        self.controls = controls
        sessionID = UUID().uuidString
        policy = try? TrainedGamePolicyRuntime.loadBundled()
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
        case .aiWon: return "灵核 AI 获胜"
        case .draw: return "和局"
        case .playing:
            if isAIThinking { return "灵核 AI 正在计算…" }
            return canHumanAct ? "轮到你" : "等待 AI"
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
        lastDecisionMode = "基础策略"
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
        guard let adapter = aiAdapter() else { return nil }
        let legal = adapter.enumerateLegalActions().filter(adapter.validate)
        guard !legal.isEmpty else { return nil }

        var baseline = legal
        if let policy,
           let ranked = try? policy.rankedLegalActions(adapter: adapter),
           !ranked.isEmpty {
            let byID = Dictionary(uniqueKeysWithValues: legal.map { ($0.actionID, $0) })
            baseline = ranked.compactMap { byID[$0.actionID] }
            if baseline.count < legal.count {
                let seen = Set(baseline.map(\.actionID))
                baseline.append(contentsOf: legal.filter { !seen.contains($0.actionID) })
            }
        }

        guard controls.gameDecisionMode.usesMaleCNSRerank,
              case .ready(let profile) = maleCNS.state,
              let snapshot = syntheticAISnapshot(),
              let ranker = try? MaleCNSGameRankerModel.loadBundled(
                for: profile.tier,
                allowExperimental: controls.gameDecisionMode.allowsExperimentalRanker
              ),
              (try? ranker.validate(profile: profile)) != nil else {
            lastDecisionMode = "基础策略"
            return baseline.first
        }

        let candidates = Array(baseline.prefix(3))
        var scored: [(AgentActionCandidate, Float)] = []
        for candidate in candidates {
            guard !Task.isCancelled,
                  let task = MaleCNSGameDecisionEncoder.taskVector(session: snapshot, candidate: candidate),
                  let channels = MaleCNSGameDecisionEncoder.channels(task: task, game: game),
                  let episode = try? await maleCNS.runGameChannels(channels, requestedSteps: 6),
                  let result = try? ranker.score(game: game, stimulus: channels, episode: episode) else { continue }
            scored.append((candidate, result.score))
        }
        guard let best = scored.max(by: { lhs, rhs in
            if lhs.1 == rhs.1 { return lhs.0.actionID > rhs.0.actionID }
            return lhs.1 < rhs.1
        }) else {
            lastDecisionMode = "基础策略"
            return baseline.first
        }
        lastDecisionMode = profile.tier == .core ? "MaleCNS Core · Top‑3" : "MaleCNS Lite · Top‑3"
        return best.0
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
