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
        .background(VeilAmbientBackground())
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
        .veilCard(emphasized: true)
        .veilSpatialPress(maximumTilt: 3.8, cornerRadius: 20, highlightColor: VeilTheme.goldBright)
        .veilDynamicGlow(active: true, emphasized: true)
    }

    private var singlePlayerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("单机 · 本地电脑", subtitle: "棋盘策略 + 2D 物理与赛道玩法，全部离线运行")
            NavigationLink(destination: LocalAIGameView(model: model, game: .artillery)) {
                gameRow(.artillery, detail: "可视化弹道 · 确定性风力 · 本地参数搜索 Bot", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
            NavigationLink(destination: LocalAIGameView(model: model, game: .lightTrail)) {
                gameRow(.lightTrail, detail: "动态赛道 · 闪避与能量 · 本地预判 Bot", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
            NavigationLink(destination: LocalAIGameView(model: model, game: .magneticHockey)) {
                gameRow(.magneticHockey, detail: "固定步物理 · 磁场偏转 · 三球决胜", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
            NavigationLink(destination: LocalAIGameView(model: model, game: .gomoku)) {
                gameRow(.gomoku, detail: "你执黑先手 · 威胁识别 + 候选搜索 + 规则校验", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
            NavigationLink(destination: LocalAIGameView(model: model, game: .xiangqi)) {
                gameRow(.xiangqi, detail: "你执红先手 · Alpha-Beta + 局面评估 + 规则校验", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
            NavigationLink(destination: LocalAIGameView(model: model, game: .ludo)) {
                gameRow(.ludo, detail: "确定性骰子 · 规则评分 Bot 自动完成回合", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
            NavigationLink(destination: LocalAIGameView(model: model, game: .tactical)) {
                gameRow(.tactical, detail: "你执曹军先行 · 离线训练策略 + 补给与目标评估", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
        }
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
                    .veilSpatialPress(maximumTilt: 4.0, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
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
        .background(VeilTheme.elevated.opacity(enabled ? 0.86 : 0.52))
        .clipShape(VeilPanelShape(cut: 12, radius: 7))
        .overlay(VeilPanelShape(cut: 12, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
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
                if game == .tactical { tacticalControlCard }
                board
                if controller.outcome != .playing { resultCard }
            }
            .padding(14)
        }
        .background(VeilAmbientBackground())
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
        .veilCard(emphasized: true)
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
            .buttonStyle(VeilGamePrimaryButtonStyle())
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
