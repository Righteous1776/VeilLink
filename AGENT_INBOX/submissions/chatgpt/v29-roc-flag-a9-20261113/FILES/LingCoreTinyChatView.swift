import SwiftUI
import UIKit

#if VERTEX_CHAT_ONLY && canImport(llama)
/// Independent, text-only sandbox. No AppModel, tool router or BLE/DB references.
@MainActor
private final class VertexTinyChatState: ObservableObject {
    @Published var messages: [AgentMessage] = []
    @Published var partial = ""
    @Published var errorText: String?
    @Published var isGenerating = false
    @Published var tokenProgress: LlamaTokenProgress?
    @Published var loadMilliseconds: Int?
    @Published var computeBudgetLabel = "等待 A9/A10 计算预算"
    @Published var protectionMessage: String?
    @Published var chineseQualityNotice: String?

    private var runtime: Vertex35MChatRuntime?
    private var currentPlan: VeilA9ComputePlan?

    func updateHostBudget(_ plan: VeilA9ComputePlan) {
        currentPlan = plan
        computeBudgetLabel = "\(plan.mode.title) · 生成上限 \(plan.language.maxNewTokens) tokens"
        runtime?.applyHostBudget(plan)
        if plan.mode == .emergency {
            stop()
            protectionMessage = "当前 A9/A10 紧急预算：已暂停微型模型，优先保留设备与通信资源。"
        } else if protectionMessage?.contains("紧急预算") == true {
            protectionMessage = nil
        }
    }

    func suspendForDevicePressure(_ reason: String) {
        stop()
        runtime?.releaseForMemoryPressure()
        boundary = nil
        runtime = nil
        protectionMessage = reason
    }

    private var boundary: LingCoreChatOnlyBoundary?
    private var task: Task<Void, Never>?
    private var activeID: UUID?

    func send(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 512, !isGenerating else { return }
        let id = UUID()
        activeID = id
        messages.append(AgentMessage(role: .user, text: text))
        isGenerating = true
        partial = ""
        errorText = nil
        chineseQualityNotice = nil
        tokenProgress = nil
        loadMilliseconds = nil

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let endpoint = try self.endpoint()
                let answer = try await endpoint.reply(to: text) { [weak self] token in
                    guard let self, self.activeID == id else { return }
                    self.partial += token
                }
                guard self.activeID == id else { return }
                self.loadMilliseconds = self.runtime?.lastModelLoadMilliseconds
                if Vertex35MChineseQualityGate.needsLanguageWarning(userText: text, modelOutput: answer) {
                    self.chineseQualityNotice = "此 35M 模型没有按中文要求回答。保留原始回复，不提供不可靠的自动翻译。"
                }
                self.messages.append(AgentMessage(role: .assistant, text: answer))
            } catch is CancellationError {
                // Cancellation produces no synthetic assistant reply.
            } catch {
                guard self.activeID == id else { return }
                self.errorText = error.localizedDescription
            }
            guard self.activeID == id else { return }
            self.isGenerating = false
            self.partial = ""
            self.task = nil
            self.activeID = nil
        }
    }

    func stop() {
        activeID = nil
        task?.cancel()
        boundary?.cancel()
        task = nil
        isGenerating = false
        partial = ""
    }

    func clear() {
        stop()
        boundary?.clear()
        messages.removeAll()
        errorText = nil
        chineseQualityNotice = nil
    }

    private func endpoint() throws -> LingCoreChatOnlyBoundary {
        if let boundary { return boundary }
        let filename = "Vertex-0.6-35M-Instruct-Q4_K_M"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "gguf", subdirectory: "LocalAI")
            ?? Bundle.main.url(forResource: filename, withExtension: "gguf") else {
            throw AgentRuntimeError.unavailable("实验模型未包含在当前应用中，请使用 Vertex 原生实验构建。")
        }
        let engine = Vertex35MChatRuntime(importedModelURL: url)
        if let currentPlan { engine.applyHostBudget(currentPlan) }
        engine.onProgress = { [weak self] progress in
            guard let self, self.activeID != nil else { return }
            self.tokenProgress = progress
        }
        runtime = engine
        let item = LingCoreChatOnlyBoundary(runtime: engine)
        boundary = item
        return item
    }
}

struct LingCoreTinyChatView: View {
    @ObservedObject var computeGovernor: VeilA9ComputeGovernor
    @StateObject private var chat = VertexTinyChatState()
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                // Reuse the latest VeilLink Grok bot R5 renderer, not a second
                // independently decoded video player. In legacy memory tiers
                // the visual is smaller and remains completely touch-transparent.
                if ProcessInfo.processInfo.physicalMemory <= 2_800_000_000
                    || AgentCapabilityProfile.current.tier == .legacyA10 {
                    VeilOpponentAvatarView(
                        mood: .idle,
                        size: 54,
                        staticOnly: true
                    )
                    .accessibilityLabel("Vertex 35M 的 Grok bot 静态轻量形象")
                    .accessibilityIdentifier("vertex35m.chat.grok_avatar_static")
                } else {
                    VeilOpponentAvatarView(
                        mood: chat.isGenerating ? .thinking : .idle,
                        size: 72
                    )
                    .accessibilityLabel("Vertex 35M 的 Grok bot 动态形象")
                    .accessibilityIdentifier("vertex35m.chat.grok_avatar")
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Grok bot")
                        .font(.headline)
                        .foregroundColor(VeilTheme.text)
                    Text("Vertex 35M · 离线聊天")
                        .font(.subheadline)
                        .foregroundColor(VeilTheme.secondaryText)
                    HStack(spacing: 5) {
                        Image(systemName: "lock.shield")
                        Text(chat.isGenerating ? "本机生成中 · 无控制权限" : "独立文本通道 · 零控制权限")
                    }
                    .font(.caption2)
                    .foregroundColor(VeilTheme.mutedGold)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(VeilTheme.panel.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("vertex35m.chat.identity_header")

            if ProcessInfo.processInfo.physicalMemory <= 2_800_000_000 {
                Text("低内存保护：使用 Grok bot 静态绘制形象；停用视频解码和持续动画，优先保留聊天与通信资源。")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if Bundle.main.url(forResource: "GrokBotFull", withExtension: "mp4") == nil {
                Text("形象资源：当前使用 Grok bot 原生动态绘制版；完整版视频尚未打包。")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            tokenDashboard

            if let protectionMessage = chat.protectionMessage {
                Text(protectionMessage)
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let message = chat.chineseQualityNotice {
                Label(message, systemImage: "character.bubble")
                    .font(.caption)
                    .foregroundColor(VeilTheme.gold)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(chat.messages) { message in
                            HStack {
                                if message.role == .user { Spacer(minLength: 40) }
                                VeilROCFlagText.render(message.text.isEmpty ? "…" : message.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(message.role == .user ? .black : VeilTheme.text)
                                    .padding(12)
                                    .background(message.role == .user ? VeilTheme.goldBright : VeilTheme.elevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))
                                if message.role == .assistant { Spacer(minLength: 40) }
                            }
                            .id(message.id)
                        }
                        if chat.isGenerating {
                            Text(chat.partial.isEmpty ? "正在本机生成…" : chat.partial)
                                .font(.system(size: 14))
                                .foregroundColor(VeilTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: chat.messages.count) { _ in
                    if let id = chat.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }

            if let error = chat.errorText {
                Text(error).font(.caption).foregroundColor(VeilTheme.danger)
            }

            HStack(spacing: 8) {
                TextField("输入文本，不超过 512 字", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .disabled(chat.isGenerating)
                if chat.isGenerating {
                    Button("停止") { chat.stop() }.buttonStyle(.bordered)
                } else {
                    Button("发送", action: send)
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.count > 512)
                }
            }
            Text("V29 实验功能 · 中文能力尚未通过验证。模型可能答错、重复或无法理解中文；其输出永远不会作为设备或游戏命令。")
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
        }
        .padding(12)
        .background(VeilAmbientBackground())
        .navigationTitle("微型离线聊天")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("清空") { chat.clear() }.disabled(chat.messages.isEmpty)
            }
        }
        .onAppear { chat.updateHostBudget(computeGovernor.plan) }
        .onReceive(computeGovernor.$plan) { plan in
            chat.updateHostBudget(plan)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
            chat.suspendForDevicePressure("系统报告内存压力，微型模型已卸载；输入框仍可正常使用。")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            chat.suspendForDevicePressure("进入后台已卸载微型模型；返回前台后可按需重新载入。")
        }
        .onDisappear {
            chat.suspendForDevicePressure("退出微型聊天已释放模型内存。")
        }
    }

    private var tokenDashboard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("TOKEN MONITOR", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Spacer()
                Text(chat.computeBudgetLabel)
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundColor(VeilTheme.secondaryText)

            HStack(spacing: 12) {
                tokenMetric("提示", chat.tokenProgress.map { String($0.promptTokens) } ?? "—")
                tokenMetric("生成", chat.tokenProgress.map { String($0.generatedTokens) } ?? "—")
                tokenMetric("合计", chat.tokenProgress.map { String($0.promptTokens + $0.generatedTokens) } ?? "—")
                tokenMetric("速度", chat.tokenProgress.map { String(format: "%.1f t/s", $0.tokensPerSecond) } ?? "—")
            }
            if let ms = chat.loadMilliseconds {
                Text("上次模型载入：\(ms) ms · 所有 Token 均为本机采样真实值")
                    .font(.system(size: 10))
                    .foregroundColor(VeilTheme.secondaryText)
            }
        }
        .padding(10)
        .background(VeilTheme.panel.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tokenMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 9)).foregroundColor(VeilTheme.secondaryText)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(VeilTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func send() {
        let input = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.count <= 512, !chat.isGenerating else { return }
        draft = ""
        chat.send(input)
    }
}
#endif
