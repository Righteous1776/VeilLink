import Foundation

#if canImport(llama)
/// Explicitly opt-in; never install this runtime through the default
/// AgentCoordinator factory or reuse its toolExecutor.
@MainActor
final class Vertex35MChatRuntime: LocalTextModelRuntime {
    private(set) var state: AgentRuntimeState = .unloaded
    let manifest: LocalTextModelManifest? = LocalTextModelManifest(
        id: "vertexresearch.vertex-0.6-35m-instruct-q4_k_m",
        displayName: "Vertex 35M — experimental offline chat",
        upstream: "VertexResearch/Vertex-0.6-35M-Instruct-GGUF",
        license: "Apache-2.0",
        quantization: "Q4_K_M",
        sha256: Vertex35MModelIntegrityGate.expectedSHA256,
        byteCount: Int(Vertex35MModelIntegrityGate.expectedBytes),
        contextLimit: 1_024,
        recommendedProfile: "experimental text-only",
        minimumOS: "15.0"
    )

    private let modelURL: URL
    private let gate = LlamaCancellationGate()
    private var engine: LlamaInferenceEngine?
    private var generationEpoch: UInt64 = 0
    private var shutdownTask: Task<Void, Never>?
    private var languageBudget: AgentLanguageComputeBudget?
    private var governanceMode: A9ComputeMode = .balanced

    /// Read-only A9/A10-derived compute caps. Never receives host command authority.
    var onProgress: (@MainActor @Sendable (LlamaTokenProgress) -> Void)?
    private(set) var lastGenerationStats: LlamaGenerationStats?
    private(set) var lastModelLoadMilliseconds: Int?

    private var isLegacyMemory: Bool {
        ProcessInfo.processInfo.physicalMemory <= 2_800_000_000
            || AgentCapabilityProfile.current.tier == .legacyA10
    }

    func applyHostBudget(_ plan: VeilA9ComputePlan) {
        languageBudget = plan.language
        governanceMode = plan.mode
        if plan.mode == .emergency {
            unload()
        }
    }

    /// Called only by the independent chat view on memory warnings/background.
    func releaseForMemoryPressure() {
        unload()
    }

    init(importedModelURL: URL) {
        modelURL = importedModelURL
    }

    func prepare() async throws {
        guard state == .unloaded || state == .unavailable else { return }
        if let shutdownTask {
            await shutdownTask.value
            self.shutdownTask = nil
        }
        guard ProcessInfo.processInfo.physicalMemory >= 1_500_000_000 else {
            throw AgentRuntimeError.unavailable("设备可用物理内存等级过低，已阻止模型载入。")
        }
        guard governanceMode != .emergency else {
            throw AgentRuntimeError.unavailable("A9/A10 当前处于紧急保护预算，已暂停微型模型。")
        }
        switch ProcessInfo.processInfo.thermalState {
        case .serious, .critical:
            throw AgentRuntimeError.unavailable("设备温度较高，已暂停本地模型以保护通信和界面。")
        default:
            break
        }
        state = .loading
        do {
            try await Vertex35MModelIntegrityGate.validate(url: modelURL)
            // CPU-first, conservative settings until device benchmarks exist.
            let config = LlamaRuntimeConfiguration(
                contextTokens: isLegacyMemory ? 512 : 1_024,
                batchTokens: isLegacyMemory ? 32 : 64,
                threads: isLegacyMemory ? 1 : min(2, ProcessInfo.processInfo.activeProcessorCount),
                gpuLayers: 0,
                temperature: 0.55,
                topK: 20,
                topP: 0.85,
                minP: 0.05
            )
            let next = LlamaInferenceEngine(configuration: config, cancellationGate: gate)
            let loadStarted = Date()
            try await next.load(modelURL: modelURL)
            lastModelLoadMilliseconds = max(0, Int(Date().timeIntervalSince(loadStarted) * 1_000))
            engine = next
            state = .ready
        } catch {
            state = .unavailable
            throw error
        }
    }

    func generate(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult {
        // Fail closed if any privileged context is accidentally forwarded.
        guard request.localContext == nil,
              request.visualContext == nil,
              !request.userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.userText.count <= 512 else {
            throw AgentRuntimeError.invalidRequest
        }
        guard governanceMode != .emergency else {
            throw AgentRuntimeError.unavailable("A9/A10 已暂停语言计算。")
        }
        guard ProcessInfo.processInfo.thermalState != .critical else {
            throw AgentRuntimeError.unavailable("当前温控限制，已停止推理。")
        }
        if state == .unloaded || state == .unavailable { try await prepare() }
        guard state == .ready, let engine else {
            throw AgentRuntimeError.unavailable("Vertex 35M runtime unavailable.")
        }
        state = .generating
        lastGenerationStats = nil
        generationEpoch &+= 1
        let epoch = generationEpoch
        defer { if state == .generating { state = .ready } }

        var chat = [
            QwenChatMessage(
                role: "system",
                content: "Offline text-only chat. No tools or controls. Be brief and truthful. Reply in the user's language. 中文问题用简体中文回答；不知道就明确说不知道。"
            )
        ]
        for message in request.messages.suffix(isLegacyMemory ? 2 : 4) {
            chat.append(QwenChatMessage(
                role: message.role == .user ? "user" : "assistant",
                content: Self.sanitize(message.text)
            ))
        }
        if chat.last?.role != "user" {
            chat.append(QwenChatMessage(role: "user", content: Self.sanitize(request.userText)))
        }
        // Fallback must also use a non-privileged prompt; GGUF ChatML is preferred.
        let fallback = chat.map { m in
            "<|im_start|>\(m.role)\n\(m.content)<|im_end|>\n"
        }.joined() + "<|im_start|>assistant\n"
        let maxTokens = max(1, min(
            96,
            request.maxNewTokens,
            languageBudget?.maxNewTokens ?? 64,
            isLegacyMemory ? 48 : 96
        ))
        let stats = try await engine.generate(
            prompt: fallback,
            chatMessages: chat,
            maxNewTokens: maxTokens,
            onProgress: { [weak self] progress in
                guard let self, self.generationEpoch == epoch else { return }
                self.onProgress?(progress)
            }
        ) { [weak self] text in
            guard let self, self.generationEpoch == epoch else { return }
            onToken(text)
        }
        guard epoch == generationEpoch else { throw AgentRuntimeError.cancelled }
        lastGenerationStats = stats
        state = .ready
        return AgentTextResult(
            text: stats.text,
            emittedChunkCount: stats.emittedChunkCount,
            estimatedTokenCount: stats.generatedTokenCount
        )
    }

    func cancel() {
        generationEpoch &+= 1
        gate.cancel()
        if state == .generating { state = .ready }
    }

    func trimMemory() {
        guard let engine else { return }
        Task { await engine.trim() }
    }

    func unload() {
        cancel()
        let previous = engine
        engine = nil
        state = .unloaded
        lastGenerationStats = nil
        if let previous {
            shutdownTask = Task { await previous.shutdown() }
        }
    }

    private static func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "<|im_start|>", with: "[literal-im-start]")
            .replacingOccurrences(of: "<|im_end|>", with: "[literal-im-end]")
            .replacingOccurrences(of: "\u{0000}", with: "")
    }
}
#endif
