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

    init(importedModelURL: URL) {
        modelURL = importedModelURL
    }

    func prepare() async throws {
        guard state == .unloaded || state == .unavailable else { return }
        state = .loading
        do {
            try await Vertex35MModelIntegrityGate.validate(url: modelURL)
            // CPU-first, conservative settings until device benchmarks exist.
            let config = LlamaRuntimeConfiguration(
                contextTokens: 1_024,
                batchTokens: 64,
                threads: 2,
                gpuLayers: 0,
                temperature: 0.55,
                topK: 20,
                topP: 0.85,
                minP: 0.05
            )
            let next = LlamaInferenceEngine(configuration: config, cancellationGate: gate)
            try await next.load(modelURL: modelURL)
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
        guard request.localContext == nil, request.visualContext == nil else {
            throw AgentRuntimeError.invalidRequest
        }
        if state == .unloaded || state == .unavailable { try await prepare() }
        guard state == .ready, let engine else {
            throw AgentRuntimeError.unavailable("Vertex 35M runtime unavailable.")
        }
        state = .generating
        generationEpoch &+= 1
        let epoch = generationEpoch
        defer { if state == .generating { state = .ready } }

        var chat = [
            QwenChatMessage(
                role: "system",
                content: "You are a tiny local text-only chat model. Respond briefly. You have no tools, app controls, external data or decision authority."
            )
        ]
        for message in request.messages.suffix(6) {
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
        let stats = try await engine.generate(
            prompt: fallback,
            chatMessages: chat,
            maxNewTokens: min(96, max(1, request.maxNewTokens))
        ) { [weak self] text in
            guard let self, self.generationEpoch == epoch else { return }
            onToken(text)
        }
        guard epoch == generationEpoch else { throw AgentRuntimeError.cancelled }
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
        Task { await previous?.shutdown() }
    }

    private static func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "<|im_start|>", with: "[literal-im-start]")
            .replacingOccurrences(of: "<|im_end|>", with: "[literal-im-end]")
            .replacingOccurrences(of: "\u{0000}", with: "")
    }
}
#endif
