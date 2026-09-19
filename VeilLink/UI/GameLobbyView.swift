import SwiftUI

struct GameLobbyView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var controls: AgentControlCenterSettings
    @State private var nearbyConversation: ConversationSummary?

    init(model: AppModel) {
        self.model = model
        controls = model.agentControls
    }

    var body: some View {
        VeilStableScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                singlePlayerSection
                nearbySection
            }
        }
        .background(VeilAmbientBackground())
        .navigationTitle("游戏")
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
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
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

            HStack(spacing: 8) {
                lobbyMetric("AI", controls.gameDecisionMode.title)
                lobbyMetric("VFLY", model.maleCNS.state.displayName)
                lobbyMetric("联网", "不需要")
            }
        }
        .veilCard(emphasized: true)
    }

    private var singlePlayerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("单机 · 人机对战", subtitle: "规则、策略和 MaleCNS 全部在本机运行")
            NavigationLink(destination: LocalAIGameView(model: model, game: .gomoku)) {
                gameRow(.gomoku, detail: "你执黑先手 · 基础策略 + 可选 MaleCNS 重排", enabled: true)
            }.buttonStyle(VeilPressStyle())
            NavigationLink(destination: LocalAIGameView(model: model, game: .xiangqi)) {
                gameRow(.xiangqi, detail: "你执红先手 · 合法着法由原规则引擎裁决", enabled: true)
            }.buttonStyle(VeilPressStyle())
            NavigationLink(destination: LocalAIGameView(model: model, game: .ludo)) {
                gameRow(.ludo, detail: "确定性骰子 · AI 自动完成自己的回合", enabled: true)
            }.buttonStyle(VeilPressStyle())
            gameRow(.tactical, detail: "三国兵棋 AI 尚未训练 · 当前只开放附近真人对战", enabled: false)
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
                                Text("五子棋 · 象棋 · 飞行棋 · 三国兵棋")
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
            Text(enabled ? "人机" : "待训练")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(enabled ? VeilTheme.gold : VeilTheme.tertiaryText)
            if enabled {
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(VeilTheme.tertiaryText)
            }
        }
        .padding(13)
        .background(VeilTheme.elevated.opacity(enabled ? 0.86 : 0.52))
        .clipShape(VeilPanelShape(cut: 12, radius: 7))
        .overlay(VeilPanelShape(cut: 12, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
    }

    private func lobbyMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(VeilTheme.tertiaryText)
            Text(value).font(.system(size: 10.5, weight: .semibold, design: .monospaced)).foregroundColor(VeilTheme.text).lineLimit(1).minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct LocalAIGameView: View {
    @ObservedObject var model: AppModel
    let game: MiniGameKind
    @StateObject private var controller: LocalAIGameController
    @State private var selectedXiangqiIndex: Int?

    init(model: AppModel, game: MiniGameKind) {
        self.model = model
        self.game = game
        _controller = StateObject(wrappedValue: LocalAIGameController(
            game: game,
            maleCNS: model.maleCNS,
            controls: model.agentControls
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                statusCard
                board
                if controller.outcome != .playing { resultCard }
            }
            .padding(14)
        }
        .background(VeilAmbientBackground().ignoresSafeArea())
        .navigationTitle(game.title + " · 人机")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
            model.maleCNS.prepareFromBundle()
        }
        .onDisappear {
            controller.cancelAI()
            model.agent.setComputeFocus(.idle)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.statusText)
                        .font(.headline)
                        .foregroundColor(controller.canHumanAct ? VeilTheme.goldBright : VeilTheme.text)
                    Text("你 vs 灵核 AI · 完全本地")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                if controller.isAIThinking { ProgressView().controlSize(.small) }
            }
            HStack(spacing: 8) {
                statusMetric("决策", controller.lastDecisionMode)
                statusMetric("VFLY", model.maleCNS.state.displayName)
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
            VStack(spacing: 12) {
                Image(systemName: "map.fill").font(.system(size: 42)).foregroundColor(VeilTheme.gold)
                Text("三国兵棋的人机策略仍在专项训练中")
                    .font(.headline)
                Text("目前可以从游戏大厅的“附近对战”继续真人官渡对局。")
                    .font(.caption).foregroundColor(VeilTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(30)
            .veilCard()
        }
    }

    private var resultCard: some View {
        VStack(spacing: 10) {
            Image(systemName: controller.outcome == .humanWon ? "trophy.fill" : (controller.outcome == .draw ? "equal.circle" : "cpu"))
                .font(.system(size: 34, weight: .light))
                .foregroundColor(VeilTheme.gold)
            Text(controller.statusText).font(.title3.bold())
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

    private func statusMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(VeilTheme.tertiaryText)
            Text(value).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(VeilTheme.text).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
