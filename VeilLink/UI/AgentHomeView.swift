import SwiftUI

struct AgentHomeView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controls: AgentControlCenterSettings
    @State private var showDiagnostics = false

    init(model: AppModel) {
        self.model = model
        controls = model.agentControls
    }

    var body: some View {
        VStack(spacing: 10) {
            AgentStatusView(coordinator: model.agent, maleCNS: model.maleCNS)
            AgentControlSummaryView(model: model, controls: controls)
            AgentQuickToolsView(model: model)
            AgentChatView(coordinator: model.agent)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(VeilAmbientBackground())
        .navigationTitle("灵核")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink(destination: AgentControlCenterView(model: model)) {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("打开 AI 控制中心")

                NavigationLink(destination: AgentVideoChatView(coordinator: model.agent)) {
                    Image(systemName: "video")
                }
                .accessibilityLabel("进入本地视频对话")

                Button {
                    model.agent.newSession()
                } label: {
                    Image(systemName: "plus.bubble")
                }
                .accessibilityLabel("新建本地会话")

                Menu {
                    Button("运行诊断") { showDiagnostics = true }
                    Button("刷新蓝牙链路") { model.agent.send("/ble refresh") }
                        .disabled(!controls.localToolMutationsEnabled)
                    Button("检查数据库完整性") { model.agent.send("/db check") }
                        .disabled(!controls.localToolMutationsEnabled)
                    Button("查看 A9 状态") { model.agent.send("/a9 status") }
                    Button("查看灵核运行状态") { model.agent.send("/agent status") }
                    if model.agent.isGenerating {
                        Button("停止生成", role: .destructive) { model.agent.stopGeneration() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("灵核更多选项")
            }
        }
        .sheet(isPresented: $showDiagnostics) {
            AgentDiagnosticsView(coordinator: model.agent)
        }
        .onAppear {
            model.agent.setComputeFocus(.languageChat)
            model.maleCNS.prepareFromBundle()
            if controls.autoLoadLanguageModel { model.agent.activate() }
        }
        .onDisappear { model.agent.setComputeFocus(.idle) }
    }
}

private struct AgentControlSummaryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controls: AgentControlCenterSettings

    var body: some View {
        NavigationLink(destination: AgentControlCenterView(model: model)) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(VeilTheme.gold.opacity(0.09))
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(VeilTheme.gold)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text("AI CONTROL")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundColor(VeilTheme.mutedGold)
                        if controls.gameDecisionMode.isExperimental {
                            Text("EXPERIMENTAL")
                                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                                .foregroundColor(VeilTheme.gold)
                        }
                    }
                    Text("\(controls.gameDecisionMode.title) · \(controls.autoLoadLanguageModel ? "LLM 自动" : "LLM 手动")")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(VeilTheme.text)
                    Text("VFLY \(model.maleCNS.state.displayName) · 工具\(controls.localToolMutationsEnabled ? "允许" : "只读")")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(VeilTheme.tertiaryText)
            }
            .padding(10)
            .background(VeilTheme.panel.opacity(0.72))
            .clipShape(VeilPanelShape(cut: 10, radius: 7))
            .overlay(VeilPanelShape(cut: 10, radius: 7).stroke(VeilTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct AgentQuickToolsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controls: AgentControlCenterSettings

    init(model: AppModel) {
        self.model = model
        controls = model.agentControls
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                quickButton("链路", icon: "antenna.radiowaves.left.and.right") {
                    model.agent.send("请根据当前本机上下文概括蓝牙链路状态、积压和健康度。")
                }
                quickButton("数据库", icon: "externaldrive.badge.checkmark") {
                    model.agent.send("/db check")
                }
                .opacity(controls.localToolMutationsEnabled ? 1 : 0.45)
                .disabled(!controls.localToolMutationsEnabled)
                quickButton("A9", icon: "gauge.with.dots.needle.50percent") {
                    model.agent.send("/a9 status")
                }
                quickButton("对局", icon: "gamecontroller") {
                    model.agent.send("请分析当前对局。只基于本机提供的合法候选动作给建议；如果没有当前对局就直接说明。")
                }
                .opacity(model.gameIntelligence.hasCurrentGame ? 1 : 0.55)
            }
            .padding(.horizontal, 1)
        }
        .frame(height: 30)
    }

    private func quickButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(VeilTheme.secondaryText)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Color.white.opacity(0.035))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(VeilTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct AgentDiagnosticsView: View {
    @ObservedObject var coordinator: AgentCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("只包含本地运行时状态、工具执行计数与性能计数；不包含聊天正文、附件、密钥、配对六码或数据库路径。")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                    Text(coordinator.diagnosticsReport())
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(VeilTheme.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
            }
            .background(VeilAmbientBackground())
            .navigationTitle("灵核诊断")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
