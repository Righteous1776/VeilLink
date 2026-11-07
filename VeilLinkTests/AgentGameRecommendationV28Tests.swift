import XCTest
@testable import VeilLink

@MainActor
final class AgentGameRecommendationV28Tests: XCTestCase {
    private func session(_ state: GomokuState = GomokuState()) -> MiniGameSessionSnapshot {
        .init(id: "v28-current-game", game: .gomoku, hostIsLocal: true, status: .active,
              invitedAt: Date(), startedAt: Date(), lastActivity: Date(), gomoku: state,
              xiangqi: nil, ludo: nil, endedByResignation: false)
    }

    func testCompactDeviceStillGeneratesOnDemandLegalSuggestion() {
        let broker = AgentGameContextBroker(lightweightRuntime: true)
        let game = session()
        broker.update(session: game, conversationTitle: "对局", peerIdentityID: "peer")
        XCTAssertEqual(broker.context?.policyMode, "compact-safe")
        XCTAssertNil(broker.currentSuggestedAction())
        broker.update(session: game, conversationTitle: "对局", peerIdentityID: "peer",
                      requestNativeRecommendation: true)
        let action = broker.currentSuggestedAction(validating: game)
        XCTAssertEqual(action?.move, .gomoku(index: 112))
        XCTAssertEqual(broker.context?.policyMode, "native-bot")
        XCTAssertTrue(broker.context?.recommendations.isEmpty == false)
    }

    func testNewTurnRejectsPreviousSuggestionAndExecutionCannotRepeat() throws {
        let broker = AgentGameContextBroker(lightweightRuntime: true)
        let game = session()
        broker.update(session: game, conversationTitle: "对局", peerIdentityID: "peer",
                      requestNativeRecommendation: true)
        let action = try XCTUnwrap(broker.currentSuggestedAction())
        var next = GomokuState()
        XCTAssertTrue(next.apply(index: 112, actor: .host))
        XCTAssertNil(broker.currentSuggestedAction(validating: session(next)))
        broker.markSuggestedActionExecuted(action)
        XCTAssertNil(broker.currentSuggestedAction())
    }
}
