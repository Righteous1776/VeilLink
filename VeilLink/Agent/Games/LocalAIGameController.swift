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
    @Published private(set) var tactical = TacticalState()
    @Published private(set) var artillery = ArtilleryState()
    @Published private(set) var lightTrail = LightTrailState()
    @Published private(set) var magneticHockey = MagneticHockeyState()
    @Published private(set) var tacticalDifficulty: TacticalBotDifficulty = .commander
    @Published private(set) var arcadeDifficulty: ArcadeBotDifficulty = .operatorMode
    @Published private(set) var tacticalScenario: TacticalSoloScenario = .standard
    @Published private(set) var tacticalDailyChallenge = TacticalDailyChallenge.challenge()
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
        case .tactical: return tactical.currentPlayer == humanPlayer
        case .artillery: return artillery.currentPlayer == humanPlayer
        case .lightTrail: return lightTrail.currentPlayer == humanPlayer
        case .magneticHockey: return magneticHockey.currentPlayer == humanPlayer
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
        artillery = ArtilleryState()
        lightTrail = LightTrailState()
        magneticHockey = MagneticHockeyState()
        if tacticalScenario == .daily {
            tacticalDailyChallenge = TacticalDailyChallenge.challenge()
            tactical = tacticalDailyChallenge.makeState()
        } else {
            tactical = TacticalState()
        }
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

    func humanTacticalMove(from: Int, to: Int) {
        guard game == .tactical, canHumanAct else { return }
        var state = tactical
        guard state.apply(from: from, to: to, actor: humanPlayer, sessionID: sessionID) else { return }
        tactical = state
        finishOrScheduleAI()
    }

    func humanTacticalPass() {
        guard game == .tactical, canHumanAct else { return }
        var state = tactical
        guard state.apply(from: nil, to: nil, actor: humanPlayer, sessionID: sessionID) else { return }
        tactical = state
        finishOrScheduleAI()
    }

    func humanArtilleryShot(angle: Int, power: Int) {
        guard game == .artillery, canHumanAct else { return }
        var state = artillery
        guard state.apply(angle: angle, power: power, actor: humanPlayer, sessionID: sessionID) else { return }
        artillery = state
        finishOrScheduleAI()
    }

    func humanLightTrailShift(_ shift: Int) {
        guard game == .lightTrail, canHumanAct else { return }
        var state = lightTrail
        guard state.apply(shift: shift, actor: humanPlayer, sessionID: sessionID) else { return }
        lightTrail = state
        finishOrScheduleAI()
    }

    func humanMagneticHockeyShot(angle: Int, power: Int) {
        guard game == .magneticHockey, canHumanAct else { return }
        var state = magneticHockey
        guard state.apply(angle: angle, power: power, actor: humanPlayer, sessionID: sessionID) else { return }
        magneticHockey = state
        finishOrScheduleAI()
    }

    func setTacticalDifficulty(_ difficulty: TacticalBotDifficulty) {
        guard game == .tactical else { return }
        tacticalDifficulty = difficulty
    }

    func setArcadeDifficulty(_ difficulty: ArcadeBotDifficulty) {
        switch game {
        case .artillery, .lightTrail, .magneticHockey:
            arcadeDifficulty = difficulty
        default:
            break
        }
    }

    func setTacticalScenario(_ scenario: TacticalSoloScenario) {
        guard game == .tactical, tacticalScenario != scenario else { return }
        tacticalScenario = scenario
        restart()
    }

    var tacticalCoachText: String {
        guard game == .tactical else { return "" }
        if tactical.currentPlayer != humanPlayer { return "军师正在观察袁军调动…" }
        let situation = tactical.situationSnapshot()
        let unsupplied = tactical.units(for: humanPlayer).filter { !situation.isSupplied($0) }
        if !unsupplied.isEmpty { return "补给告急：\(unsupplied.map(\.name).joined(separator: "、")) 已断粮。" }
        if tactical.control(at: 31) != .cao { return "建议：优先争夺中央官渡，每轮可得 2 VP。" }
        if let command = tactical.unit(id: "cao-command"),
           situation.threatenedHexes(by: .yuan).contains(command.position) {
            return "中军处在袁军威胁范围内，考虑后撤或用友军屏护。"
        }
        return "官渡在手：守住目标，同时寻找切断袁军粮道的机会。"
    }

    var tacticalDebrief: TacticalDebrief {
        TacticalDebrief.make(
            state: tactical,
            humanPlayer: humanPlayer,
            challenge: tacticalScenario == .daily ? tacticalDailyChallenge : nil
        )
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
            if let winner = tactical.winner { outcome = winner == humanPlayer ? .humanWon : .aiWon }
            else if tactical.isDraw { outcome = .draw }
        case .artillery:
            if let winner = artillery.winner { outcome = winner == humanPlayer ? .humanWon : .aiWon }
            else if artillery.isDraw { outcome = .draw }
        case .lightTrail:
            if let winner = lightTrail.winner { outcome = winner == humanPlayer ? .humanWon : .aiWon }
            else if lightTrail.isDraw { outcome = .draw }
        case .magneticHockey:
            if let winner = magneticHockey.winner { outcome = winner == humanPlayer ? .humanWon : .aiWon }
            else if magneticHockey.isDraw { outcome = .draw }
        }
    }

    private func scheduleAIIfNeeded() {
        guard outcome == .playing else { return }
        let current: MiniGamePlayer?
        switch game {
        case .gomoku: current = gomoku.currentPlayer
        case .xiangqi: current = xiangqi.currentPlayer
        case .ludo: current = ludo.currentPlayer
        case .tactical: current = tactical.currentPlayer
        case .artillery: current = artillery.currentPlayer
        case .lightTrail: current = lightTrail.currentPlayer
        case .magneticHockey: current = magneticHockey.currentPlayer
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
            let snapshot = tactical
            let currentSessionID = sessionID
            let difficulty = tacticalDifficulty
            let result = await Task.detached(priority: .userInitiated) {
                TacticalBot.chooseMove(
                    in: snapshot,
                    for: .guest,
                    sessionID: currentSessionID,
                    difficulty: difficulty
                )
            }.value
            guard let result else { return nil }

            var ruleGate = tactical
            guard ruleGate.apply(
                from: result.from,
                to: result.to,
                actor: .guest,
                sessionID: sessionID
            ) else { return nil }
            lastDecisionMode = "兵棋·\(difficulty.title)"
            return AgentActionCandidate(
                actionID: result.isPass ? "tactical:pass" : "tactical:\(result.from!):\(result.to!)",
                encodedAction: AgentGameEncoding.encodeInts([result.from ?? -1, result.to ?? -1]),
                metadata: [
                    "from": result.from.map(String.init) ?? "pass",
                    "to": result.to.map(String.init) ?? "pass",
                    "score": String(format: "%.4f", result.score),
                    "candidates": String(result.candidates),
                    "policy": result.policyID
                ],
                features: []
            )
        case .artillery:
            let snapshot = artillery
            let currentSessionID = sessionID
            let shot = await Task.detached(priority: .userInitiated) {
                ArtilleryBot.chooseShot(
                    in: snapshot,
                    actor: .guest,
                    sessionID: currentSessionID,
                    difficulty: self.arcadeDifficulty
                )
            }.value
            guard let shot else { return nil }
            var ruleGate = artillery
            guard ruleGate.apply(angle: shot.angle, power: shot.power, actor: .guest, sessionID: sessionID) else { return nil }
            lastDecisionMode = "弹道搜索·\(arcadeDifficulty.title)"
            return AgentActionCandidate(
                actionID: "artillery:\(shot.angle):\(shot.power)",
                encodedAction: AgentGameEncoding.encodeInts([shot.angle, shot.power]),
                metadata: ["angle": String(shot.angle), "power": String(shot.power)],
                features: []
            )
        case .lightTrail:
            let snapshot = lightTrail
            let currentSessionID = sessionID
            let shift = await Task.detached(priority: .userInitiated) {
                LightTrailBot.chooseShift(
                    in: snapshot,
                    actor: .guest,
                    sessionID: currentSessionID,
                    difficulty: self.arcadeDifficulty
                )
            }.value
            guard let shift else { return nil }
            var ruleGate = lightTrail
            guard ruleGate.apply(shift: shift, actor: .guest, sessionID: sessionID) else { return nil }
            lastDecisionMode = "赛道预判·\(arcadeDifficulty.title)"
            return AgentActionCandidate(
                actionID: "light-trail:\(shift)",
                encodedAction: AgentGameEncoding.encodeInts([shift]),
                metadata: ["shift": String(shift)],
                features: []
            )
        case .magneticHockey:
            let snapshot = magneticHockey
            let currentSessionID = sessionID
            let move = await Task.detached(priority: .userInitiated) {
                MagneticHockeyBot.chooseMove(
                    in: snapshot,
                    actor: .guest,
                    sessionID: currentSessionID,
                    difficulty: self.arcadeDifficulty
                )
            }.value
            guard let move else { return nil }
            var ruleGate = magneticHockey
            guard ruleGate.apply(move: move, actor: .guest, sessionID: sessionID) else { return nil }
            lastDecisionMode = "磁场反弹·\(arcadeDifficulty.title)"
            return AgentActionCandidate(
                actionID: "magnetic-hockey:\(move.angle):\(move.power)",
                encodedAction: AgentGameEncoding.encodeInts([move.angle, move.power]),
                metadata: ["angle": String(move.angle), "power": String(move.power)],
                features: []
            )
        }
    }

    private func aiAdapter() -> (any AgentGameAdapter)? {
        switch game {
        case .gomoku: return GomokuAgentAdapter(state: gomoku, actor: aiPlayer)
        case .xiangqi: return XiangqiAgentAdapter(state: xiangqi, actor: aiPlayer)
        case .ludo: return LudoAgentAdapter(state: ludo, actor: aiPlayer, sessionID: sessionID)
        case .tactical: return nil
        case .artillery, .lightTrail, .magneticHockey: return nil
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
            tactical: game == .tactical ? tactical : nil,
            artillery: game == .artillery ? artillery : nil,
            lightTrail: game == .lightTrail ? lightTrail : nil,
            magneticHockey: game == .magneticHockey ? magneticHockey : nil,
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
            let from = candidate.metadata["from"].flatMap(Int.init)
            let to = candidate.metadata["to"].flatMap(Int.init)
            var state = tactical
            guard state.apply(from: from, to: to, actor: aiPlayer, sessionID: sessionID) else { return }
            tactical = state
        case .artillery:
            guard let angle = candidate.metadata["angle"].flatMap(Int.init),
                  let power = candidate.metadata["power"].flatMap(Int.init) else { return }
            var state = artillery
            guard state.apply(angle: angle, power: power, actor: aiPlayer, sessionID: sessionID) else { return }
            artillery = state
        case .lightTrail:
            guard let shift = candidate.metadata["shift"].flatMap(Int.init) else { return }
            var state = lightTrail
            guard state.apply(shift: shift, actor: aiPlayer, sessionID: sessionID) else { return }
            lightTrail = state
        case .magneticHockey:
            guard let angle = candidate.metadata["angle"].flatMap(Int.init),
                  let power = candidate.metadata["power"].flatMap(Int.init) else { return }
            var state = magneticHockey
            guard state.apply(angle: angle, power: power, actor: aiPlayer, sessionID: sessionID) else { return }
            magneticHockey = state
        }
    }
}
