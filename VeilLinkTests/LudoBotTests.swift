import XCTest
@testable import VeilLink

final class LudoBotTests: XCTestCase {
    func testBotAlwaysReturnsRuleEngineLegalAction() {
        let sessionID = "00000000-0000-0000-0000-000000000001"
        var state = LudoState()
        let hostLegal = state.legalPieces(sessionID: sessionID)
        let hostAction = hostLegal.first ?? -1
        XCTAssertTrue(state.apply(pieceIndex: hostAction, actor: .host, sessionID: sessionID))

        let result = LudoBot.chooseMove(in: state, for: .guest, sessionID: sessionID)
        XCTAssertNotNil(result)
        guard let result else { return }
        XCTAssertTrue(state.apply(pieceIndex: result.pieceIndex, actor: .guest, sessionID: sessionID))
    }

    func testNoLegalMoveUsesPassSentinel() {
        let sessionID = "00000000-0000-0000-0000-000000000002"
        var state = LudoState()
        let legal = state.legalPieces(sessionID: sessionID)
        if legal.isEmpty {
            let move = LudoBot.chooseMove(in: state, for: .host, sessionID: sessionID)
            XCTAssertEqual(move?.pieceIndex, -1)
        }
    }
}
