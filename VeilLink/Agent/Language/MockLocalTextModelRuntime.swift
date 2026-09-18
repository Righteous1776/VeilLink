import Foundation

/// Phase-1 deterministic local runtime. It exists to prove the UI/runtime/lifecycle contract only.
/// It is intentionally not presented as an LLM and performs no network access.
@MainActor
final class MockLocalTextModelRuntime: LocalTextModelRuntime {
    private(set) var state: AgentRuntimeState = .unloaded
    let manifest: LocalTextModelManifest? = LocalTextModelManifest(
        id: "veillink.foundation.mock.v1",
        displayName: "Foundation Mock",
        upstream: "VeilLink internal deterministic fixture",
        license: "Project internal test runtime",
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
        try await Task.sleep(nanoseconds: 45_000_000)
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
        guard state == .ready else {
            throw AgentRuntimeError.unavailable("本地基础运行时当前不可用。")
        }

        state = .generating
        let epoch = cancellationEpoch
        let response = Self.foundationResponse(to: input, visualContext: request.visualContext)
        let chunks = AgentTokenStream.chunks(text: response, targetCharacters: 4)
        var rendered = ""
        var emitted = 0

        defer {
            if state == .generating { state = .ready }
        }

        for chunk in chunks {
            try Task.checkCancellation()
            guard epoch == cancellationEpoch else { throw AgentRuntimeError.cancelled }
            onToken(chunk)
            rendered += chunk
            emitted += 1
            try await Task.sleep(nanoseconds: 18_000_000)
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

    func trimMemory() {
        // No heavy cache exists in the Phase-1 fixture. This method is deliberately real so the
        // same lifecycle path can later trim KV/model caches without changing AppModel/UI code.
    }

    func unload() {
        cancellationEpoch &+= 1
        state = .unloaded
    }

    private static func foundationResponse(to input: String, visualContext: AgentVisualContext?) -> String {
        let clipped = String(input.prefix(72))
        let visual = visualContext.map { " 当前摄像头摘要：\($0.compactPromptDescription)。" } ?? ""
        return "已在本机收到「\(clipped)」。\(visual)当前运行的是 VeilLink 本地基础运行时（Foundation Mock）；视频链路已经能把低频本地视觉摘要并入同一请求，但真正的本地文本/视觉模型仍需由训练与推理后端替换。"
    }
}
