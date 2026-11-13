import XCTest
@testable import VeilLink

final class GomokuLossReplayGateTests: XCTestCase {
    func testFiveTimesRepeatedHumanForkFailure() {
        var board = GomokuState()
        for move in [112, 96, 81, 82, 110, 98, 111, 113, 109, 108, 95] {
            XCTAssertTrue(board.apply(index: move, actor: board.currentPlayer))
        }
        let ai = board.currentPlayer
        XCTAssertFalse(GomokuBot.externalMovePassesTacticalGate(in: board, for: ai, index: 83))
        XCTAssertTrue(GomokuBot.externalMovePassesTacticalGate(in: board, for: ai, index: 67))
        XCTAssertTrue(GomokuBot.externalMovePassesTacticalGate(in: board, for: ai, index: 123))
    }

    func testRejectsOccupiedAndOutOfRangeExternalMoves() {
        var board = GomokuState()
        XCTAssertTrue(board.apply(index: 112, actor: board.currentPlayer))
        let ai = board.currentPlayer
        XCTAssertFalse(GomokuBot.externalMovePassesTacticalGate(in: board, for: ai, index: 112))
        XCTAssertFalse(GomokuBot.externalMovePassesTacticalGate(in: board, for: ai, index: 225))
    }
}
