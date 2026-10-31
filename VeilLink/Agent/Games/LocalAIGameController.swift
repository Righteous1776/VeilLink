import Combine
import Foundation

enum BoardBotDifficulty: String, CaseIterable, Identifiable, Sendable {
    case relaxed
    case balanced
    case advanced
    case master

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed: return "轻松"
        case .balanced: return "均衡"
        case .advanced: return "进阶"
        case .master: return "宗师"
        }
    }

    var detail: String {
        switch self {
        case .relaxed: return "保留明显容错，适合入门练习"
        case .balanced: return "稳定策略与本地学习"
        case .advanced: return "更宽候选、更深反击搜索"
        case .master: return "设备允许时启用最深离线搜索"
        }
    }
}

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
    @Published private(set) var tacticalScenario: TacticalSoloScenario = .standard
    @Published private(set) var tacticalDailyChallenge = TacticalDailyChallenge.challenge()
    @Published private(set) var outcome: Outcome = .playing
    @Published private(set) var isAIThinking = false
    @Published private(set) var lastDecisionMode = "基础策略"
    @Published private(set) var lastDecisionMilliseconds: Int?
    @Published private(set) var learningSummary: AdaptiveBoardLearningSummary
    @Published private(set) var boardDifficulty: BoardBotDifficulty = .balanced
    /// Explicit local opt-in; the incumbent search remains the default and fallback.
    @Published private(set) var useExternalGomokuEngine = UserDefaults.standard.bool(forKey: "VeilLink.Gomoku.V2.Enabled")
    @Published private(set) var gomokuFormationMode = GomokuFormationMode(
        rawValue: UserDefaults.standard.string(forKey: "VeilLink.Gomoku.FormationMode.v1") ?? ""
    ) ?? .off
    @Published private(set) var discoveredGomokuFormations = 0
    @Published private(set) var trainedNativeGames = 0
    @Published private(set) var isNativeTraining = false
    @Published private(set) var nativeTrainingCompleted = 0
    @Published private(set) var nativeTrainingTarget = 0
    @Published private(set) var nativeTrainingMessage = "原生对弈训练尚未启动。"
    @Published private(set) var useNativeTrainingEvidence = UserDefaults.standard.bool(forKey: "VeilLink.Gomoku.UseNativeSelfPlay.v1")
    @Published private(set) var coachProfile: PersonalBoardCoachProfile
    @Published private(set) var coachTip = "每一步都会沉淀为下一局的本地训练证据。"
    @Published private(set) var developerTeachingMode = false
    @Published private(set) var developerFormationCount = 0

    let game: MiniGameKind
    let humanPlayer: MiniGamePlayer = .host
    let aiPlayer: MiniGamePlayer = .guest
    @Published private(set) var sessionID: String

    private var aiTask: Task<Void, Never>?
    private let learningStore: AdaptiveBoardLearningStore
    private let formationLibrary: DeveloperFormationLibrary?
    private let formationDiscovery = GomokuFormationDiscoveryStore()
    private let nativeTrainingStore: AdaptiveBoardLearningStore?
    private var nativeTrainingTask: Task<Void, Never>?
    private var learningPlies: [AdaptiveBoardPly] = []
    /// Kept separate from ordinary player history so an owner-authored lesson
    /// never silently becomes public-player learning evidence.
    private var developerFormationPlies: [AdaptiveBoardPly] = []

    init(
        game: MiniGameKind,
        learningStore: AdaptiveBoardLearningStore? = nil,
        formationLibrary: DeveloperFormationLibrary? = nil
    ) {
        self.game = game
        let resolvedLearningStore = learningStore ?? AdaptiveBoardLearningStore.store(for: game)
        self.learningStore = resolvedLearningStore
        self.formationLibrary = formationLibrary
        if game == .gomoku {
            let archiveURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("VeilLink", isDirectory: true)
                .appendingPathComponent("gomoku-native-selfplay-v1.json")
            nativeTrainingStore = AdaptiveBoardLearningStore(game: .gomoku, fileURL: archiveURL)
        } else {
            nativeTrainingStore = nil
        }
        learningSummary = resolvedLearningStore.summary
        coachProfile = resolvedLearningStore.coachProfile(for: game)
        developerFormationCount = formationLibrary?.lessons.count ?? 0
        discoveredGomokuFormations = formationDiscovery.candidateCount
        trainedNativeGames = nativeTrainingStore?.summary.completedGames ?? 0
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

    var learningStoreAvailable: Bool { learningStore.lastSaveSucceeded }

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
        finalizeLearning(as: .unfinished)
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
        developerFormationPlies.removeAll(keepingCapacity: true)
        developerTeachingMode = false
        lastDecisionMode = "规则 Bot"
        lastDecisionMilliseconds = nil
    }

    func humanGomokuMove(_ index: Int) {
        guard game == .gomoku, canHumanAct else { return }
        var state = gomoku
        let position = AdaptiveBoardPosition.gomoku(state)
        coachTip = GomokuBot.coachingHint(beforePlaying: index, in: state, for: humanPlayer)
        guard state.apply(index: index, actor: humanPlayer) else { return }
        learningPlies.append(AdaptiveBoardPly(position: position, action: String(index), actor: humanPlayer))
        gomoku = state
        finishOrScheduleAI()
    }

    func setDeveloperTeachingMode(_ enabled: Bool) {
        guard game == .gomoku else { return }
        if enabled, !developerTeachingMode {
            beginDeveloperFormationRecording()
            return
        }
        developerTeachingMode = enabled
        if enabled { aiTask?.cancel(); aiTask = nil; isAIThinking = false }
    }

    func beginDeveloperFormationRecording() {
        guard game == .gomoku else { return }
        finalizeLearning(as: .unfinished)
        aiTask?.cancel(); aiTask = nil
        gomoku = GomokuState()
        outcome = .playing
        isAIThinking = false
        sessionID = UUID().uuidString
        developerFormationPlies.removeAll(keepingCapacity: true)
        developerTeachingMode = true
        coachTip = "阵法录制已从空棋盘开始：请依次演示双方的攻防走子。"
    }

    func developerGomokuMove(_ index: Int) {
        guard game == .gomoku, developerTeachingMode, outcome == .playing else { return }
        var state = gomoku
        let actor = state.currentPlayer
        let position = AdaptiveBoardPosition.gomoku(state)
        guard state.apply(index: index, actor: actor) else { return }
        developerFormationPlies.append(AdaptiveBoardPly(position: position, action: String(index), actor: actor))
        gomoku = state
        updateOutcome()
    }

    func captureDeveloperFormation(name: String, purpose: String, objective: String) throws {
        guard game == .gomoku, let formationLibrary else {
            throw DeveloperFormationError.invalidLesson
        }
        try formationLibrary.capture(name: name, purpose: purpose, objective: objective, plies: developerFormationPlies)
        developerFormationCount = formationLibrary.lessons.count
        developerFormationPlies.removeAll(keepingCapacity: true)
        developerTeachingMode = false
        coachTip = "已保存开发者阵法：后续同一前缀局面会优先使用你录制的应手。"
    }

    func humanXiangqiMove(from: Int, to: Int) {
        guard game == .xiangqi, canHumanAct else { return }
        var state = xiangqi
        let position = AdaptiveBoardPosition.xiangqi(state)
        coachTip = XiangqiBot.coachingHint(beforePlayingFrom: from, to: to, in: state, for: humanPlayer)
        guard state.apply(from: from, to: to, actor: humanPlayer) else { return }
        learningPlies.append(AdaptiveBoardPly(position: position, action: "\(from):\(to)", actor: humanPlayer))
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

    func setExternalGomokuEngineEnabled(_ enabled: Bool) {
        guard game == .gomoku else { return }
        useExternalGomokuEngine = enabled
        UserDefaults.standard.set(enabled, forKey: "VeilLink.Gomoku.V2.Enabled")
    }

    func setGomokuFormationMode(_ mode: GomokuFormationMode) {
        guard game == .gomoku else { return }
        gomokuFormationMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "VeilLink.Gomoku.FormationMode.v1")
        coachTip = mode.detail
    }

    func setUseNativeTrainingEvidence(_ enabled: Bool) {
        guard game == .gomoku else { return }
        useNativeTrainingEvidence = enabled
        UserDefaults.standard.set(enabled, forKey: "VeilLink.Gomoku.UseNativeSelfPlay.v1")
    }

    func startNativeTraining(games target: Int) {
        guard game == .gomoku, [10, 100, 1_000].contains(target),
              !isNativeTraining, let store = nativeTrainingStore else { return }
        if !store.lastSaveSucceeded {
            nativeTrainingMessage = "训练档案需要修复；未覆盖旧记录。"
            return
        }
        nativeTrainingTarget = target
        nativeTrainingCompleted = 0
        isNativeTraining = true
        setUseNativeTrainingEvidence(true)
        nativeTrainingMessage = "真正调用原生 Bot 对弈，完整保存后才计数。"
        let startingSeed = store.summary.completedGames
        let selectedMode = gomokuFormationMode
        nativeTrainingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isNativeTraining = false
                self.nativeTrainingTask = nil
            }
            var failed = 0
            for gameIndex in 0..<(target * 2) {
                if Task.isCancelled || self.nativeTrainingCompleted >= target { break }
                let snapshot = store.snapshot()
                let seed = startingSeed + gameIndex
                let worker = Task.detached(priority: .utility) {
                    NativeGomokuSelfPlay.play(
                        seed: seed, formationMode: selectedMode, learning: snapshot
                    )
                }
                let finished = await withTaskCancellationHandler(
                    operation: { await worker.value },
                    onCancel: { worker.cancel() }
                )
                if let finished, finished.completed {
                    let stored = store.recordCompletedNativeBatch([
                        (plies: finished.plies, result: finished.result)
                    ])
                    if stored == 1 {
                        self.nativeTrainingCompleted += 1
                        self.trainedNativeGames = store.summary.completedGames
                    } else {
                        self.nativeTrainingMessage = "训练数据保存失败，已停止。"
                        break
                    }
                } else {
                    failed += 1
                    if failed >= 10 {
                        self.nativeTrainingMessage = "对局连续未完成，已停止，不计入经验。"
                        break
                    }
                }
                await Task.yield()
            }
            self.trainedNativeGames = store.summary.completedGames
            if self.nativeTrainingCompleted == target {
                self.nativeTrainingMessage = "本轮已保存 \(self.nativeTrainingCompleted) 局原生自对弈。"
            } else if Task.isCancelled {
                self.nativeTrainingMessage = "已停止，本轮已保存 \(self.nativeTrainingCompleted) 局。"
            }
        }
    }

    func stopNativeTraining() {
        nativeTrainingTask?.cancel()
    }

    func setBoardDifficulty(_ difficulty: BoardBotDifficulty) {
        guard game == .gomoku || game == .xiangqi else { return }
        boardDifficulty = difficulty
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
        stopNativeTraining()
        aiTask?.cancel(); aiTask = nil
        isAIThinking = false
        finalizeLearning(as: .unfinished)
    }

    func clearBoardLearning() {
        learningStore.clear()
        if game == .gomoku {
            stopNativeTraining()
            formationDiscovery.clear()
            discoveredGomokuFormations = 0
            nativeTrainingStore?.clear()
            trainedNativeGames = nativeTrainingStore?.summary.completedGames ?? 0
            setUseNativeTrainingEvidence(false)
        }
        learningPlies.removeAll(keepingCapacity: true)
        learningSummary = learningStore.summary
        coachProfile = learningStore.coachProfile(for: game)
        coachTip = "已清空本地训练档案；下一局将从新的个人棋谱开始。"
    }

    func exportBoardLearning() throws -> URL {
        try learningStore.exportPackage()
    }

    func importBoardLearning(from url: URL) throws -> AdaptiveBoardLearningImportReport {
        let report = try learningStore.importPackage(from: url)
        learningPlies.removeAll(keepingCapacity: true)
        learningSummary = learningStore.summary
        coachProfile = learningStore.coachProfile(for: game)
        coachTip = "训练包已合并到本地档案；下一局会使用其中的阵法证据。"
        return report
    }

    private func finishOrScheduleAI() {
        updateOutcome()
        guard !developerTeachingMode else { return }
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
        switch outcome {
        case .humanWon: finalizeLearning(as: .humanWon)
        case .aiWon: finalizeLearning(as: .aiWon)
        case .draw: finalizeLearning(as: .draw)
        case .playing: break
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
            let formation = formationLibrary?.influence(for: learningPlies) ?? .empty
            let humanLearning = learningStore.snapshot(currentPlies: learningPlies).applying(formation)
            let nativeActive = useNativeTrainingEvidence && trainedNativeGames > 0
            let learning = nativeActive && nativeTrainingStore != nil
                ? humanLearning.incorporatingNativeSelfPlay(
                    nativeTrainingStore!.snapshot(), completedGames: trainedNativeGames
                )
                : humanLearning
            let budget = GomokuBotBudget.forDifficulty(
                boardDifficulty,
                profileLabel: VeilDevicePerformance.current.label
            ).reinforced(by: learning.trainingLevel)
            let preference = GomokuFormationPreference(
                mode: gomokuFormationMode,
                aiHistory: learningPlies.filter { $0.actor == .guest }.compactMap { Int($0.action) },
                discovered: formationDiscovery.eligibleSignatures
            )
            var chosen: GomokuBotMove?
            var engineName = "原生"
            // Native tactics are the only engine that currently consumes these
            // formation preferences. Do not claim PVS/VCF uses them.
            if useExternalGomokuEngine && !preference.enabled && !nativeActive {
                // A standalone JavaScriptCore actor; the external engine never
                // touches gameplay/DB and is validated by our own rule gate.
                let external = await VeilOfflineGomokuEngine.shared.chooseMove(
                    in: snapshot,
                    for: .guest,
                    timeLimitMilliseconds: budget.timeLimitMilliseconds,
                    maxDepth: boardDifficulty == .master ? 7 : boardDifficulty == .advanced ? 5 : 3
                )
                if let external {
                    var trial = snapshot
                    if trial.apply(index: external.index, actor: .guest) {
                        chosen = external
                        engineName = "PVS/VCF"
                    }
                }
            }
            if chosen == nil {
                chosen = await Task.detached(priority: .userInitiated) {
                    GomokuBot.chooseMove(
                        in: snapshot, for: .guest, budget: budget,
                        learning: learning, formationPreference: preference
                    )
                }.value
            }
            guard let result = chosen else { return nil }

            var ruleGate = gomoku
            guard ruleGate.apply(index: result.index, actor: .guest) else { return nil }
            let learned = learning.hasSequenceEvidence ? " · 训练 Lv\(learning.trainingLevel)" : ""
            let formationLabel = formation.matchedLessonNames.first.map { " · 阵法：\($0)" } ?? ""
            // Preserve the incumbent controller's observable status contract.
            // External PVS/VCF does NOT consume AdaptiveBoardLearningSnapshot:
            // reporting its training level or Owner formation as applied would
            // misrepresent actual search inputs.
            if engineName == "原生" {
                lastDecisionMode = "五子棋 · \(boardDifficulty.title)\(learned)\(formationLabel)"
                    + (preference.enabled ? " · \(preference.mode.title)" : "")
                    + (nativeActive ? " · 原生实战训练 \(trainedNativeGames) 局" : "")
            } else {
                lastDecisionMode = "五子棋 · PVS/VCF · \(boardDifficulty.title)"
            }
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
            let formation = formationLibrary?.influence(for: learningPlies) ?? .empty
            let learning = learningStore.snapshot(currentPlies: learningPlies).applying(formation)
            let budget = XiangqiBotBudget.forDifficulty(
                boardDifficulty,
                profileLabel: VeilDevicePerformance.current.label
            ).reinforced(by: learning.trainingLevel)
            let result = await Task.detached(priority: .userInitiated) {
                XiangqiBot.chooseMove(in: snapshot, for: .guest, budget: budget, learning: learning)
            }.value
            guard let result else { return nil }

            var ruleGate = xiangqi
            guard ruleGate.apply(from: result.from, to: result.to, actor: .guest) else { return nil }
            let baseMode = result.completedDepth > 0
                ? "象棋 · \(boardDifficulty.title) D\(result.completedDepth)"
                : "象棋 · \(boardDifficulty.title) 快速着"
            lastDecisionMode = learning.hasSequenceEvidence
                ? baseMode + " · 训练 Lv\(learning.trainingLevel)"
                : baseMode
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
                ArtilleryBot.chooseShot(in: snapshot, actor: .guest, sessionID: currentSessionID)
            }.value
            guard let shot else { return nil }
            var ruleGate = artillery
            guard ruleGate.apply(angle: shot.angle, power: shot.power, actor: .guest, sessionID: sessionID) else { return nil }
            lastDecisionMode = "弹道搜索 Bot"
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
                LightTrailBot.chooseShift(in: snapshot, actor: .guest, sessionID: currentSessionID)
            }.value
            guard let shift else { return nil }
            var ruleGate = lightTrail
            guard ruleGate.apply(shift: shift, actor: .guest, sessionID: sessionID) else { return nil }
            lastDecisionMode = "赛道预判 Bot"
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
                MagneticHockeyBot.chooseMove(in: snapshot, actor: .guest, sessionID: currentSessionID)
            }.value
            guard let move else { return nil }
            var ruleGate = magneticHockey
            guard ruleGate.apply(move: move, actor: .guest, sessionID: sessionID) else { return nil }
            lastDecisionMode = "磁场反弹 Bot"
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
            let position = AdaptiveBoardPosition.gomoku(state)
            guard state.apply(index: index, actor: aiPlayer) else { return }
            learningPlies.append(AdaptiveBoardPly(position: position, action: String(index), actor: aiPlayer))
            gomoku = state
        case .xiangqi:
            guard let from = candidate.metadata["from"].flatMap(Int.init),
                  let to = candidate.metadata["to"].flatMap(Int.init) else { return }
            var state = xiangqi
            let position = AdaptiveBoardPosition.xiangqi(state)
            guard state.apply(from: from, to: to, actor: aiPlayer) else { return }
            learningPlies.append(AdaptiveBoardPly(position: position, action: "\(from):\(to)", actor: aiPlayer))
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

    private func finalizeLearning(as result: AdaptiveBoardGameResult) {
        guard game == .gomoku || game == .xiangqi, !learningPlies.isEmpty else { return }
        learningStore.record(game: game, plies: learningPlies, result: result)
        if game == .gomoku {
            formationDiscovery.record(
                aiMoves: learningPlies.filter { $0.actor == .guest }.compactMap { Int($0.action) },
                outcome: result
            )
            discoveredGomokuFormations = formationDiscovery.candidateCount
        }
        learningPlies.removeAll(keepingCapacity: true)
        learningSummary = learningStore.summary
        coachProfile = learningStore.coachProfile(for: game)
        switch result {
        case .humanWon:
            coachTip = "本局已归档：下一局会提高对你常用成功线路的应对强度。"
        case .aiWon, .unfinished:
            coachTip = "本局已归档：教练会保留这条线路，下一次给出更有针对性的练习。"
        case .draw:
            coachTip = "本局已归档：平衡局面会用于训练攻守转换。"
        }
    }
}
