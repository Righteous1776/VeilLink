import XCTest
@testable import VeilLink

#if REAL_LOCAL_AI_REQUIRED
@MainActor
final class RealLocalInferenceSmokeTests: XCTestCase {
    func testBundledQwenProducesVisibleOfflineText() async throws {
        let profile = AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        let runtime = LlamaLocalTextModelRuntime(profile: profile)
        try await runtime.prepare()
        defer { runtime.unload() }

        let request = AgentTextRequest(
            sessionID: "ci-real-local-ai",
            messages: [AgentMessage(role: .user, text: "用一句简短中文回答：你现在在哪里运行？")],
            userText: "用一句简短中文回答：你现在在哪里运行？",
            maxNewTokens: 32,
            visualContext: nil
        )
        var streamed = ""
        let result = try await runtime.generate(request: request) { chunk in
            streamed += chunk
        }

        XCTAssertTrue(LocalTextModelRuntimeFactory.isRealLocalInferenceCompiled)
        XCTAssertGreaterThan(result.estimatedTokenCount, 0)
        XCTAssertFalse(streamed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(streamed.contains("<think>"))

        guard let stats = runtime.lastGenerationStats else {
            XCTFail("Real llama.cpp generation stats were not published")
            return
        }
        let metrics: [String: Any] = [
            "model_id": LocalModelCatalog.primary.id,
            "model_load_ms": runtime.lastModelLoadMilliseconds ?? -1,
            "prompt_tokens": stats.promptTokenCount,
            "generated_tokens": stats.generatedTokenCount,
            "first_visible_ms": stats.firstVisibleTokenMilliseconds ?? -1,
            "total_ms": stats.totalMilliseconds,
            "tokens_per_second": stats.generatedTokensPerSecond,
            "visible_characters": streamed.count,
            "chat_template": stats.usedModelChatTemplate ? "gguf" : "fallback-chatml"
        ]
        let data = try JSONSerialization.data(withJSONObject: metrics, options: [.sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
        print("VEILLINK_AI_METRICS_JSON=\(json)")
    }
}
#endif
