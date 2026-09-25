import Foundation

/// Zero-weight, deterministic conversational runtime for the Core edition.
/// It uses only local intents and app-generated context. It is not an LLM.
@MainActor
final class VeilTalkLiteRuntime: LocalTextModelRuntime {
    private(set) var state: AgentRuntimeState = .unloaded
    let manifest: LocalTextModelManifest? = LocalTextModelManifest(
        id: "veillink.veiltalk-lite.v4",
        displayName: "VeilTalk Lite",
        upstream: "VeilLink model-free local intent runtime",
        license: "Project internal runtime",
        quantization: "none",
        sha256: "embedded-source",
        byteCount: 0,
        contextLimit: 0,
        recommendedProfile: "legacyA10|balanced|high",
        minimumOS: "15.0"
    )

    private var cancellationEpoch = 0

    func prepare() async throws {
        guard state == .unloaded || state == .unavailable else { return }
        state = .loading
        try await Task.sleep(nanoseconds: 12_000_000)
        try Task.checkCancellation()
        state = .ready
    }

    func generate(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult {
        let input = request.userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw AgentRuntimeError.invalidRequest }
        if state == .unloaded { try await prepare() }
        guard state == .ready else { throw AgentRuntimeError.unavailable("VeilTalk Lite 当前不可用。") }

        state = .generating
        let epoch = cancellationEpoch
        let response = Self.reply(to: input, localContext: request.localContext)
        let chunks = AgentTokenStream.chunks(text: response, targetCharacters: 5)
        var rendered = ""
        var emitted = 0

        defer { if state == .generating { state = .ready } }
        for chunk in chunks {
            try Task.checkCancellation()
            guard epoch == cancellationEpoch else { throw AgentRuntimeError.cancelled }
            rendered += chunk
            emitted += 1
            onToken(chunk)
            try await Task.sleep(nanoseconds: 7_000_000)
        }
        state = .ready
        return AgentTextResult(
            text: rendered,
            emittedChunkCount: emitted,
            estimatedTokenCount: max(1, rendered.count / 2)
        )
    }

    func cancel() {
        cancellationEpoch &+= 1
        if state == .generating || state == .loading { state = .ready }
    }

    func trimMemory() {}

    func unload() {
        cancellationEpoch &+= 1
        state = .unloaded
    }

    nonisolated static func reply(to raw: String, localContext: AgentLocalContext?) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        if containsAny(lower, ["你好", "hello", "hi", "嗨", "早上好", "晚上好"]) {
            return "你好。我是 VeilTalk Lite，Core 版零模型本地助手。除了简单对话和状态摘要，我还能通过 Local Control Plane 调用 VeilLink 的受控本机功能。"
        }
        if containsAny(lower, ["你是谁", "什么模型", "什么ai", "什么 ai", "模型吗"]) {
            return "我是 VeilTalk Lite。这里没有内置大语言模型，也不会联网推理；Core 版用本地规则和上下文完成基础对话。"
        }
        if containsAny(lower, ["蓝牙", "ble", "连接", "附近设备"]) {
            guard let localContext else { return "当前没有可用的本机连接摘要。" }
            let b = localContext.bluetooth
            let health = b.weakestHealth.map { "，最低链路健康度 \($0)/100" } ?? ""
            return "BLE 当前\(b.running ? "已运行" : "未运行")，跟踪 \(b.trackedPeers) 台，已连接 \(b.connectedPeers) 台，恢复中 \(b.recoveringPeers) 台\(health)。"
        }
        if containsAny(lower, ["游戏", "对局", "局面", "轮到谁"]) {
            if let game = localContext?.game {
                return "当前是《\(game.gameTitle)》，第 \(game.turn) 回合，本方\(game.isLocalTurn ? "行动中" : "等待对方")。状态：\(game.status)。"
            }
            return "当前没有活动中的游戏上下文。"
        }
        if containsAny(lower, ["状态", "诊断", "a9", "数据库"]) {
            guard let localContext else { return "当前没有可用的本机状态摘要。" }
            return "本机摘要：A9 健康度 \(localContext.a9HealthScore)/100，模式 \(localContext.a9Mode)，数据库 \(localContext.databaseIntegrity)，BLE 已连接 \(localContext.bluetooth.connectedPeers) 台。"
        }
        if containsAny(lower, ["帮助", "help", "能做什么", "命令"]) {
            let tools = localContext?.availableTools ?? []
            let toolText = tools.isEmpty ? "当前没有公开的本地命令。" : "可用命令：" + tools.joined(separator: "、") + "。"
            return "我能做基础对话，也能通过 Control Plane V3 查看和调控本机 App；AutoTune 还能根据温控、A9 与 BLE 压力做受限的安全自调节。\(toolText)"
        }
        if containsAny(lower, ["谢谢", "谢了", "thanks", "thank you"]) {
            return "不用客气。需要我看本机连接、对局或运行状态时直接说。"
        }

        let clipped = String(text.prefix(54))
        if let context = localContext, context.bluetooth.connectedPeers > 0 {
            return "我收到「\(clipped)」。VeilTalk Lite 不是大模型，所以复杂开放式问答能力有限；当前本机有 \(context.bluetooth.connectedPeers) 个 BLE 连接，我更适合处理 VeilLink 状态、对局和简单聊天。"
        }
        return "我收到「\(clipped)」。VeilTalk Lite 是零模型本地运行时，适合简单聊天和 VeilLink 本机状态问答；复杂知识问答需要实验 AI 版。"
    }

    nonisolated private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}
