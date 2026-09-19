import SwiftUI
import UIKit

struct AgentControlCenterView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var controls: AgentControlCenterSettings

    @State private var showsExperimentalCoreConfirmation = false
    @State private var showsResetConfirmation = false
    @State private var copied = false

    init(model: AppModel) {
        self.model = model
        controls = model.agentControls
    }

    var body: some View {
        VeilStableScrollView {
            VStack(spacing: 14) {
                overviewCard
                languageCard
                maleCNSCard
                permissionsCard
                resourceCard
                diagnosticsCard
                resetCard
            }
        }
        .background(VeilAmbientBackground())
        .navigationTitle("AI 控制中心")
        .navigationBarTitleDisplayMode(.inline)
        .alert("启用实验 Core？", isPresented: $showsExperimentalCoreConfirmation) {
            Button("取消", role: .cancel) {}
            Button("启用实验 Core") {
                model.setAgentGameDecisionMode(.experimentalCore)
            }
        } message: {
            Text("Core R7 当前只有小规模验证，deployment_eligible 仍为 false。开启后会强制加载 48k Core VFLY，并允许实验 ranker 参与 Top-3 重排；可能增加耗电、延迟或降低部分局面质量。")
        }
        .alert("恢复 AI 安全默认值？", isPresented: $showsResetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) { model.resetAgentControls() }
        } message: {
            Text("会恢复自动稳定模式、关闭自动执行建议着法，并重新启用本地显式聊天助手、视觉摘要和本地工具。不会删除模型、聊天或身份数据。")
        }
        .onAppear { model.refreshA9Health() }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VeilIdentityGlyph(seed: "veillink-agent-control-center", size: 48, active: model.agent.runtimeState == .ready || model.agent.runtimeState == .generating)
                VStack(alignment: .leading, spacing: 3) {
                    Text("LOCAL AI STACK")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundColor(VeilTheme.mutedGold)
                    Text("灵核 · 双脑控制")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                    Text("Qwen Runtime + MaleCNS/VFLY + A9")
                        .font(.caption)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.agent.runtimeState.displayName)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(runtimeColor)
                    Text("H\(model.a9Health.decision.healthScore)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                }
            }

            HStack(spacing: 8) {
                metric("LLM", model.agent.runtimeManifest?.displayName ?? LocalTextModelRuntimeFactory.backendName)
                metric("VFLY", model.maleCNS.state.displayName)
            }
            HStack(spacing: 8) {
                metric("GAME", controls.gameDecisionMode.title)
                metric("A9", model.computeGovernor.plan.mode.title)
            }
        }
        .veilCard(emphasized: true)
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("本地语言模型", icon: "text.bubble.fill")

            Toggle(isOn: Binding(
                get: { controls.autoLoadLanguageModel },
                set: { model.setAgentAutoLoadLanguageModel($0) }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("进入灵核时自动预热").fontWeight(.medium)
                    Text("关闭后不会在打开灵核页面时主动载入；仍可用下面按钮手动加载。")
                        .font(.caption).foregroundColor(VeilTheme.secondaryText)
                }
            }
            .tint(VeilTheme.gold)

            if let manifest = model.agent.runtimeManifest {
                VStack(alignment: .leading, spacing: 5) {
                    detailRow("模型", manifest.displayName)
                    detailRow("量化", manifest.quantization)
                    detailRow("上下文", "\(manifest.contextLimit) tokens")
                    detailRow("资源", ByteCountFormatter.string(fromByteCount: Int64(manifest.byteCount), countStyle: .file))
                    detailRow("最低系统", "iOS \(manifest.minimumOS)+")
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 9) {
                Button {
                    model.agent.activate()
                } label: {
                    Label("加载 / 预热", systemImage: "bolt.fill")
                }
                .buttonStyle(.bordered)
                .tint(VeilTheme.gold)
                .disabled(model.agent.runtimeState == .loading || model.agent.runtimeState == .generating)

                Button {
                    model.agent.unloadRuntime()
                } label: {
                    Label("卸载", systemImage: "power")
                }
                .buttonStyle(.bordered)
                .tint(VeilTheme.secondaryText)
                .disabled(model.agent.runtimeState == .unloaded)
            }

            Text("卸载只释放本机模型运行时和缓存，不会删除 GGUF、VFLY、聊天或训练资产。")
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .veilCard()
    }

    private var maleCNSCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("MaleCNS · 游戏决策", icon: "brain.head.profile")

            VStack(spacing: 7) {
                decisionModeButton(.automaticStable)
                decisionModeButton(.baselineOnly)
                decisionModeButton(.trainedLite)
                decisionModeButton(.experimentalCore)
            }

            Divider().background(Color.white.opacity(0.07))
            detailRow("当前图", model.maleCNS.state.displayName)
            detailRow("图选择", model.maleCNS.deploymentMode.title)
            detailRow("重排范围", "基础策略 Top-3")
            if let learned = model.maleCNS.lastLearnedReadout {
                detailRow("最近 readout", "\(learned.label) · \(Int((learned.confidence * 100).rounded()))%")
            }

            if controls.gameDecisionMode == .trainedLite {
                Text("Lite R7 已通过当前部署门：12k 神经元图 + residual candidate ranker。它只重排合法候选，不拥有规则裁决权。")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
            } else if controls.gameDecisionMode == .experimentalCore {
                Label("实验 Core 已手动开启。当前训练样本仍不足，不应把输出视为成熟策略。", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(VeilTheme.gold)
            }
        }
        .veilCard()
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("权限与上下文", icon: "lock.shield.fill")

            Toggle(isOn: Binding(
                get: { controls.conversationTextAccessEnabled },
                set: { model.setAgentConversationTextAccessEnabled($0) }
            )) {
                permissionLabel("当前对话正文", detail: "仅你主动打开“灵核助手”并点任务时，临时读取最近几条普通文本。")
            }
            .tint(VeilTheme.gold)

            Toggle(isOn: Binding(
                get: { controls.visualContextEnabled },
                set: { model.setAgentVisualContextEnabled($0) }
            )) {
                permissionLabel("视觉摘要进入 Agent", detail: "摄像头仍只在本机处理；关闭后低频 Vision 摘要也不会进入语言请求。")
            }
            .tint(VeilTheme.gold)

            Toggle(isOn: Binding(
                get: { controls.localToolMutationsEnabled },
                set: { model.setAgentLocalToolMutationsEnabled($0) }
            )) {
                permissionLabel("允许本地工具动作", detail: "控制 BLE 刷新与数据库完整性自检；状态查询始终是只读。")
            }
            .tint(VeilTheme.gold)

            Toggle(isOn: Binding(
                get: { controls.allowSuggestedGameMoveExecution },
                set: { model.setAgentSuggestedGameMoveExecutionEnabled($0) }
            )) {
                permissionLabel("允许执行建议着法", detail: "默认关闭。开启后仍只有明确 /game move 或按钮操作才能发送，且动作必须来自规则引擎合法候选。")
            }
            .tint(VeilTheme.gold)

            Text("这些权限全部保存在本机 UserDefaults；不会上传到模型服务或服务器。")
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .veilCard()
    }

    private var resourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("A9 与资源", icon: "gauge.with.dots.needle.67percent")
            HStack(spacing: 8) {
                metric("模式", model.computeGovernor.plan.mode.title)
                metric("焦点", model.computeGovernor.plan.focus.title)
            }
            HStack(spacing: 8) {
                metric("FLY", model.computeGovernor.plan.maleCNS.tier.rawValue.uppercased())
                metric("LLM", "\(model.computeGovernor.plan.language.maxNewTokens)t")
            }

            Text("临时计算焦点")
                .font(.caption.weight(.semibold))
                .foregroundColor(VeilTheme.secondaryText)
            HStack(spacing: 8) {
                focusButton("待机", .idle)
                focusButton("对话", .languageChat)
                focusButton("游戏", .gameDecision)
            }

            Button {
                model.trimAgentMemory()
            } label: {
                Label("释放 AI 临时内存", systemImage: "memorychip")
            }
            .buttonStyle(.bordered)
            .tint(VeilTheme.gold)

            Text("A9 仍会覆盖不安全的算力请求，并优先保留 BLE/传输预算；这里不会绕过温控或 iOS 后台限制。")
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .veilCard()
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("诊断", icon: "stethoscope")

            Button {
                model.runA9StorageCheck()
                model.haptics.selection()
            } label: {
                HStack {
                    Label("数据库完整性自检", systemImage: "externaldrive.badge.checkmark")
                    Spacer()
                    Text(model.a9Health.databaseIntegrity.title)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                }
            }
            .buttonStyle(VeilPressStyle())

            Button {
                model.bluetooth.refreshLinks()
                model.refreshA9Health()
                model.haptics.selection()
            } label: {
                HStack {
                    Label("刷新 BLE 链路", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    Text("\(model.bluetooth.connectedPeerCount) LINK")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                }
            }
            .buttonStyle(VeilPressStyle())

            Button {
                UIPasteboard.general.string = model.agentDiagnosticsReport()
                copied = true
                model.haptics.resolved()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
            } label: {
                HStack {
                    Label(copied ? "已复制 AI 诊断" : "复制 AI 诊断", systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    Spacer()
                    Text("NO CHAT TEXT")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.mutedGold)
                }
            }
            .buttonStyle(VeilPressStyle())
        }
        .veilCard()
    }

    private var resetCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("实验控制不会修改模型文件本身", systemImage: "checkmark.shield")
                .font(.caption.weight(.semibold))
                .foregroundColor(VeilTheme.secondaryText)
            Text("“部署”在这里指运行时是否允许加载并参与决策，不会重新训练或覆盖 VFLY/Qwen 资产。")
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
            Button(role: .destructive) { showsResetConfirmation = true } label: {
                Label("恢复 AI 安全默认值", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
        }
        .veilCard()
    }

    private func decisionModeButton(_ mode: AgentGameDecisionMode) -> some View {
        let selected = controls.gameDecisionMode == mode
        let blocked = mode == .experimentalCore && model.agent.capabilityProfile.tier == .legacyA10
        return Button {
            guard !blocked else { return }
            if mode == .experimentalCore {
                showsExperimentalCoreConfirmation = true
            } else {
                model.setAgentGameDecisionMode(mode)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(mode.title).font(.subheadline.weight(.semibold))
                        if mode.isExperimental {
                            Text("EXPERIMENTAL")
                                .font(.system(size: 7.5, weight: .heavy, design: .monospaced))
                                .foregroundColor(VeilTheme.gold)
                        }
                    }
                    Text(blocked ? "A10 / iPhone 7 不允许加载 Core 图。" : mode.subtitle)
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }
            .padding(10)
            .background(selected ? VeilTheme.gold.opacity(0.08) : Color.white.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(selected ? VeilTheme.gold.opacity(0.28) : VeilTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(blocked)
        .opacity(blocked ? 0.5 : 1)
    }

    private func focusButton(_ title: String, _ focus: AgentComputeFocus) -> some View {
        Button {
            model.agent.setComputeFocus(focus)
            model.haptics.selection()
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(model.computeGovernor.plan.focus == focus ? VeilTheme.gold : VeilTheme.secondaryText)
    }

    private func permissionLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).fontWeight(.medium)
            Text(detail).font(.caption).foregroundColor(VeilTheme.secondaryText)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundColor(VeilTheme.goldBright)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundColor(VeilTheme.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundColor(VeilTheme.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.caption)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundColor(VeilTheme.tertiaryText)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(VeilTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var runtimeColor: Color {
        switch model.agent.runtimeState {
        case .ready: return VeilTheme.success
        case .generating: return VeilTheme.goldBright
        case .loading, .cooling: return VeilTheme.gold
        case .unavailable: return VeilTheme.danger
        case .unloaded: return VeilTheme.secondaryText
        }
    }
}
