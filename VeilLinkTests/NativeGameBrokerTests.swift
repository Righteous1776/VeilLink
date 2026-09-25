import XCTest
@testable import VeilLink

@MainActor
final class NativeGameBrokerTests: XCTestCase {
    func testCoreBrokerPublishesNativeGomokuSuggestionWithoutMaleCNS() async throws {
        let suite = "studio.zeo.VeilLinkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        _ = AgentControlCenterSettings(defaults: defaults)
        let broker = AgentGameContextBroker()
        let now = Date(timeIntervalSince1970: 10)
        let session = MiniGameSessionSnapshot(
            id: UUID().uuidString,
            game: .gomoku,
            hostIsLocal: true,
            status: .active,
            invitedAt: now,
            startedAt: now,
            lastActivity: now,
            gomoku: GomokuState(), xiangqi: nil, ludo: nil, tactical: nil,
            endedByResignation: false
        )

        broker.update(session: session, conversationTitle: "peer", peerIdentityID: "peer-id")
        XCTAssertEqual(broker.context?.policyMode, "native-bot")
        let deadline = Date().addingTimeInterval(1.0)
        while broker.currentSuggestedAction() == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        let action = broker.currentSuggestedAction(validating: session)
        XCTAssertNotNil(action)
        XCTAssertEqual(broker.context?.maleCNS, nil)
    }
}
