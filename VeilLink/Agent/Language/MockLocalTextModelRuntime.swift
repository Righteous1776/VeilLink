import Foundation

/// Deterministic fixture used by fast CI or as an explicit fallback when the real llama module
/// is not compiled. It never pretends to be a language model and performs no network access.
@MainActor
final class MockLocalTextModelRuntime: LocalTextModelRuntime {
    private(set) var state: AgentRuntimeState = .unloaded
    let manifest: LocalTextModelManifest? = LocalTextModelManifest(
        id: "veillink.foundation.mock.v2",
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
        let response = Self.foundationResponse(
            to: input,
            visualContext: request.visualContext,
            localContext: request.localContext
        )
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

    func trimMemory() {}

    func unload() {
        cancellationEpoch &+= 1
        state = .unloaded
    }

    private static func foundationResponse(
        to input: String,
        visualContext: AgentVisualContext?,
        localContext: AgentLocalContext?
    ) -> String {
        let clipped = String(input.prefix(72))
        let visual = visualContext.map { " 当前摄像头摘要：\($0.compactPromptDescription)。" } ?? ""
        let local = localContext.map {
            let game = $0.game.map { "；当前对局=\($0.gameTitle)，本方回合=\($0.isLocalTurn ? "是" : "否")" } ?? ""
            return " 当前已接入本机上下文：BLE连接 \($0.bluetooth.connectedPeers)/\($0.bluetooth.trackedPeers)，A9=\($0.a9HealthScore)/100\(game)。"
        } ?? ""
        return "已在本机收到「\(clipped)」。\(visual)\(local)当前运行的是 VeilLink 的确定性测试运行时；Release 本地 AI 构建应由真实 Qwen/llama Runtime 替代。"
    }
}
