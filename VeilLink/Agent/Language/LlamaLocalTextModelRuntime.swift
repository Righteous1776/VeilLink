import Foundation

#if canImport(llama)
@MainActor
final class LlamaLocalTextModelRuntime: LocalTextModelRuntime {
    private(set) var state: AgentRuntimeState = .unloaded
    let manifest: LocalTextModelManifest? = LocalModelCatalog.primary.manifest

    private let profile: AgentCapabilityProfile
    private let configuration: LlamaRuntimeConfiguration
    private var engine: LlamaInferenceEngine?
    private var cancellationEpoch: UInt64 = 0
    private(set) var lastModelLoadMilliseconds: Int?
    private(set) var lastGenerationStats: LlamaGenerationStats?

    init(profile: AgentCapabilityProfile) {
        self.profile = profile
        configuration = .resolved(profile: profile)
    }

    func prepare() async throws {
        guard state == .unloaded || state == .unavailable else { return }
        state = .loading
        DiagnosticLogStore.shared.log(
            .info,
            .agent,
            event: "local_ai.model.verify.begin",
            metadata: [
                "model_id": LocalModelCatalog.primary.id,
                "model_revision": LocalModelCatalog.qwenModelRevision,
                "profile": profile.id,
                "llama_commit": LocalModelCatalog.llamaCPPCommit
            ]
        )

        do {
            let validation = try await LocalModelManager.validate(descriptor: LocalModelCatalog.primary)
            DiagnosticLogStore.shared.log(
                .info,
                .agent,
                event: "local_ai.model.verify.ok",
                metadata: [
                    "model_id": LocalModelCatalog.primary.id,
                    "bytes": String(validation.byteCount),
                    "sha256_prefix": String(validation.sha256.prefix(12))
                ]
            )

            let newEngine = LlamaInferenceEngine(configuration: configuration)
            let started = Date()
            try await newEngine.load(modelURL: validation.url)
            lastModelLoadMilliseconds = Int(Date().timeIntervalSince(started) * 1_000)
            engine = newEngine
            state = .ready
            DiagnosticLogStore.shared.log(
                .info,
                .agent,
                event: "local_ai.model.load.ok",
                metadata: [
                    "duration_ms": String(lastModelLoadMilliseconds ?? 0),
                    "context_budget": String(configuration.contextTokens),
                    "batch_budget": String(configuration.batchTokens),
                    "threads": String(configuration.threads),
                    "gpu_layers": String(configuration.gpuLayers)
                ]
            )
        } catch {
            engine = nil
            state = .unavailable
            DiagnosticLogStore.shared.log(
                .error,
                .agent,
                event: "local_ai.model.load.failed",
                message: error.localizedDescription,
                metadata: ["model_id": LocalModelCatalog.primary.id]
            )
            throw error
        }
    }

    func generate(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult {
        guard !request.userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentRuntimeError.invalidRequest
        }
        if state == .unloaded || state == .unavailable { try await prepare() }
        guard let engine, state == .ready else {
            throw AgentRuntimeError.unavailable("真实本地模型尚未就绪。")
        }

        cancellationEpoch &+= 1
        let epoch = cancellationEpoch
        state = .generating
        DiagnosticLogStore.shared.log(
            .info,
            .agent,
            event: "local_ai.generate.begin",
            metadata: [
                "session_id": request.sessionID,
                "history_count": String(request.messages.count),
                "max_new": String(request.maxNewTokens),
                "runtime": LocalModelCatalog.primary.id
            ]
        )

        defer {
            if state == .generating { state = .ready }
        }

        var historyLimit = min(request.messages.count, profile.recentMessageLimit)
        var lastOverflow: LlamaEngineError?
        while historyLimit >= 1 {
            try Task.checkCancellation()
            guard epoch == cancellationEpoch else { throw AgentRuntimeError.cancelled }
            let chatMessages = QwenPromptFormatter.messages(request: request, historyLimit: historyLimit)
            let prompt = QwenPromptFormatter.prompt(request: request, historyLimit: historyLimit)
            do {
                let stats = try await engine.generate(
                    prompt: prompt,
                    chatMessages: chatMessages,
                    maxNewTokens: request.maxNewTokens,
                    onPiece: onToken
                )
                guard epoch == cancellationEpoch else { throw AgentRuntimeError.cancelled }
                lastGenerationStats = stats
                state = .ready
                DiagnosticLogStore.shared.log(
                    .info,
                    .agent,
                    event: "local_ai.generate.ok",
                    metadata: [
                        "duration_ms": String(stats.totalMilliseconds),
                        "first_piece_ms": stats.firstVisibleTokenMilliseconds.map(String.init) ?? "none",
                        "prompt_count": String(stats.promptTokenCount),
                        "generated_count": String(stats.generatedTokenCount),
                        "pieces_per_second": String(format: "%.2f", stats.generatedTokensPerSecond),
                        "history_used": String(historyLimit),
                        "chat_template": stats.usedModelChatTemplate ? "gguf" : "fallback-chatml"
                    ]
                )
                return AgentTextResult(
                    text: stats.text,
                    emittedChunkCount: stats.emittedChunkCount,
                    estimatedTokenCount: stats.generatedTokenCount
                )
            } catch let error as LlamaEngineError {
                if case .contextOverflow = error {
                    lastOverflow = error
                    if historyLimit == 1 { break }
                    historyLimit = max(1, historyLimit / 2)
                    continue
                }
                throw error
            } catch is CancellationError {
                throw AgentRuntimeError.cancelled
            }
        }

        DiagnosticLogStore.shared.log(
            .warning,
            .agent,
            event: "local_ai.generate.context_overflow",
            metadata: ["history_count": String(request.messages.count)]
        )
        throw lastOverflow ?? AgentRuntimeError.unavailable("本地上下文预算不足。")
    }

    func cancel() {
        cancellationEpoch &+= 1
        if state == .generating || state == .loading { state = .ready }
        DiagnosticLogStore.shared.log(.info, .agent, event: "local_ai.generate.cancel")
    }

    func trimMemory() {
        guard let engine else { return }
        Task { await engine.trim() }
        DiagnosticLogStore.shared.log(.info, .agent, event: "local_ai.memory.trim")
    }

    func unload() {
        cancellationEpoch &+= 1
        let old = engine
        engine = nil
        lastGenerationStats = nil
        state = .unloaded
        Task { await old?.shutdown() }
        DiagnosticLogStore.shared.log(.info, .agent, event: "local_ai.model.unload")
    }
}
#endif
