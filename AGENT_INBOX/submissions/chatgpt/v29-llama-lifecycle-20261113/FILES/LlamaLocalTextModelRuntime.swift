import Foundation

#if canImport(llama)
@MainActor
final class LlamaLocalTextModelRuntime: LocalTextModelRuntime {
    private(set) var state: AgentRuntimeState = .unloaded
    let manifest: LocalTextModelManifest? = LocalModelCatalog.primary.manifest

    private let profile: AgentCapabilityProfile
    private let configuration: LlamaRuntimeConfiguration
    private var engine: LlamaInferenceEngine?
    private let cancellationGate = LlamaCancellationGate()
    private var cancellationEpoch: UInt64 = 0
    private var shutdownTask: Task<Void, Never>?
    // Multiple unload calls may overlap on MainActor while native shutdown awaits.
    // Retain and chain every older task, even if the current engine is nil.
    private var shutdownGeneration: UInt64 = 0
    private var preparationInFlight = false
    private(set) var lastModelLoadMilliseconds: Int?
    private(set) var lastGenerationStats: LlamaGenerationStats?

    init(profile: AgentCapabilityProfile) {
        self.profile = profile
        configuration = .resolved(profile: profile)
    }

    func prepare() async throws {
        guard state == .unloaded || state == .unavailable else { return }
        // Do not start a second backend_init while an abandoned load is still
        // unwinding; this is independent of Swift MainActor reentrancy.
        guard !preparationInFlight else {
            throw AgentRuntimeError.unavailable("本地模型仍在完成上一次初始化。")
        }
        preparationInFlight = true
        defer { preparationInFlight = false }
        let preparationEpoch = cancellationEpoch
        if let pendingShutdown = shutdownTask {
            let observedGeneration = shutdownGeneration
            await pendingShutdown.value
            // A second unload may have installed another, still running task.
            // Never erase that newer barrier when this earlier await resumes.
            if observedGeneration == shutdownGeneration {
                shutdownTask = nil
            }
        }
        guard preparationEpoch == cancellationEpoch,
              state == .unloaded || state == .unavailable else {
            throw AgentRuntimeError.cancelled
        }
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
            guard preparationEpoch == cancellationEpoch, state == .loading else {
                throw AgentRuntimeError.cancelled
            }
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

            let newEngine = LlamaInferenceEngine(
                configuration: configuration,
                cancellationGate: cancellationGate
            )
            let started = Date()
            try await newEngine.load(modelURL: validation.url)
            guard preparationEpoch == cancellationEpoch, state == .loading else {
                // Cancel/unload may occur while llama_model_load_from_file blocks.
                // Free this newly created engine instead of resurrecting it.
                await newEngine.shutdown()
                throw AgentRuntimeError.cancelled
            }
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
            // An in-flight load cancelled by the owner must not overwrite a
            // newer .unloaded state with .unavailable after it resumes.
            guard preparationEpoch == cancellationEpoch, state == .loading else {
                throw AgentRuntimeError.cancelled
            }
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
        cancellationGate.cancel()
        // A cancelled native decode is STILL in-flight until its actor
        // method unwinds. Marking .ready early allowed overlapping calls.
        // During a load, invalidate the readiness state; prepare() checks epoch.
        if state == .loading { state = .unloaded }
        DiagnosticLogStore.shared.log(.info, .agent, event: "local_ai.generate.cancel")
    }

    func trimMemory() {
        guard let engine else { return }
        Task { await engine.trim() }
        DiagnosticLogStore.shared.log(.info, .agent, event: "local_ai.memory.trim")
    }

    func unload() {
        cancellationEpoch &+= 1
        cancellationGate.cancel()
        let old = engine
        engine = nil
        lastGenerationStats = nil
        state = .unloaded
        // Do NOT cancel or overwrite an unfinished native destructor. A
        // cancelled Task awaiting a continuation may still be running, and
        // starting a new llama_backend_init before it finishes risks freeing
        // process-global native state out from under the new model.
        let precedingShutdown = shutdownTask
        shutdownGeneration &+= 1
        shutdownTask = Task {
            if let precedingShutdown { await precedingShutdown.value }
            await old?.shutdown()
        }
        DiagnosticLogStore.shared.log(.info, .agent, event: "local_ai.model.unload")
    }
}
#endif
