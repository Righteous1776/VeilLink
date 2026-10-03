import SwiftUI

struct GameLobbyView: View {
    @ObservedObject var model: AppModel
    @State private var nearbyConversation: ConversationSummary?

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero.veilStaggeredEntrance(index: 0)
                singlePlayerSection.veilStaggeredEntrance(index: 1)
                nearbySection.veilStaggeredEntrance(index: 2)
            }
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("游戏")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                VeilToolCenterToolbarLink(model: model)
            }
        }
        .sheet(item: $nearbyConversation) { conversation in
            MiniGameHubView(model: model, conversation: conversation)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(VeilTheme.gold.opacity(0.12))
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundColor(VeilTheme.goldBright)
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOCAL GAME HUB")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.3)
                        .foregroundColor(VeilTheme.mutedGold)
                    Text("游戏大厅")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text("单机人机 · 附近 E2EE 对战")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                lobbyMetric("单机", "规则 Bot")
                lobbyMetric("模型", "不内置")
                lobbyMetric("联网", "不需要")
            }
        }
        .padding(14)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                emphasized: true
            )
        )
        .overlay(alignment: .topTrailing) {
            VeilScrewHead().padding(7)
        }
        .veilSpatialPress(maximumTilt: 2.0, cornerRadius: 20, highlightColor: VeilTheme.goldBright)
        .veilDynamicGlow(active: true, emphasized: true)
    }

    private var singlePlayerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                "单机 · 本地电脑",
                subtitle: "战役沙盘、2D 物理实验与经典棋盘全部离线运行"
            )

            NavigationLink(destination: TacticalSoloV2View(model: model)) {
                tacticalFeaturedCard
            }
            .buttonStyle(.plain)
            .veilSpatialPress(maximumTilt: 1.8, cornerRadius: 18, highlightColor: VeilTheme.goldBright)

            VeilInstrumentRackSection(
                title: "2D 街机实验台",
                subtitle: "确定性物理、赛道与磁场玩法；相同输入可复算。",
                code: "ARCADE"
            ) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                    spacing: 10
                ) {
                    NavigationLink(destination: LocalAIGameView(model: model, game: .artillery)) {
                        gameTile(
                            .artillery,
                            detail: "弹道火控 · 风场预测",
                            telemetry: "PHYSICS"
                        )
                    }
                    NavigationLink(destination: LocalAIGameView(model: model, game: .lightTrail)) {
                        gameTile(
                            .lightTrail,
                            detail: "五轨闪避 · 能量路线",
                            telemetry: "3-STEP AI"
                        )
                    }
                    NavigationLink(destination: LocalAIGameView(model: model, game: .magneticHockey)) {
                        gameTile(
                            .magneticHockey,
                            detail: "固定步物理 · 磁场偏转",
                            telemetry: "120 Hz"
                        )
                    }
                }
            }

            VeilInstrumentRackSection(
                title: "经典棋盘台",
                subtitle: "轻量规则 Bot 与确定性棋局恢复。",
                code: "BOARD"
            ) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                    spacing: 10
                ) {
                    NavigationLink(destination: LocalAIGameView(model: model, game: .gomoku)) {
                        gameTile(.gomoku, detail: "威胁识别 · 候选搜索", telemetry: "TACTIC")
                    }
                    NavigationLink(destination: LocalAIGameView(model: model, game: .xiangqi)) {
                        gameTile(.xiangqi, detail: "Alpha-Beta · 局面评估", telemetry: "SEARCH")
                    }
                    NavigationLink(destination: LocalAIGameView(model: model, game: .ludo)) {
                        gameTile(.ludo, detail: "确定性骰子 · 规则评分", telemetry: "RULE BOT")
                    }
                }
            }
        }
    }

    private var tacticalFeaturedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                    Image(systemName: MiniGameKind.tactical.icon)
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(VeilTheme.goldBright)
                }
                .frame(width: 58, height: 58)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 0.8)
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text("GUANDU CAMPAIGN / V2")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(VeilTheme.mutedGold)
                    Text("官渡决战")
                        .font(.title3.bold())
                        .foregroundColor(VeilTheme.text)
                    Text("48×27 大地图 · 战争迷雾 · WEGO · 补给与作战层")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer()
                VeilIndicatorLamp(active: true)
            }

            HStack(spacing: 8) {
                VeilLCDDisplay(title: "MAP", value: "48×27")
                    .frame(maxWidth: .infinity)
                VeilLCDDisplay(title: "SYSTEM", value: "WEGO")
                    .frame(maxWidth: .infinity)
                VeilLCDDisplay(title: "INTEL", value: "FOG")
                    .frame(maxWidth: .infinity)
            }

            HStack {
                VeilInstrumentLabel(title: "SOLO", value: "A* BOT", active: true)
                Spacer()
                VeilInstrumentLabel(title: "MODE", value: "CAMPAIGN", active: true)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(VeilTheme.gold)
            }
        }
        .padding(14)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                emphasized: true
            )
        )
        .overlay(alignment: .topLeading) { VeilScrewHead().padding(7) }
        .overlay(alignment: .bottomTrailing) { VeilScrewHead().padding(7) }
    }

    private func gameTile(
        _ game: MiniGameKind,
        detail: String,
        telemetry: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                    Image(systemName: game.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(VeilTheme.goldBright)
                }
                .frame(width: 40, height: 40)
                Spacer()
                VeilIndicatorLamp(active: true)
            }

            Text(game.title)
                .font(.subheadline.bold())
                .foregroundColor(VeilTheme.text)
            Text(detail)
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
                .lineLimit(2)

            Spacer(minLength: 3)

            HStack {
                Text(telemetry)
                    .font(.system(size: 7.5, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundColor(VeilTheme.mutedGold)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2.bold())
                    .foregroundColor(VeilTheme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .leading)
        .padding(12)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                emphasized: false
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("附近对战", subtitle: "沿用现有 BLE + E2EE 游戏消息链")
            if model.conversations.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.slash")
                        .foregroundColor(VeilTheme.secondaryText)
                    Text("还没有可用联系人。先在“附近”完成配对，再从这里直接发起对局。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                    Spacer()
                }
                .veilCard()
            } else {
                ForEach(Array(model.conversations.prefix(6))) { conversation in
                    Button {
                        nearbyConversation = conversation
                        model.haptics.selection()
                    } label: {
                        HStack(spacing: 12) {
                            VeilIdentityGlyph(seed: conversation.peerIdentityID, size: 40, active: false)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(conversation.title)
                                    .font(.headline)
                                    .foregroundColor(VeilTheme.text)
                                Text("炮战 · 光轨 · 磁轨冰球 · 棋类 · 兵棋")
                                    .font(.caption)
                                    .foregroundColor(VeilTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(VeilTheme.tertiaryText)
                        }
                        .padding(13)
                        .background(VeilTheme.elevated.opacity(0.82))
                        .clipShape(VeilPanelShape(cut: 12, radius: 7))
                        .overlay(VeilPanelShape(cut: 12, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(VeilPressStyle())
                    .veilSpatialPress(maximumTilt: 2.0, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline).foregroundColor(VeilTheme.goldBright)
            Text(subtitle).font(.caption).foregroundColor(VeilTheme.secondaryText)
        }
    }

    private func gameRow(_ game: MiniGameKind, detail: String, enabled: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(VeilTheme.gold.opacity(enabled ? 0.12 : 0.05))
                Image(systemName: game.icon)
                    .foregroundColor(enabled ? VeilTheme.gold : VeilTheme.tertiaryText)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.headline)
                    .foregroundColor(enabled ? VeilTheme.text : VeilTheme.secondaryText)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Text(enabled ? "人机" : "待开发")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(enabled ? VeilTheme.gold : VeilTheme.tertiaryText)
            if enabled {
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(VeilTheme.tertiaryText)
            }
        }
        .padding(13)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                emphasized: enabled
            )
        )
        .overlay(alignment: .topTrailing) {
            VeilIndicatorLamp(active: enabled).padding(8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(enabled ? "可以开始人机对局" : "尚未开放")
    }

    private func lobbyMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(.caption2, design: .monospaced).weight(.bold)).foregroundColor(VeilTheme.tertiaryText)
            Text(value).font(.system(.caption2, design: .monospaced).weight(.semibold)).foregroundColor(VeilTheme.text).lineLimit(1).minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct LocalAIGameView: View {
    @ObservedObject var model: AppModel
    let game: MiniGameKind
    @StateObject private var controller: LocalAIGameController
    @State private var selectedXiangqiIndex: Int?
    @State private var showsTacticalGuide = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel, game: MiniGameKind) {
        self.model = model
        self.game = game
        _controller = StateObject(wrappedValue: LocalAIGameController(game: game))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusCard
                if isArcadeGame { arcadeControlCard }
                if isBoardGame {
                    boardControlCard
                    boardSituationCard
                }
                if game == .tactical { tacticalControlCard }
                board
                    .padding(10)
                    .background(
                        VeilInstrumentPlate(
                            shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                            emphasized: true
                        )
                    )
                    .overlay(alignment: .topTrailing) {
                        VeilScrewHead().padding(7)
                    }
                if controller.outcome != .playing { resultCard }
            }
            .padding(14)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle(game.title + " · 人机")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if game == .tactical {
                    Button {
                        showsTacticalGuide = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("兵棋教程与规则")
                    .foregroundColor(VeilTheme.gold)
                }
                Button("重开") {
                    selectedXiangqiIndex = nil
                    controller.restart()
                    model.haptics.selection()
                }
                .foregroundColor(VeilTheme.gold)
            }
        }
        .onAppear {
            model.agent.setComputeFocus(.gameDecision)
            if game == .tactical,
               !UserDefaults.standard.bool(forKey: TacticalSoloGuideView.completionKey) {
                showsTacticalGuide = true
            }
        }
        .onDisappear {
            controller.cancelAI()
            model.agent.setComputeFocus(.idle)
        }
        .sheet(isPresented: $showsTacticalGuide) {
            TacticalSoloGuideView()
        }
    }

    private var isArcadeGame: Bool {
        switch game {
        case .artillery, .lightTrail, .magneticHockey:
            return true
        default:
            return false
        }
    }

    private var isBoardGame: Bool {
        switch game {
        case .gomoku, .xiangqi, .ludo:
            return true
        default:
            return false
        }
    }

    private var boardControlCard: some View {
        VeilInstrumentDeck(
            title: "棋盘对手",
            subtitle: "本地搜索预算分档；不会改变棋盘规则、存档格式或附近联机协议。",
            symbol: "brain.head.profile"
        ) {
            HStack {
                VeilInstrumentLabel(
                    title: "DIFFICULTY",
                    value: controller.boardDifficulty.title,
                    active: true
                )
                Spacer()
                VeilLCDDisplay(
                    title: "BOT MODE",
                    value: controller.boardDifficulty.telemetryLabel
                )
                .frame(width: 112)
            }

            HStack(spacing: 7) {
                ForEach(BoardBotDifficulty.allCases) { difficulty in
                    Button {
                        controller.setBoardDifficulty(difficulty)
                        model.haptics.selection()
                    } label: {
                        VStack(spacing: 2) {
                            Text(difficulty.title)
                            Text(difficulty.telemetryLabel)
                                .font(.system(size: 6.5, weight: .black, design: .monospaced))
                                .tracking(0.5)
                                .opacity(0.72)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        VeilCompactKeyStyle(
                            selected: difficulty == controller.boardDifficulty
                        )
                    )
                    .accessibilityLabel("难度 \(difficulty.title)")
                    .accessibilityValue(
                        difficulty == controller.boardDifficulty ? "当前选择" : "未选择"
                    )
                }
            }
            .padding(6)
            .background(Color.black.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
            )

            Text(
                controller.boardDifficulty.telemetryDetail(
                    profileLabel: VeilDevicePerformance.current.label,
                    game: game
                )
            )
            .font(.caption2.monospaced())
            .foregroundColor(VeilTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var boardSituationCard: some View {
        switch game {
        case .gomoku:
            VeilInstrumentDeck(
                title: "五子棋局势",
                subtitle: "候选点来自规则 Bot 的局部搜索窗口。",
                symbol: "circle.grid.3x3.fill"
            ) {
                HStack(spacing: 8) {
                    VeilLCDDisplay(title: "MOVES", value: "\(controller.gomoku.moveCount)")
                        .frame(maxWidth: .infinity)
                    VeilLCDDisplay(
                        title: "CANDIDATES",
                        value: "\(GomokuBot.legalCandidateCount(in: controller.gomoku, radius: 2))"
                    )
                    .frame(maxWidth: .infinity)
                    VeilLCDDisplay(
                        title: "TURN",
                        value: controller.gomoku.currentPlayer == .host ? "YOU" : "BOT"
                    )
                    .frame(maxWidth: .infinity)
                }
            }

        case .xiangqi:
            let redCount = xiangqiPieceCount(side: .red)
            let blackCount = xiangqiPieceCount(side: .black)
            let legal = XiangqiBot.legalMoveCount(
                in: controller.xiangqi,
                actor: controller.xiangqi.currentPlayer
            )
            VeilInstrumentDeck(
                title: "象棋局势",
                subtitle: "显示双方子力、当前合法着数与将军状态。",
                symbol: "checkerboard.rectangle"
            ) {
                HStack(spacing: 8) {
                    VeilLCDDisplay(title: "RED", value: "\(redCount)")
                        .frame(maxWidth: .infinity)
                    VeilLCDDisplay(title: "BLACK", value: "\(blackCount)")
                        .frame(maxWidth: .infinity)
                    VeilLCDDisplay(title: "LEGAL", value: "\(legal)")
                        .frame(maxWidth: .infinity)
                }
                VeilStatusStrip(
                    leftTitle: "CHECK",
                    leftValue: controller.xiangqi.isCurrentPlayerInCheck ? "YES" : "NO",
                    rightTitle: "REPEAT",
                    rightValue: "\(controller.xiangqi.currentPositionRepetitionCount)x",
                    active: controller.xiangqi.isCurrentPlayerInCheck
                )
            }

        case .ludo:
            let dice = controller.ludo.expectedDice(sessionID: controller.sessionID)
            let legal = controller.ludo.legalPieces(sessionID: controller.sessionID).count
            VeilInstrumentDeck(
                title: "飞行棋局势",
                subtitle: "下一骰由本局 session seed 确定，双方状态可复现。",
                symbol: "die.face.5.fill"
            ) {
                HStack(spacing: 8) {
                    VeilLCDDisplay(title: "NEXT DICE", value: "\(dice)")
                        .frame(maxWidth: .infinity)
                    VeilLCDDisplay(title: "LEGAL", value: "\(legal)")
                        .frame(maxWidth: .infinity)
                    VeilLCDDisplay(
                        title: "FINISH",
                        value: "\(controller.ludo.finishedCount(for: .host))/4"
                    )
                    .frame(maxWidth: .infinity)
                }
                VeilStatusStrip(
                    leftTitle: "BOT FINISH",
                    leftValue: "\(controller.ludo.finishedCount(for: .guest))/4",
                    rightTitle: "TURN",
                    rightValue: controller.ludo.currentPlayer == .host ? "YOU" : "BOT",
                    active: true
                )
            }

        default:
            EmptyView()
        }
    }

    private func xiangqiPieceCount(side: XiangqiSide) -> Int {
        (0..<(XiangqiState.rows * XiangqiState.columns))
            .compactMap { controller.xiangqi.piece(at: $0) }
            .filter { $0.side == side }
            .count
    }

    private var arcadeControlCard: some View {
        VeilInstrumentDeck(
            title: "本地对手",
            subtitle: "只改变本机 Bot 的搜索精度与前视深度，不改变游戏规则或联机协议。",
            symbol: "cpu"
        ) {
            VStack(spacing: 9) {
                HStack {
                    VeilInstrumentLabel(
                        title: "DIFFICULTY",
                        value: controller.arcadeDifficulty.title,
                        active: true
                    )
                    Spacer()
                    VeilLCDDisplay(
                        title: "BOT MODE",
                        value: controller.arcadeDifficulty.telemetryLabel
                    )
                    .frame(width: 112)
                }

                HStack(spacing: 7) {
                    ForEach(ArcadeBotDifficulty.allCases) { difficulty in
                        Button {
                            controller.setArcadeDifficulty(difficulty)
                            model.haptics.selection()
                        } label: {
                            VStack(spacing: 2) {
                                Text(difficulty.title)
                                Text(difficulty.telemetryLabel)
                                    .font(.system(size: 6.5, weight: .black, design: .monospaced))
                                    .tracking(0.5)
                                    .opacity(0.72)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(
                            VeilCompactKeyStyle(
                                selected: difficulty == controller.arcadeDifficulty
                            )
                        )
                        .accessibilityLabel("难度 \(difficulty.title)")
                        .accessibilityValue(
                            difficulty == controller.arcadeDifficulty ? "当前选择" : "未选择"
                        )
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
                )
            }

            let detail: String = {
                switch game {
                case .artillery:
                    return "火控搜索步长：角度 \(controller.arcadeDifficulty.artilleryAngleStep)° / 力度 \(controller.arcadeDifficulty.artilleryPowerStep)%"
                case .lightTrail:
                    return "赛道前视：\(controller.arcadeDifficulty.lightTrailDepth) 个赛段"
                case .magneticHockey:
                    return "击球采样：角度 \(controller.arcadeDifficulty.hockeyAngleStep)° / 力度 \(controller.arcadeDifficulty.hockeyPowerStep)%"
                default:
                    return ""
                }
            }()
            Text(detail)
                .font(.caption2.monospaced())
                .foregroundColor(VeilTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.statusText)
                        .font(.headline)
                        .foregroundColor(controller.canHumanAct ? VeilTheme.goldBright : VeilTheme.text)
                    Text("你 vs 本地电脑 · 完全离线")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                if controller.isAIThinking {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("本地电脑正在思考")
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
                statusMetric("引擎", controller.lastDecisionMode)
                statusMetric("联网", "不需要")
                statusMetric("耗时", controller.lastDecisionMilliseconds.map { "\($0)ms" } ?? "--")
            }
        }
        .padding(14)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                emphasized: true
            )
        )
    }

    @ViewBuilder
    private var board: some View {
        switch game {
        case .gomoku:
            GomokuBoardView(state: controller.gomoku, localPlayer: .host, enabled: controller.canHumanAct) { index in
                controller.humanGomokuMove(index)
                model.haptics.impact()
            }
        case .xiangqi:
            XiangqiBoardView(
                state: controller.xiangqi,
                localPlayer: .host,
                enabled: controller.canHumanAct,
                selectedIndex: $selectedXiangqiIndex,
                onSelection: { model.haptics.selection() }
            ) { from, to in
                selectedXiangqiIndex = nil
                controller.humanXiangqiMove(from: from, to: to)
                model.haptics.impact()
            }
        case .ludo:
            LudoBoardView(
                state: controller.ludo,
                sessionID: controller.sessionID,
                localPlayer: .host,
                enabled: controller.canHumanAct,
                onRoll: { model.haptics.impact() }
            ) { piece in
                controller.humanLudoMove(piece: piece)
                model.haptics.impact()
            }
        case .tactical:
            TacticalBoardView(
                state: controller.tactical,
                localPlayer: .host,
                enabled: controller.canHumanAct,
                onMove: { from, to in
                    controller.humanTacticalMove(from: from, to: to)
                    model.haptics.impact()
                },
                onPass: {
                    controller.humanTacticalPass()
                    model.haptics.selection()
                }
            )
        case .artillery:
            ArtilleryGameView(
                state: controller.artillery,
                sessionID: controller.sessionID,
                localPlayer: .host,
                enabled: controller.canHumanAct
            ) { angle, power in
                controller.humanArtilleryShot(angle: angle, power: power)
                model.haptics.impact()
            }
        case .lightTrail:
            LightTrailGameView(
                state: controller.lightTrail,
                sessionID: controller.sessionID,
                localPlayer: .host,
                enabled: controller.canHumanAct
            ) { shift in
                controller.humanLightTrailShift(shift)
                model.haptics.selection()
            }
        case .magneticHockey:
            MagneticHockeyGameView(
                state: controller.magneticHockey,
                sessionID: controller.sessionID,
                localPlayer: .host,
                enabled: controller.canHumanAct
            ) { angle, power in
                controller.humanMagneticHockeyShot(angle: angle, power: power)
                model.haptics.impact()
            }
        }
    }

    private var resultCard: some View {
        VStack(spacing: 10) {
            Image(systemName: controller.outcome == .humanWon ? "trophy.fill" : (controller.outcome == .draw ? "equal.circle" : "cpu"))
                .font(.system(size: 34, weight: .light))
                .foregroundColor(VeilTheme.gold)
            Text(controller.statusText).font(.title3.bold())
            if game == .tactical {
                let report = controller.tacticalDebrief
                Text(report.headline)
                    .font(.headline)
                    .foregroundColor(VeilTheme.goldBright)
                Text(report.summary)
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                    .multilineTextAlignment(.center)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], spacing: 6) {
                    ForEach(report.medals, id: \.self) { medal in
                        Label(medal, systemImage: "medal.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(VeilTheme.gold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(VeilTheme.gold.opacity(0.09))
                            .clipShape(Capsule())
                    }
                }
            }
            Button("再来一局") {
                selectedXiangqiIndex = nil
                controller.restart()
            }
            .buttonStyle(VeilPhysicalButtonStyle(accent: true))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .veilCard()
    }

    private var tacticalControlCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.tacticalScenario.title)
                        .font(.headline)
                        .foregroundColor(VeilTheme.goldBright)
                    if controller.tacticalScenario == .daily {
                        Text("\(controller.tacticalDailyChallenge.dayID) · \(controller.tacticalDailyChallenge.title)")
                            .font(.caption2.monospaced())
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                }
                Spacer()
                Menu {
                    ForEach(TacticalBotDifficulty.allCases) { difficulty in
                        Button {
                            if let animation = VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion) {
                                withAnimation(animation) { controller.setTacticalDifficulty(difficulty) }
                            } else {
                                controller.setTacticalDifficulty(difficulty)
                            }
                            model.haptics.selection()
                        } label: {
                            if difficulty == controller.tacticalDifficulty {
                                Label(difficulty.title, systemImage: "checkmark")
                            } else {
                                Text(difficulty.title)
                            }
                        }
                    }
                } label: {
                    Label(controller.tacticalDifficulty.title, systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(VeilTheme.gold)
                }
            }

            HStack(spacing: 8) {
                ForEach(TacticalSoloScenario.allCases) { scenario in
                    Button {
                        if let animation = VeilMotionPolicy.animation(.transit, reduceMotionRequested: reduceMotion) {
                            withAnimation(animation) { controller.setTacticalScenario(scenario) }
                        } else {
                            controller.setTacticalScenario(scenario)
                        }
                        model.haptics.selection()
                    } label: {
                        Text(scenario.title)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .frame(minHeight: 34)
                            .background((controller.tacticalScenario == scenario ? VeilTheme.gold : Color.white).opacity(controller.tacticalScenario == scenario ? 0.12 : 0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(controller.tacticalScenario == scenario ? "已选择" : "未选择")
                    .accessibilityAddTraits(controller.tacticalScenario == scenario ? .isSelected : [])
                }
            }

            if controller.tacticalScenario == .daily {
                Text(controller.tacticalDailyChallenge.briefing)
                    .font(.caption)
                    .foregroundColor(VeilTheme.text)
                Label("勋章目标：\(controller.tacticalDailyChallenge.medalGoal)", systemImage: "medal")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.mutedGold)
            }

            Label(controller.tacticalCoachText, systemImage: "lightbulb.fill")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .id(controller.tacticalCoachText)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
        .veilCard()
        .animation(VeilMotionPolicy.animation(.reveal, reduceMotionRequested: reduceMotion), value: controller.tacticalCoachText)
    }

    private func statusMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(.caption2, design: .monospaced).weight(.bold)).foregroundColor(VeilTheme.tertiaryText)
            Text(value).font(.system(.caption2, design: .monospaced).weight(.semibold)).foregroundColor(VeilTheme.text).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
