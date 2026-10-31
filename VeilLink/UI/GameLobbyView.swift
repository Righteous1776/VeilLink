import SwiftUI
import UniformTypeIdentifiers

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
                gameRow(.gomoku, detail: "你执黑先手 · 四档棋力 · 个性化本地陪练", enabled: true)
            }
            .buttonStyle(VeilPressStyle())
            .veilSpatialPress(maximumTilt: 4.2, cornerRadius: 12, highlightColor: VeilTheme.goldBright)
            NavigationLink(destination: LocalAIGameView(model: model, game: .xiangqi)) {
                gameRow(.xiangqi, detail: "你执红先手 · 四档棋力 · 自学习阵法预判", enabled: true)
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
    @State private var showsLearningImporter = false
    @State private var showsLearningShare = false
    @State private var learningExportURL: URL?
    @State private var learningExchangeMessage: String?
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
                : nil
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusCard
                if game == .gomoku || game == .xiangqi { learningCard }
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
        .onChange(of: developerLearningGate.isAuthorized) { authorized in
            if !authorized { controller.setDeveloperTeachingMode(false) }
        }
        .sheet(isPresented: $showsTacticalGuide) {
            TacticalSoloGuideView()
        }
        .sheet(isPresented: $showsLearningShare, onDismiss: { learningExportURL = nil }) {
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

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(VeilTheme.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("本地自学习棋手")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(VeilTheme.text)
                    Text(controller.learningSummary.compactText)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(VeilTheme.goldBright)
                }
                Spacer()
                Button("清空") { showsLearningResetConfirmation = true }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.secondaryText)
            }
            Text("五子棋与中国象棋分别建库；每一局和每个合法局面都会保留。重复阵法会按走子序列预测你的下一步，并把输局与中断局反馈到下一局决策。全程离线，不设固定局面或容量上限，仅受设备可用空间约束。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if game == .gomoku {
                Toggle(isOn: Binding(
                    get: { controller.useExternalGomokuEngine },
                    set: { controller.setExternalGomokuEngineEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("离线强力引擎 · PVS/VCF")
                            .font(.caption.weight(.semibold))
                        Text("实验功能：默认关闭，遇到异常自动回退原生 AI；独立引擎不修改你的棋谱")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                }
                .tint(VeilTheme.gold)
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
                    .foregroundColor(VeilTheme.goldBright)
                    .padding(10)
                    .background(VeilTheme.subtleFillStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityLabel("五子棋阵法学习模式")
                Text("系统可自主选择八卦、进攻、防守偏好，或由玩家指定。已发现候选：\(controller.discoveredGomokuFormations) 类。阵法不能覆盖必胜/必防；启用阵法偏好时使用原生搜索，PVS/VCF 在关闭阵法后恢复。云盘棋形模型仍处于离线验证阶段。")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "repeat.circle")
                            .foregroundColor(VeilTheme.gold)
                        Text("原生 Bot 自对弈训练")
                            .font(.caption.weight(.bold))
                        Spacer()
                        Text("已实战 \(controller.trainedNativeGames) 局")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(VeilTheme.goldBright)
                    }
                    Text("真正调用本 App 的 GomokuBot 落子，完整对局保存到独立学习档案；图片分类训练不计入局数。训练仅在此页面前台运行。")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                    Toggle("允许原生 Bot 使用已保存的自对弈经验", isOn: Binding(
                        get: { controller.useNativeTrainingEvidence },
                        set: { controller.setUseNativeTrainingEvidence($0) }
                    ))
                    .font(.caption2)
                    .tint(VeilTheme.gold)
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
                                .foregroundColor(VeilTheme.goldBright)
                        }
                    }
                    Text(controller.nativeTrainingMessage)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(VeilTheme.subtleFillStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            HStack(spacing: 8) {
                Label(controller.boardDifficulty.title, systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.goldBright)
                Text(controller.boardDifficulty.detail)
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
                Spacer(minLength: 0)
                Menu {
                    ForEach(BoardBotDifficulty.allCases) { difficulty in
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
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundColor(VeilTheme.goldBright)
                }
            }
            .padding(9)
            .background(VeilTheme.subtleFillStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .foregroundColor(VeilTheme.goldBright)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(9)
            .background(VeilTheme.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                localPlayer: .host,
                enabled: controller.canHumanAct || (
                    controller.developerTeachingMode
                        && ownerMode.isAuthorized(for: .developerTraining)
                        && model.appLock.isEnabled
                        && !model.appLock.isLocked
                        && developerLearningGate.canImportTraining()
                )
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
