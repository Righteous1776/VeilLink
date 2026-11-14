import SwiftUI
import UniformTypeIdentifiers
import VeilopolyUI


// ECLIPSE R17: purposely restricted to charcoal, white/silver, green, amber and red.
// This palette is scoped to the Gomoku experience, never the other game lobbies.
enum VeilEclipseChrome {
    static let black = Color(red: 0.032, green: 0.037, blue: 0.044)
    static let canvas = Color(red: 0.052, green: 0.058, blue: 0.065)
    static let panel = Color(red: 0.085, green: 0.094, blue: 0.105)
    static let raised = Color(red: 0.12, green: 0.13, blue: 0.14)
    static let silver = Color(red: 0.78, green: 0.81, blue: 0.82)
    static let white = Color(red: 0.95, green: 0.96, blue: 0.96)
    static let muted = Color(red: 0.53, green: 0.56, blue: 0.57)
    static let line = Color(red: 0.24, green: 0.28, blue: 0.28)
    static let green = Color(red: 0.19, green: 0.86, blue: 0.54)
    static let amber = Color(red: 0.96, green: 0.59, blue: 0.19)
    static let red = Color(red: 0.95, green: 0.27, blue: 0.27)
}

private struct VeilEclipseDeckSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VeilEclipseChrome.panel, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(VeilEclipseChrome.line, lineWidth: 0.9))
    }
}

// Rule-derived counts only; never fake a probability, internal engine thought,
// suggested coordinate, win-rate or search continuation.
private enum VeilEclipseThreatReadout {
    static func instantWins(on state: GomokuState, for player: MiniGamePlayer) -> Int {
        let own: Int8 = player == .host ? 1 : 2
        var threats = 0
        let directions: [(Int, Int)] = [(1, 0), (0, 1), (1, 1), (1, -1)]
        for index in 0..<(GomokuState.size * GomokuState.size) where state.value(at: index) == 0 {
            let row = index / GomokuState.size
            let col = index % GomokuState.size
            var qualifies = false
            for (dr, dc) in directions {
                var count = 1
                for sign in [-1, 1] {
                    var r = row + dr * sign, c = col + dc * sign
                    while (0..<GomokuState.size).contains(r), (0..<GomokuState.size).contains(c),
                          state.value(at: r * GomokuState.size + c) == own {
                        count += 1
                        r += dr * sign; c += dc * sign
                    }
                }
                if count >= 5 { qualifies = true; break }
            }
            if qualifies { threats += 1 }
        }
        return threats
    }
}

struct GameLobbyView: View {
    @ObservedObject var model: AppModel
    @State private var nearbyConversation: ConversationSummary?
    @State private var showsVeilopoly = false


    init(model: AppModel) {
        self.model = model
    }


    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero.veilStaggeredEntrance(index: 0)
                VeilopolyMultiplayerLobby(model: model)
                singlePlayerSection.veilStaggeredEntrance(index: 1)
                realtimeArcadeSection.veilStaggeredEntrance(index: 2)
                interactiveStorySection.veilStaggeredEntrance(index: 3)
                nearbySection.veilStaggeredEntrance(index: 4)
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
        .veilopolyFullscreen(isPresented: $showsVeilopoly, humanCount: 1)
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
                        .font(VeilType.terminalLabel)
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
            Button {
                model.haptics.selection()
                showsVeilopoly = true
            } label: {
                realtimeGameRow(title: "大富翁 · Veilopoly",
                    detail: "地产经营 · 银行与股市 · 城市快讯 · 自动续局",
                    motif: .circuit, badge: "离线")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("game-lobby.veilopoly")
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
                eclipseLobbyRow
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilEclipseChrome.green)
            NavigationLink(destination: LocalAIGameView(model: model, game: .xiangqi)) {
                gameRow(.xiangqi, detail: "可选红黑与先后手 · 四档棋力 · 自学习阵法预判", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
            NavigationLink(destination: LocalAIGameView(model: model, game: .ludo)) {
                gameRow(.ludo, detail: "确定性骰子 · 规则评分 Bot 自动完成回合", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
            NavigationLink(destination: TacticalV2SoloView(model: model)) {
                gameRow(.tactical, detail: "48×27 官渡大战场 · 战争迷雾 · 补给 · 袁军实时行动", enabled: true)
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
                        .padding(VeilSpacing.sm)
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


    private var realtimeArcadeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("实时渲染游戏", subtitle: "SpriteKit 2D + SceneKit 3D · 稳定帧循环 · 自适应画质")
            NavigationLink(destination: PrismRift3DGameView()) {
                realtimeGameRow(title: "棱镜裂隙 3D", detail: "动态灯光 · 三维隧道 · 3 阶 Boss · 能量与舰体管理", motif: .circuit, badge: "3D")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: AfterglowConvoyLabView()) {
                realtimeGameRow(title: "余烬护航", detail: "雨夜视差 · 信标伙伴 · 风暴护盾 · 程序化航线", motif: .tide, badge: "2D")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: AshHarborLabView()) {
                realtimeGameRow(title: "灰港", detail: "暴风救援 · 探照灯与船体管理 · 四组求救信号", motif: .tide, badge: "2D")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: RainlineLastTrainLabView()) {
                realtimeGameRow(title: "雨线末班车", detail: "实时列车调度 · 四类故障 · 夜雨材质与本地模型", motif: .comet, badge: "2D+")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: SignalDiveLabView()) {
                realtimeGameRow(title: "深潜信号", detail: "深海探索 · 主动声呐 · 生物回波与压力管理", motif: .pulse, badge: "2D+")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: BlackoutDistrictLabView()) {
                realtimeGameRow(title: "熄灯街区", detail: "实时抢修驾驶 · 12 节点电网 · 130+ 建筑单元", motif: .circuit, badge: "2D+")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: VeilPulseRunnerView()) {
                realtimeGameRow(title: "星隙快递", detail: "三段式横版平台跳跃 · 收集星核 · 冲刺", motif: .comet, badge: "2D")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: VeilVoidSwarmView()) {
                realtimeGameRow(title: "虚空蜂群", detail: "触控移动 · 自动射击 · 波次生存", motif: .guardian, badge: "2D")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: RhythmNeonView()) {
                realtimeGameRow(title: "霓虹节拍", detail: "节拍闪避 · 连击得分 · 超载冲刺", motif: .pulse, badge: "2D")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: VeilRhythmR6NativeGameView()) {
                realtimeGameRow(title: "实时节奏远征", detail: "SpriteKit 实时判定 · 原生渲染 · 自适应画质", motif: .pulse, badge: "2D")
            }
            .buttonStyle(.plain)
            NavigationLink(destination: LatticeClashLabView()) {
                realtimeGameRow(title: "晶格冲突", detail: "确定性单机策略 · 连锁占领 · 本地 Bot", motif: .circuit, badge: "策略")
            }
            .buttonStyle(.plain)
        }
    }


    private var interactiveStorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("互动剧情", subtitle: "剧情与游戏归入大厅，不再藏在工具箱")
            NavigationLink(destination: VeilStoryLabView()) {
                realtimeGameRow(
                    title: "故事实验室",
                    detail: "原生分支叙事 · 多结局 · 完全离线",
                    motif: .comet,
                    badge: "剧情"
                )
            }
            .buttonStyle(.plain)
            NavigationLink(destination: VeilMonogatariGameView()) {
                realtimeGameRow(
                    title: "雨幕之后 · Monogatari R6",
                    detail: "官方 2.8.0 完整引擎 · 东京雨夜 · 四种结局 · 本地存档",
                    motif: .tide,
                    badge: "VN"
                )
            }
            .buttonStyle(.plain)
            NavigationLink(destination: VeilMonogatariHostView()) {
                realtimeGameRow(
                    title: "VeilLink × Monogatari",
                    detail: "官方 v2.8.0 引擎 · 原创离线剧情 · 本地存档",
                    motif: .comet,
                    badge: "VN"
                )
            }
            .buttonStyle(.plain)
        }
    }


    private func realtimeGameRow(title: String, detail: String, motif: ArcadeVisualMotif, badge: String = "实时") -> some View {
        HStack(spacing: 12) {
            ArcadeVisualIcon(motif: motif, animated: false)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundColor(VeilTheme.text)
                Text(detail).font(.caption).foregroundColor(VeilTheme.secondaryText).lineLimit(2)
            }
            Spacer(minLength: 4)
            Text(badge)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(VeilTheme.goldBright)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(VeilTheme.tertiaryText)
        }
        .padding(12)
        .background(VeilTheme.elevated.opacity(0.86))
        .clipShape(VeilPanelShape(cut: 12, radius: 7))
        .overlay(VeilPanelShape(cut: 12, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }


    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(VeilType.cardTitle).foregroundColor(VeilTheme.goldBright)
            Text(subtitle).font(.caption).foregroundColor(VeilTheme.secondaryText)
        }
    }


    private var eclipseLobbyRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(VeilEclipseChrome.black)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(VeilEclipseChrome.line, lineWidth: 0.9)
                Image(systemName: "cpu")
                    .font(.system(size: 21, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilEclipseChrome.green)
            }
            .frame(width: 49, height: 49)
            VStack(alignment: .leading, spacing: 4) {
                Text("ECLIPSE  /  五子棋")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(VeilEclipseChrome.white)
                Text("7档原生 AI · 攻防搜索 · 计算控制台")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilEclipseChrome.silver)
                    .lineLimit(2)
            }
            Spacer(minLength: 3)
            Text("LOCAL")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(VeilEclipseChrome.green)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(VeilEclipseChrome.silver)
        }
        .padding(12)
        .background(VeilEclipseChrome.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(VeilEclipseChrome.line, lineWidth: 0.9))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("game-lobby.eclipse.r17")
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
                .font(VeilType.terminalLabel)
                .foregroundColor(enabled ? VeilTheme.gold : VeilTheme.tertiaryText)
            if enabled {
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(VeilTheme.tertiaryText)
            }
        }
        .padding(VeilSpacing.sm)
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
        .background(VeilTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}


struct LocalAIGameView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var ownerMode: OwnerModeController
    @ObservedObject private var developerLearningGate: DeveloperLearningLabGate
    let game: MiniGameKind
    @StateObject private var controller: LocalAIGameController
    @State private var selectedXiangqiIndex: Int?
    @State private var showsTacticalGuide = false
    @State private var showsLearningResetConfirmation = false
    @State private var showsBoardAdvanced = false
    @State private var showsLearningImporter = false
    @State private var showsLearningShare = false
    @State private var showsEclipseTrace = false
    @State private var eclipseSheetTab: EclipsePanelTab = .compute

    private enum EclipsePanelTab: Hashable { case compute, training }
    @State private var learningExportURL: URL?
    @State private var learningExchangeMessage: String?
    @AppStorage(VeilOpponentAvatarPolicy.preferenceKey) private var grokBotEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    init(model: AppModel, game: MiniGameKind) {
        self.model = model
        ownerMode = model.ownerMode
        developerLearningGate = model.developerLearningGate
        self.game = game
        _controller = StateObject(wrappedValue: LocalAIGameController(
            game: game,
            formationLibrary: game == .gomoku
                ? DeveloperFormationLibrary(game: game, keychain: model.keychain)
                : nil,
            matchStore: game == .gomoku || game == .xiangqi ? LocalBoardMatchStore(game: game) : nil
        ))
    }


    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if game == .gomoku {
                    eclipseWorkspace
                } else {
                statusCard
                if game == .gomoku {
                    VeilEclipseIdentityCard(
                        // The controller starts a 180ms pre-search pause;
                        // show actual computation effects only after its timestamp exists.
                        isThinking: controller.isAIThinking && controller.eclipseSearchStartedAt != nil,
                        matchFinished: controller.outcome != .playing,
                        lastCompletedMilliseconds: controller.lastDecisionMilliseconds,
                        actualSearchStartedAt: controller.eclipseSearchStartedAt,
                        difficultyTitle: controller.boardDifficulty.title,
                        openTrace: { showsEclipseTrace = true }
                    )
                    .veilCard()
                } else if VeilOpponentAvatarPolicy.shouldRender(
                    enabled: grokBotEnabled, hasComputerOpponent: true
                ) {
                    HStack(spacing: 12) {
                        VeilOpponentAvatarView(mood: grokBotMood, size: 76)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Grok bot").font(.caption.weight(.semibold))
                            Text(grokBotMood.label)
                                .font(.caption2).foregroundColor(VeilTheme.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .veilCard()
                    .accessibilityIdentifier("game.grok_bot.avatar")
                }
                if game == .gomoku || game == .xiangqi { boardQuickControls }
                if game == .tactical { tacticalControlCard }
                board
                if controller.outcome != .playing { resultCard }
                if game == .gomoku || game == .xiangqi { boardAdvancedPanel }
                }
            }
            .padding(14)
        }
        .background {
            if game == .gomoku { VeilEclipseChrome.canvas.ignoresSafeArea() }
            else { VeilAmbientBackground() }
        }
        .navigationTitle(game == .gomoku ? "ECLIPSE · 五子棋" : game.title + " · 人机")
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
            controller.resumeBoardMatchIfNeeded()
            if game == .tactical,
               !UserDefaults.standard.bool(forKey: TacticalSoloGuideView.completionKey) {
                showsTacticalGuide = true
            }
        }
        .onDisappear {
            controller.cancelAI()
            model.agent.setComputeFocus(.idle)
        }
        .onChange(of: developerLearningGate.isAuthorized) { authorized in
            if !authorized { controller.setDeveloperTeachingMode(false) }
        }
        .sheet(isPresented: $showsTacticalGuide) {
            TacticalSoloGuideView()
        }
        .sheet(isPresented: $showsEclipseTrace) {
            if game == .gomoku {
                VeilEclipseTraceSheet(
                    isThinking: controller.isAIThinking && controller.eclipseSearchStartedAt != nil,
                    matchFinished: controller.outcome != .playing,
                    lastCompletedMilliseconds: controller.lastDecisionMilliseconds,
                    actualSearchStartedAt: controller.eclipseSearchStartedAt,
                    committedMoves: controller.eclipseCompletedMoveHistory,
                    difficultyTitle: controller.boardDifficulty.title,
                    searchModeTitle: controller.boardSearchMode.title,
                    liveMetrics: nil, // No genuine R5/V9 streaming telemetry in main.
                    archivedMatchPage: { offset, limit in
                        controller.eclipseHistoryPage(offset: offset, limit: limit)
                    }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { game == .gomoku && showsBoardAdvanced },
            set: { showsBoardAdvanced = $0 }
        )) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("控制台分区", selection: $eclipseSheetTab) {
                            Text("计算引擎").tag(EclipsePanelTab.compute)
                            Text("训练档案").tag(EclipsePanelTab.training)
                        }
                        .pickerStyle(.segmented)
                        .padding(12)
                        if eclipseSheetTab == .compute { eclipseComputeControls }
                        else { learningCard }
                    }
                    .padding(.bottom, 24)
                }
                .background(VeilEclipseChrome.canvas.ignoresSafeArea())
                .navigationTitle("ECLIPSE / CONTROL")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { showsBoardAdvanced = false }
                            .foregroundColor(VeilEclipseChrome.green)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showsLearningShare, onDismiss: {
            if let learningExportURL {
                try? FileManager.default.removeItem(at: learningExportURL)
            }
            learningExportURL = nil
        }) {
            if let learningExportURL {
                ShareSheet(items: [learningExportURL])
            }
        }
        .fileImporter(
            isPresented: $showsLearningImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            guard game == .xiangqi,
                  case .success(let urls) = result,
                  let selectedURL = urls.first else { return }
            Task {
                do {
                    let url = try await VeilImportedFileAccess.materializeInBackground(
                        selectedURL,
                        acceptedExtensions: ["json"]
                    )
                    defer { VeilImportedFileAccess.removeStagedCopy(url) }
                    let report = try controller.importBoardLearning(from: url)
                    learningExchangeMessage = "增强训练包已导入：\(report.completedGames) 局、\(report.rememberedPositions) 个局面。"
                    model.haptics.selection()
                } catch {
                    learningExchangeMessage = error.localizedDescription
                }
            }
        }
        .alert(
            "棋谱训练包",
            isPresented: Binding(
                get: { learningExchangeMessage != nil },
                set: { if !$0 { learningExchangeMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) { learningExchangeMessage = nil }
        } message: {
            Text(learningExchangeMessage ?? "")
        }
        .confirmationDialog(
            "清空本地自学习棋谱？",
            isPresented: $showsLearningResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("清空棋谱与训练数据", role: .destructive) {
                controller.clearBoardLearning()
                model.haptics.selection()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会删除五子棋和中国象棋的本地训练数据，不影响对局功能。")
        }
    }


    // R17: A purposeful, code-driven cockpit for the Gomoku game only.
    private var eclipseWorkspace: some View {
        VStack(spacing: 12) {
            VeilEclipseDeckSurface {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu.fill")
                            .foregroundColor(VeilEclipseChrome.green)
                        Text("ECLIPSE  /  NATIVE INTELLIGENCE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(0.7)
                            .foregroundColor(VeilEclipseChrome.silver)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        Circle()
                            .fill(controller.isAIThinking ? VeilEclipseChrome.green : VeilEclipseChrome.muted)
                            .frame(width: 7, height: 7)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(controller.statusText)
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundColor(controller.canHumanAct ? VeilEclipseChrome.green : VeilEclipseChrome.white)
                        Spacer()
                        Text("OFFLINE  ·  15×15")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(VeilEclipseChrome.muted)
                    }
                    Picker("执子", selection: Binding(
                        get: { controller.humanPlayer },
                        set: { controller.setBoardHumanPlayer($0) }
                    )) {
                        Text("我方 · 黑").tag(MiniGamePlayer.host)
                        Text("我方 · 白").tag(MiniGamePlayer.guest)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("gomoku.eclipse.seat.picker")
                    if controller.didRestoreBoardMatch {
                        Label("已恢复上一局 · 本地自动存档", systemImage: "internaldrive")
                            .font(.caption2)
                            .foregroundColor(VeilEclipseChrome.silver)
                    }
                    if let warning = controller.boardMatchSaveWarning ?? controller.eclipseArchiveWarning {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(VeilEclipseChrome.red)
                    }
                }
            }
            VeilEclipseIdentityCard(
                isThinking: controller.isAIThinking && controller.eclipseSearchStartedAt != nil,
                matchFinished: controller.outcome != .playing,
                lastCompletedMilliseconds: controller.lastDecisionMilliseconds,
                actualSearchStartedAt: controller.eclipseSearchStartedAt,
                difficultyTitle: controller.boardDifficulty.title,
                openTrace: { showsEclipseTrace = true }
            )
            .padding(12)
            .background(VeilEclipseChrome.panel, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(VeilEclipseChrome.line, lineWidth: 0.9))

            VeilEclipseDeckSurface {
                VStack(spacing: 10) {
                    HStack {
                        Text("MATCH  /  TACTICAL BOARD")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(VeilEclipseChrome.silver)
                        Spacer()
                        Text(String(format: "PLY %03d", controller.gomoku.moveCount))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(VeilEclipseChrome.muted)
                    }
                    board
                    HStack {
                        Text("BLACK  /  WHITE")
                        Spacer()
                        Text(controller.canHumanAct ? "YOUR TURN" : controller.isAIThinking ? "SEARCHING" : "LOCKED")
                            .foregroundColor(controller.canHumanAct ? VeilEclipseChrome.green : VeilEclipseChrome.silver)
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilEclipseChrome.muted)
                }
            }
            if controller.outcome != .playing { eclipseResultPanel }
            eclipseTelemetryDeck
            eclipseThreatDeck
            eclipseControlDeck
        }
    }

    private var eclipseTelemetryDeck: some View {
        VeilEclipseDeckSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("01  /  SEARCH TELEMETRY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.silver)
                    Spacer()
                    Text("LAST DECISION")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.muted)
                }
                HStack(spacing: 8) {
                    eclipseMetric("VISITED NODES", controller.lastDecisionNodes.map { "\($0)" } ?? "—")
                    eclipseMetric("THINK TIME", controller.lastDecisionMilliseconds.map { "\($0) ms" } ?? "—")
                    eclipseMetric("TRAINED", "\(controller.trainedNativeGames) G")
                }
                Text(controller.lastDecisionMode)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(VeilEclipseChrome.muted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("记录的是上一手实际引擎结果，并非实时预测或胜率。")
                    .font(.caption2)
                    .foregroundColor(VeilEclipseChrome.muted)
            }
        }
    }

    private func eclipseMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(VeilEclipseChrome.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(VeilEclipseChrome.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(VeilEclipseChrome.black, in: RoundedRectangle(cornerRadius: 9))
    }

    private var eclipseThreatDeck: some View {
        let ai = VeilEclipseThreatReadout.instantWins(on: controller.gomoku, for: controller.aiPlayer)
        let human = VeilEclipseThreatReadout.instantWins(on: controller.gomoku, for: controller.humanPlayer)
        return VeilEclipseDeckSurface {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("02  /  TACTICAL SIGNAL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.silver)
                    Spacer()
                    Text("RULE VERIFIED")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.green)
                }
                HStack(spacing: 8) {
                    eclipseThreatBox("ECLIPSE 即时成五点", count: ai, accent: VeilEclipseChrome.green)
                    eclipseThreatBox("我方即时成五点", count: human, accent: human > 0 ? VeilEclipseChrome.amber : VeilEclipseChrome.silver)
                }
                Text("仅统计当前棋盘一步成五的空点数量，不展示坐标，不是模型置信度。")
                    .font(.caption2)
                    .foregroundColor(VeilEclipseChrome.muted)
            }
        }
    }

    private func eclipseThreatBox(_ title: String, count: Int, accent: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(count > 0 ? accent : VeilEclipseChrome.line)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(VeilEclipseChrome.muted)
                    .lineLimit(2)
                Text("\(count)")
                    .font(.system(size: 23, weight: .bold, design: .monospaced))
                    .foregroundColor(count > 0 ? accent : VeilEclipseChrome.silver)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(VeilEclipseChrome.black, in: RoundedRectangle(cornerRadius: 9))
    }

    private var eclipseControlDeck: some View {
        VeilEclipseDeckSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("03  /  ENGINE CONTROL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.silver)
                    Spacer()
                    Text("USER OVERRIDE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.green)
                }
                HStack(spacing: 8) {
                    Menu {
                        ForEach(BoardBotDifficulty.allCases) { level in
                            Button {
                                controller.setBoardDifficulty(level)
                                model.haptics.selection()
                            } label: {
                                if level == controller.boardDifficulty {
                                    Label(level.title, systemImage: "checkmark")
                                } else { Text(level.title) }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                            Text(controller.boardDifficulty.title)
                                .lineLimit(1).minimumScaleFactor(0.72)
                            Image(systemName: "chevron.down")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(VeilEclipseChrome.green)
                    .accessibilityIdentifier("board.difficulty.menu")
                    Toggle("深度搜索", isOn: Binding(
                        get: { controller.boardSearchMode == .full },
                        set: { controller.setBoardSearchMode($0 ? .full : .economy) }
                    ))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilEclipseChrome.silver)
                    .tint(VeilEclipseChrome.green)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityIdentifier("board.deepSearch.toggle")
                }
                HStack(spacing: 8) {
                    eclipseNavigationButton("思考与高级设置", icon: "slider.horizontal.3", tab: .compute)
                    eclipseNavigationButton("训练与阵法", icon: "brain.head.profile", tab: .training)
                }
                Button {
                    showsEclipseTrace = true
                    model.haptics.selection()
                } label: {
                    HStack {
                        Image(systemName: "terminal")
                        Text("打开 ECLIPSE 计算显示屏 / 赛后回放")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(VeilEclipseChrome.silver)
                    .padding(10)
                    .background(VeilEclipseChrome.black, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func eclipseNavigationButton(_ title: String, icon: String, tab: EclipsePanelTab) -> some View {
        Button {
            eclipseSheetTab = tab
            showsBoardAdvanced = true
            model.haptics.selection()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(VeilEclipseChrome.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(VeilEclipseChrome.raised, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(VeilEclipseChrome.line, lineWidth: 0.7))
        }
        .buttonStyle(.plain)
    }

    private var eclipseResultPanel: some View {
        VeilEclipseDeckSurface {
            VStack(spacing: 8) {
                Image(systemName: controller.outcome == .humanWon ? "trophy.fill" : "checkmark.shield")
                    .foregroundColor(controller.outcome == .humanWon ? VeilEclipseChrome.green : VeilEclipseChrome.silver)
                Text(controller.statusText)
                    .font(.headline)
                    .foregroundColor(VeilEclipseChrome.white)
                Button("重新挑战 ECLIPSE") {
                    controller.restart()
                    model.haptics.selection()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(VeilEclipseChrome.green)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var grokBotMood: VeilOpponentAvatarMood {
        if controller.isAIThinking { return .thinking }
        switch controller.outcome {
        case .playing: return .idle
        case .aiWon: return .won
        case .humanWon: return .lost
        case .draw: return .draw
        }
    }


    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            if game == .gomoku || game == .xiangqi {
                Picker("你的棋子", selection: Binding(
                    get: { controller.humanPlayer },
                    set: { controller.setBoardHumanPlayer($0) }
                )) {
                    Text(game == .gomoku ? "黑 · 先手" : "红 · 先手").tag(MiniGamePlayer.host)
                    Text(game == .gomoku ? "白 · 后手" : "黑 · 后手").tag(MiniGamePlayer.guest)
                }
                .pickerStyle(.segmented)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.statusText)
                        .font(.headline)
                        .foregroundColor(controller.canHumanAct ? VeilTheme.goldBright : VeilTheme.text)
                    Text("你 vs 本地电脑 · 完全离线")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                    if controller.didRestoreBoardMatch {
                        Text("已恢复上次棋局 · 每步自动保存")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.gold)
                    }
                    if let warning = controller.boardMatchSaveWarning {
                        Text(warning)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    if let warning = controller.eclipseArchiveWarning, game == .gomoku {
                        Text(warning)
                            .font(.caption2)
                            .foregroundColor(VeilTheme.danger)
                    }
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


    // Keep the board visible above the fold: one compact difficulty menu and
    // one user-controlled search switch. No device model may disable this.
    private var boardQuickControls: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(game == .gomoku ? BoardBotDifficulty.allCases : BoardBotDifficulty.xiangqiCases) { difficulty in
                    Button {
                        controller.setBoardDifficulty(difficulty)
                        model.haptics.selection()
                    } label: {
                        if difficulty == controller.boardDifficulty {
                            Label(difficulty.title, systemImage: "checkmark")
                        } else {
                            Text(difficulty.title)
                        }
                    }
                }
            } label: {
                Label(controller.boardDifficulty.title, systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(VeilTheme.goldBright)
            }
            .accessibilityIdentifier("board.difficulty.menu")


            Spacer(minLength: 4)


            Toggle(isOn: Binding(
                get: { controller.boardSearchMode == .full },
                set: { controller.setBoardSearchMode($0 ? .full : .economy) }
            )) {
                Text("深度搜索")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.text)
            }
            .tint(VeilTheme.gold)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("board.deepSearch.toggle")
            .accessibilityHint("默认开启；任何设备都可使用。关闭后采用节能搜索预算。")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(VeilTheme.elevated.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }


    private var boardAdvancedPanel: some View {
        VStack(spacing: 9) {
            Button {
                showsBoardAdvanced.toggle()
                model.haptics.selection()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(VeilTheme.gold)
                    Text("训练与高级设置")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(VeilTheme.text)
                    Spacer(minLength: 6)
                    Text(controller.learningSummary.compactText)
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(VeilTheme.secondaryText)
                        .lineLimit(1)
                    Image(systemName: showsBoardAdvanced ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundColor(VeilTheme.goldBright)
                }
                .padding(12)
                .background(VeilTheme.elevated.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("board.advanced.toggle")
            .accessibilityValue(showsBoardAdvanced ? "已展开" : "已收起")


            if showsBoardAdvanced {
                learningCard
            }
        }
    }


    // R17: Every control below writes to the R16 engine options, not demo state.
    private var eclipseComputeControls: some View {
        let options = controller.eclipseAdvancedOptions
        return VStack(alignment: .leading, spacing: 13) {
            VeilEclipseDeckSurface {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("COMPUTE / TIME BUDGET", systemImage: "brain")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(VeilEclipseChrome.white)
                        Spacer()
                        Text("LIVE CONFIG")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(VeilEclipseChrome.green)
                    }
                    Picker("思考时长", selection: Binding(
                        get: { options.thinkingMode },
                        set: { mode in
                            var next = controller.eclipseAdvancedOptions
                            next.thinkingMode = mode
                            controller.setEclipseAdvancedOptions(next)
                        }
                    )) {
                        Text("自动").tag(EclipseThinkingMode.automatic)
                        Text("自定").tag(EclipseThinkingMode.custom)
                        Text("不限时").tag(EclipseThinkingMode.untimed)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("gomoku.eclipse.thinking.mode")
                    if options.thinkingMode == .custom {
                        HStack {
                            Text("TIME LIMIT")
                            Spacer()
                            Text("\(options.seconds) s")
                                .foregroundColor(VeilEclipseChrome.green)
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.silver)
                        Slider(value: Binding(
                            get: { Double(options.seconds) },
                            set: { value in
                                var next = controller.eclipseAdvancedOptions
                                next.seconds = Int(value.rounded())
                                controller.setEclipseAdvancedOptions(next)
                            }
                        ), in: 5...300, step: 5)
                        .tint(VeilEclipseChrome.green)
                        .accessibilityIdentifier("gomoku.eclipse.thinking.seconds.slider")
                    } else {
                        Text(options.thinkingMode == .untimed
                             ? "NO HARD TIMER · 由搜索节点与深度保护结束计算"
                             : "AUTO BUDGET · 当前难度自动决定每步搜索上限")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(options.thinkingMode == .untimed ? VeilEclipseChrome.green : VeilEclipseChrome.muted)
                    }
                    if options.thinkingMode != .automatic {
                        Divider().overlay(VeilEclipseChrome.line)
                        HStack {
                            Text("NODE BUDGET")
                            Spacer()
                            Text("\(options.maxNodes / 1_000) K")
                                .foregroundColor(VeilEclipseChrome.green)
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.silver)
                        Slider(value: Binding(
                            get: { Double(options.maxNodes) },
                            set: { value in
                                var next = controller.eclipseAdvancedOptions
                                next.maxNodes = Int(value.rounded() / 50_000) * 50_000
                                controller.setEclipseAdvancedOptions(next)
                            }
                        ), in: 50_000...2_000_000, step: 50_000)
                        .tint(VeilEclipseChrome.green)
                        .accessibilityIdentifier("gomoku.eclipse.thinking.nodes.slider")
                        HStack {
                            Text("DEPTH CEILING")
                            Spacer()
                            Text("D\(options.maxDepth)")
                                .foregroundColor(VeilEclipseChrome.green)
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.silver)
                        Slider(value: Binding(
                            get: { Double(options.maxDepth) },
                            set: { value in
                                var next = controller.eclipseAdvancedOptions
                                next.maxDepth = Int(value.rounded())
                                controller.setEclipseAdvancedOptions(next)
                            }
                        ), in: 3...12, step: 1)
                        .tint(VeilEclipseChrome.green)
                        .accessibilityIdentifier("gomoku.eclipse.thinking.depth.slider")
                    }
                }
            }
            VeilEclipseDeckSurface {
                VStack(alignment: .leading, spacing: 13) {
                    Text("TACTICAL MODULES / MANUAL OVERRIDE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.silver)
                    Toggle(isOn: Binding(
                        get: { options.r12Enabled },
                        set: { enabled in
                            var next = controller.eclipseAdvancedOptions
                            next.r12Enabled = enabled
                            controller.setEclipseAdvancedOptions(next)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("R12  /  强制攻防延伸").foregroundColor(VeilEclipseChrome.white)
                            Text("默认开启 · 叶节点继续处理强制攻防")
                                .font(.caption2).foregroundColor(VeilEclipseChrome.muted)
                        }
                    }
                    .tint(VeilEclipseChrome.green)
                    .accessibilityIdentifier("gomoku.eclipse.r12.toggle")
                    Divider().overlay(VeilEclipseChrome.line)
                    Toggle(isOn: Binding(
                        get: { options.r13Enabled },
                        set: { enabled in
                            var next = controller.eclipseAdvancedOptions
                            next.r13Enabled = enabled
                            controller.setEclipseAdvancedOptions(next)
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("R13  /  增量威胁索引").foregroundColor(VeilEclipseChrome.white)
                            Text("实验开关 · 需进一步确认真机性能")
                                .font(.caption2).foregroundColor(VeilEclipseChrome.muted)
                        }
                    }
                    .tint(VeilEclipseChrome.green)
                    .accessibilityIdentifier("gomoku.eclipse.r13.toggle")
                }
            }
            VeilEclipseDeckSurface {
                VStack(alignment: .leading, spacing: 5) {
                    Label("THERMAL / POWER NOTICE", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilEclipseChrome.amber)
                    Text("长时间深度搜索可能明显增加耗电与发热。设置从下一手起生效；退出棋局可取消计算。")
                        .font(.caption)
                        .foregroundColor(VeilEclipseChrome.silver)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 12)
        .accessibilityIdentifier("gomoku.eclipse.advanced.console")
    }

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("本地自学习棋手")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(VeilTheme.text)
                    Text(controller.learningSummary.compactText)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.goldBright)
                }
                Spacer()
                Button("清空") { showsLearningResetConfirmation = true }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.secondaryText)
            }
            Text("五子棋与象棋分别保存本地棋谱；训练经验只影响对应的原生棋手。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if game == .gomoku {
                Toggle(isOn: Binding(
                    get: { controller.eclipseVisualizationEnabled },
                    set: { controller.setEclipseVisualizationEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("棋盘思考可视化").font(.caption.weight(.semibold))
                        Text("仅原生搜索显示真实分支；可能透露策略，默认关闭。")
                            .font(.caption2).foregroundColor(VeilTheme.secondaryText)
                    }
                }
                .tint(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.gold)
                .accessibilityIdentifier("gomoku.eclipse.live-trace.toggle")
                HStack(spacing: 8) {
                    Image(systemName: "cpu").foregroundColor(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.goldBright)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ECLIPSE 原生搜索")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(VeilTheme.text)
                        Text("统一原生战术安全门、训练排序与深度搜索")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                }
                Menu {
                    ForEach(GomokuFormationMode.allCases) { mode in
                        Button {
                            controller.setGomokuFormationMode(mode)
                            model.haptics.selection()
                        } label: {
                            if mode == controller.gomokuFormationMode {
                                Label(mode.title, systemImage: "checkmark")
                            } else {
                                Text(mode.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                        Text("阵法学习")
                            .font(.caption.weight(.semibold))
                        Spacer(minLength: 0)
                        Text(controller.gomokuFormationMode.title)
                            .font(.caption2)
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .foregroundColor(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.goldBright)
                    .padding(10)
                    .background(VeilTheme.subtleFillStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityLabel("五子棋阵法学习模式")
                Text("已发现 \(controller.discoveredGomokuFormations) 类阵法；阵法偏好时由原生引擎落子。")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "repeat.circle")
                            .foregroundColor(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.gold)
                        Text("原生 Bot 自对弈训练")
                            .font(.caption.weight(.bold))
                        Spacer()
                        Text("已实战 \(controller.trainedNativeGames) 局")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.goldBright)
                    }
                    Text("原生 Bot 离线自对弈，仅完整胜负局计数；使用训练经验时会切到原生搜索。")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                    Toggle("允许原生 Bot 使用已保存的自对弈经验", isOn: Binding(
                        get: { controller.useNativeTrainingEvidence },
                        set: { controller.setUseNativeTrainingEvidence($0) }
                    ))
                    .font(.caption2)
                    .tint(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.gold)
                    if controller.isNativeTraining {
                        ProgressView(
                            value: Double(controller.nativeTrainingCompleted),
                            total: Double(max(1, controller.nativeTrainingTarget))
                        )
                        HStack {
                            Text("\(controller.nativeTrainingCompleted)/\(controller.nativeTrainingTarget) 局已保存")
                                .font(.caption.monospacedDigit())
                            Spacer()
                            Button("停止训练") { controller.stopNativeTraining() }
                                .font(.caption.weight(.semibold))
                        }
                    } else {
                        Menu {
                            Button("原生自对弈 10 局") { controller.startNativeTraining(games: 10) }
                            Button("原生自对弈 100 局") { controller.startNativeTraining(games: 100) }
                            Button("原生自对弈 1000 局（长时间前台运行）") {
                                controller.startNativeTraining(games: 1_000)
                            }
                        } label: {
                            Label("开始真正的 Bot 自对弈", systemImage: "play.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.goldBright)
                        }
                    }
                    Text(controller.nativeTrainingMessage)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        do {
                            learningExportURL = try controller.exportNativeSelfPlayDetails()
                            showsLearningShare = true
                        } catch {
                            learningExchangeMessage = error.localizedDescription
                        }
                    } label: {
                        Label("导出自对弈明细（逐手棋谱）", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.trainedNativeGames == 0 || controller.isImportingNativeSeed)
                    .accessibilityHint("包含每局胜负、保存时间、双方逐手落点与阵法统计")
                }
                .padding(10)
                .background(VeilTheme.subtleFillStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(controller.coachProfile.levelText + " · " + controller.coachProfile.preferredOpening)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.text)
                Text(controller.coachProfile.nextLesson)
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
                Text(controller.coachProfile.reviewFocus)
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(controller.coachTip)
                    .font(.caption2)
                    .foregroundColor(game == .gomoku ? VeilEclipseChrome.green : VeilTheme.goldBright)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(9)
            .background((game == .gomoku ? VeilEclipseChrome.green : VeilTheme.gold).opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            HStack(spacing: 10) {
                Button {
                    do {
                        learningExportURL = try controller.exportBoardLearning()
                        showsLearningShare = true
                    } catch {
                        learningExchangeMessage = error.localizedDescription
                    }
                } label: {
                    Label("导出训练包", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)


                if game == .gomoku {
                    if ownerMode.isAuthorized(for: .developerTraining),
                       model.appLock.isEnabled,
                       !model.appLock.isLocked,
                       developerLearningGate.canImportTraining() {
                        NavigationLink(destination: BoardDeveloperLearningLabView(
                            model: model,
                            controller: controller,
                            game: game
                        )) {
                            Label("开发训练室", systemImage: "lock.shield")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button { showsLearningImporter = true } label: {
                        Label("导入增强包", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .font(.caption.weight(.semibold))
            if !controller.learningStoreAvailable {
                Label("训练数据暂时无法写入，当前对局仍可正常进行", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.danger)
            }
        }
        .veilCard()
    }


    @ViewBuilder
    private var board: some View {
        switch game {
        case .gomoku:
            GomokuBoardView(
                state: controller.gomoku,
                localPlayer: controller.humanPlayer,
                enabled: controller.canHumanAct || (
                    controller.developerTeachingMode
                        && ownerMode.isAuthorized(for: .developerTraining)
                        && model.appLock.isEnabled
                        && !model.appLock.isLocked
                        && developerLearningGate.canImportTraining()
                ),
                eclipseThinking: controller.isAIThinking && controller.eclipseSearchStartedAt != nil,
                actualSearchStartedAt: controller.eclipseSearchStartedAt,
                eclipseVisualizationEnabled: controller.eclipseVisualizationEnabled,
                eclipseTraceStore: controller.eclipseTraceStore,
                eclipseSessionID: controller.sessionID,
                eclipseBoardTurn: controller.gomoku.moveCount,
                eclipseMatchPlaying: controller.outcome == .playing,
                eclipseConsoleStyle: true
            ) { index in
                if controller.developerTeachingMode,
                   ownerMode.isAuthorized(for: .developerTraining),
                   model.appLock.isEnabled,
                   !model.appLock.isLocked,
                   developerLearningGate.canImportTraining() {
                    controller.developerGomokuMove(index)
                } else {
                    controller.humanGomokuMove(index)
                }
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
                            .background(controller.tacticalScenario == scenario ? VeilTheme.gold.opacity(0.12) : VeilTheme.subtleFill)
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
        .background(VeilTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

