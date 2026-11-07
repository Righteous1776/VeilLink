import SwiftUI

struct AgentGameAssistantSheet: View {
    @ObservedObject var model: AppModel
    let conversation: ConversationSummary
    let session: MiniGameSessionSnapshot

    @ObservedObject private var intelligence: AgentGameContextBroker
    @ObservedObject private var controls: AgentControlCenterSettings
    @Environment(\.dismiss) private var dismiss
    @State private var actionStatus: String?

    init(model: AppModel, conversation: ConversationSummary, session: MiniGameSessionSnapshot) {
        self.model = model
        self.conversation = conversation
        self.session = session
        _intelligence = ObservedObject(wrappedValue: model.gameIntelligence)
        _controls = ObservedObject(wrappedValue: model.agentControls)
    }

    private var nativeMoveSupported: Bool {
        [.gomoku, .xiangqi, .ludo].contains(session.game)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                contextCard
                quickActions
                AgentChatView(coordinator: model.agent)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(VeilAmbientBackground())
            .navigationTitle("灵核 · \(session.game.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            model.updateAgentGameContext(session, conversation: conversation)
            actionStatus = model.refreshAgentGameRecommendation()
            model.agent.setComputeFocus(.gameDecision)
            model.agent.activate()
        }
        .onDisappear {
            model.agent.setComputeFocus(.gameDecision)
        }
        .onChange(of: model.messagesRevision) { _ in
            actionStatus = model.refreshAgentGameRecommendation()
        }
    }

    @ViewBuilder
    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("当前对局", systemImage: "gamecontroller.fill")
                    .font(.caption.weight(.bold))
                    .foregroundColor(VeilTheme.gold)
                Spacer()
                if let context = intelligence.context {
                    Text(context.isLocalTurn ? "你的回合" : "等待对方")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(context.isLocalTurn ? VeilTheme.goldBright : VeilTheme.secondaryText)
                }
            }

            if let context = intelligence.context {
                HStack(spacing: 8) {
                    infoChip("TURN", "\(context.turn)")
                    infoChip("POLICY", context.policyMode)
                    infoChip("FLY", context.maleCNS == nil ? "WAIT" : "READY")
                }

                if context.recommendations.isEmpty {
                    Text(context.note ?? "当前没有经过策略模型排序的合法动作。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(context.recommendations.prefix(3).enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                Text("\(index + 1)")
                                    .font(.caption2.bold().monospacedDigit())
                                    .foregroundColor(VeilTheme.gold)
                                Text(item.label)
                                    .font(.caption)
                                    .foregroundColor(VeilTheme.text)
                                Spacer()
                                if let score = item.score {
                                    Text(String(format: "%.3f", score))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundColor(VeilTheme.tertiaryText)
                                }
                            }
                        }
                    }
                }

                if nativeMoveSupported && !controls.allowSuggestedGameMoveExecution {
                    Text("执行建议着法默认关闭。可以只查看推荐；若要手动发送，需先在下方明确开启权限。")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }

                if let fly = context.maleCNS {
                    Text("MaleCNS 辅助：\(fly.topReadouts.prefix(2).joined(separator: " · "))")
                        .font(.caption2.monospaced())
                        .foregroundColor(VeilTheme.tertiaryText)
                        .lineLimit(2)
                }
            } else {
                Text("正在读取本机棋局状态…")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
            }

            if let actionStatus {
                Text(actionStatus)
                    .font(.caption2)
                    .foregroundColor(VeilTheme.gold)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(VeilTheme.panel.opacity(0.82))
        .clipShape(VeilPanelShape(cut: 11, radius: 7))
        .overlay(VeilPanelShape(cut: 11, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            if nativeMoveSupported {
                Toggle(isOn: Binding(
                    get: { controls.allowSuggestedGameMoveExecution },
                    set: { model.setAgentSuggestedGameMoveExecutionEnabled($0) }
                )) {
                    Text("允许手动执行规则引擎建议")
                        .font(.caption.weight(.semibold))
                }
                .tint(VeilTheme.gold)
                .accessibilityIdentifier("agent-game-move-execution-permission")
                Text("默认关闭。只有点击“执行建议”才会发送着法；发送前仍会读取最新棋谱并重新校验合法性。")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
            } else {
                Text("当前游戏没有可执行的原生规则建议。灵核仅提供局面解释，不能代替专用游戏 Bot 操作。")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
            }

            HStack(spacing: 8) {
                Button {
                    model.agent.send("请分析当前对局。仅引用本机局面和已列出的合法候选；如果没有合法候选，请明确说无法推荐可执行动作，不能编造着法。")
                } label: {
                    Label("只读分析", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(VeilGameSecondaryButtonStyle())

                if nativeMoveSupported {
                    Button {
                        actionStatus = model.executeAgentSuggestedGameMove()
                    } label: {
                        Label("执行建议", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(VeilGamePrimaryButtonStyle())
                    .disabled(
                        !controls.allowSuggestedGameMoveExecution
                            || intelligence.currentSuggestedAction() == nil
                    )
                    .accessibilityIdentifier("agent-game-execute-suggestion")
                }
            }

            if nativeMoveSupported {
                Button {
                    actionStatus = model.refreshAgentGameRecommendation()
                } label: {
                    Label("按最新棋谱刷新合法建议", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(VeilGameSecondaryButtonStyle())
            }
        }
        .font(.caption.weight(.semibold))
    }

    private func infoChip(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundColor(VeilTheme.mutedGold)
            Text(value)
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundColor(VeilTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(VeilTheme.subtleFill)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
