import SwiftUI

struct AgentGameAssistantSheet: View {
    @ObservedObject var model: AppModel
    let conversation: ConversationSummary
    let session: MiniGameSessionSnapshot

    @ObservedObject private var intelligence: AgentGameContextBroker
    @Environment(\.dismiss) private var dismiss
    @State private var actionStatus: String?

    init(model: AppModel, conversation: ConversationSummary, session: MiniGameSessionSnapshot) {
        self.model = model
        self.conversation = conversation
        self.session = session
        _intelligence = ObservedObject(wrappedValue: model.gameIntelligence)
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
        .preferredColorScheme(.dark)
        .onAppear {
            model.updateAgentGameContext(session, conversation: conversation)
            model.agent.setComputeFocus(.gameDecision)
            model.agent.activate()
        }
        .onDisappear {
            model.agent.setComputeFocus(.gameDecision)
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
        HStack(spacing: 8) {
            Button {
                model.agent.send("请分析当前对局。只使用本机提供的局面和合法候选动作，说明你推荐哪一步以及理由；不要发明候选列表之外的着法。")
            } label: {
                Label("分析", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VeilGameSecondaryButtonStyle())

            Button {
                actionStatus = model.executeAgentSuggestedGameMove()
            } label: {
                Label("执行建议", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VeilGamePrimaryButtonStyle())
            .disabled(intelligence.currentSuggestedAction() == nil)
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
        .background(Color.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
