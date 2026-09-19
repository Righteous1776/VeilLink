import XCTest
@testable import VeilLink

@MainActor
final class AgentGameExecutionValidationTests: XCTestCase {
    private func initialSession(id: String = UUID().uuidString) -> MiniGameSessionSnapshot {
        let now = Date(timeIntervalSince1970: 1)
        return MiniGameSessionSnapshot(
            id: id,
            game: .gomoku,
            hostIsLocal: true,
            status: .active,
            invitedAt: now,
            startedAt: now,
            lastActivity: now,
            gomoku: GomokuState(),
            xiangqi: nil,
            ludo: nil,
            tactical: nil,
            endedByResignation: false
        )
    }

    func testSuggestedMoveMustStillBeLegalForCurrentSession() {
        let session = initialSession()
        let action = AgentSuggestedGameAction(
            sessionID: session.id,
            peerIdentityID: "peer",
            gameID: MiniGameKind.gomoku.rawValue,
            gameTitle: MiniGameKind.gomoku.title,
            turn: 0,
            move: .gomoku(index: 112),
            actionID: "candidate",
            label: "center"
        )

        XCTAssertTrue(AgentGameContextBroker.suggestedActionRemainsLegal(action, in: session))
    }

    func testSuggestedMoveIsRejectedAfterBoardChanges() {
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        let now = Date(timeIntervalSince1970: 1)
        let session = MiniGameSessionSnapshot(
            id: UUID().uuidString,
            game: .gomoku,
            hostIsLocal: true,
            status: .active,
            invitedAt: now,
            startedAt: now,
            lastActivity: now,
            gomoku: state,
            xiangqi: nil,
            ludo: nil,
            tactical: nil,
            endedByResignation: false
        )
        let stale = AgentSuggestedGameAction(
            sessionID: session.id,
            peerIdentityID: "peer",
            gameID: MiniGameKind.gomoku.rawValue,
            gameTitle: MiniGameKind.gomoku.title,
            turn: 0,
            move: .gomoku(index: 112),
            actionID: "stale",
            label: "stale"
        )

        XCTAssertFalse(AgentGameContextBroker.suggestedActionRemainsLegal(stale, in: session))
    }

    func testSuggestedMoveRejectsWrongTurnAndWrongSession() {
        let session = initialSession()
        let wrongTurn = AgentSuggestedGameAction(
            sessionID: session.id,
            peerIdentityID: "peer",
            gameID: MiniGameKind.gomoku.rawValue,
            gameTitle: MiniGameKind.gomoku.title,
            turn: 99,
            move: .gomoku(index: 112),
            actionID: "wrong-turn",
            label: "wrong"
        )
        let wrongSession = AgentSuggestedGameAction(
            sessionID: UUID().uuidString,
            peerIdentityID: "peer",
            gameID: MiniGameKind.gomoku.rawValue,
            gameTitle: MiniGameKind.gomoku.title,
            turn: 0,
            move: .gomoku(index: 112),
            actionID: "wrong-session",
            label: "wrong"
        )

        XCTAssertFalse(AgentGameContextBroker.suggestedActionRemainsLegal(wrongTurn, in: session))
        XCTAssertFalse(AgentGameContextBroker.suggestedActionRemainsLegal(wrongSession, in: session))
    }
}
