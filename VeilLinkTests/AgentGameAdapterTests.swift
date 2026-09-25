import XCTest
@testable import VeilLink

final class AgentGameAdapterTests: XCTestCase {
    func testTrainingRegistryExcludesTactical() {
        XCTAssertTrue(AgentGameRegistry.isTrainingEnabled(.gomoku))
        XCTAssertTrue(AgentGameRegistry.isTrainingEnabled(.xiangqi))
        XCTAssertTrue(AgentGameRegistry.isTrainingEnabled(.ludo))
        XCTAssertFalse(AgentGameRegistry.isTrainingEnabled(.tactical))
        XCTAssertNotNil(AgentGameRegistry.exclusionReason(for: .tactical))
    }

    func testGomokuAdapterEnumeratesOnlyEmptySquares() {
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        let adapter = GomokuAgentAdapter(state: state, actor: .guest)
        XCTAssertEqual(adapter.enumerateLegalActions().count, 224)
        XCTAssertFalse(adapter.enumerateLegalActions().contains { $0.metadata["index"] == "112" })
        XCTAssertEqual(adapter.makeObservation().features.count, 228)
    }

    func testXiangqiAdapterActionsValidateAgainstEngine() {
        let state = XiangqiState()
        let adapter = XiangqiAgentAdapter(state: state, actor: .host)
        let actions = adapter.enumerateLegalActions()
        XCTAssertFalse(actions.isEmpty)
        XCTAssertTrue(actions.allSatisfy(adapter.validate))
        XCTAssertEqual(adapter.makeObservation().features.count, 95)
    }

    func testLudoAdapterUsesDeterministicDiceAndLegalCandidates() {
        let state = LudoState()
        let sessionID = "00000000-0000-0000-0000-000000000001"
        let adapter = LudoAgentAdapter(state: state, actor: .host, sessionID: sessionID)
        XCTAssertFalse(adapter.enumerateLegalActions().isEmpty)
        XCTAssertTrue(adapter.enumerateLegalActions().allSatisfy(adapter.validate))
        XCTAssertEqual(adapter.makeObservation().features.count, 11)
    }

    @MainActor
    func testVisualContextFlowsIntoFoundationRequest() async throws {
        let runtime = MockLocalTextModelRuntime()
        try await runtime.prepare()
        let visual = AgentVisualContext(
            capturedAt: Date(timeIntervalSince1970: 1),
            faceCount: 1,
            labels: ["person", "indoor"],
            recognizedText: ["VeilLink"],
            frameWidth: 640,
            frameHeight: 480
        )
        let request = AgentTextRequest(
            sessionID: "visual",
            messages: [],
            userText: "你看到了什么？",
            maxNewTokens: 64,
            visualContext: visual
        )
        var streamed = ""
        _ = try await runtime.generate(request: request) { streamed += $0 }
        XCTAssertTrue(streamed.contains("摄像头摘要"))
        XCTAssertTrue(streamed.contains("VeilLink"))
    }
}
