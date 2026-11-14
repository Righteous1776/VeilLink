import XCTest
@testable import VeilLink

@MainActor
final class LocalLanguageModelRemovalTests: XCTestCase {
    func testProductionRuntimeIsAlwaysModelFree() {
        let runtime = LocalTextModelRuntimeFactory.make(
            profile: AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        )
        XCTAssertTrue(runtime is VeilTalkLiteRuntime)
        XCTAssertEqual(LocalTextModelRuntimeFactory.backendName, "VeilTalk Lite")
        XCTAssertFalse(LocalTextModelRuntimeFactory.isRealLocalInferenceCompiled)
    }

    func testNoLegacyLanguageGGUFIsShipped() {
        XCTAssertNil(Bundle.main.url(
            forResource: "Vertex-0.6-35M-Instruct-Q4_K_M",
            withExtension: "gguf",
            subdirectory: "LocalAI"
        ))
        XCTAssertNil(Bundle.main.url(
            forResource: "Vertex-0.6-35M-Instruct-Q4_K_M",
            withExtension: "gguf"
        ))
        XCTAssertNil(Bundle.main.url(
            forResource: "Qwen3-0.6B-Q4_0",
            withExtension: "gguf"
        ))
    }

    func testCoreChatRetainsModelFreeBackend() async throws {
        let runtime = LocalTextModelRuntimeFactory.make(
            profile: AgentCapabilityProfile.profile(devicePerformanceLabel: "LEGACY-COMPACT")
        )
        try await runtime.prepare()
        let request = AgentTextRequest(
            sessionID: "model-free-regression",
            messages: [AgentMessage(role: .user, text: "你好")],
            userText: "你好",
            maxNewTokens: 64,
            visualContext: nil
        )
        var streamed = ""
        let response = try await runtime.generate(request: request) { piece in
            streamed += piece
        }
        XCTAssertFalse(response.text.isEmpty)
        XCTAssertEqual(streamed, response.text)
        runtime.unload()
    }
}
