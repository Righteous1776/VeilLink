import XCTest
@testable import VeilLink

final class LocalTextRuntimeTests: XCTestCase {
    @MainActor
    func testFoundationMockStreamsLocallyAndReturnsToReady() async throws {
        let runtime = MockLocalTextModelRuntime()
        XCTAssertEqual(runtime.state, .unloaded)
        try await runtime.prepare()
        XCTAssertEqual(runtime.state, .ready)

        var streamed = ""
        let request = AgentTextRequest(
            sessionID: "test",
            messages: [],
            userText: "你好",
            maxNewTokens: 32,
            visualContext: nil
        )
        let result = try await runtime.generate(request: request) { chunk in
            streamed += chunk
        }
        XCTAssertEqual(runtime.state, .ready)
        XCTAssertEqual(streamed, result.text)
        XCTAssertTrue(streamed.contains("Foundation Mock"))
        XCTAssertGreaterThan(result.emittedChunkCount, 0)
        XCTAssertEqual(runtime.manifest?.minimumOS, "15.0")
    }

    @MainActor
    func testFoundationMockCanUnloadWithoutExternalModel() async throws {
        let runtime = MockLocalTextModelRuntime()
        try await runtime.prepare()
        runtime.trimMemory()
        runtime.unload()
        XCTAssertEqual(runtime.state, .unloaded)
        XCTAssertEqual(runtime.manifest?.byteCount, 0)
    }
}
