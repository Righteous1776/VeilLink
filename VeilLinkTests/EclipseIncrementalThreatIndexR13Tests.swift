import XCTest
@testable import VeilLink

final class EclipseIncrementalThreatIndexR13Tests: XCTestCase {
    func testImmediateFivesAndUndo() throws {
        var board = [UInt8](repeating: 0, count: 225)
        for i in [108, 109, 110, 111] { board[i] = 1 }
        var index = try XCTUnwrap(EclipseIncrementalThreatIndexR13(cells: board))
        XCTAssertEqual(index.winningSquares(stone: 1), [107, 112])
        XCTAssertTrue(index.place(107, stone: 1))
        XCTAssertFalse(index.winsImmediately(stone: 1, at: 107))
        XCTAssertTrue(index.undo(107, stone: 1))
        XCTAssertEqual(index.winningSquares(stone: 1), [107, 112])
    }

    func testForkDeduplicatesCompletionEndpoints() throws {
        var board = [UInt8](repeating: 0, count: 225)
        for i in [109, 110, 111] { board[i] = 1 }
        let index = try XCTUnwrap(EclipseIncrementalThreatIndexR13(cells: board))
        XCTAssertTrue(index.forkSquares(stone: 1).contains(108))
        XCTAssertTrue(index.forkSquares(stone: 1).contains(112))
    }

    func testIllegalMoveCannotCorruptIndex() throws {
        let empty = [UInt8](repeating: 0, count: 225)
        var index = try XCTUnwrap(EclipseIncrementalThreatIndexR13(cells: empty))
        XCTAssertTrue(index.place(100, stone: 1))
        XCTAssertFalse(index.place(100, stone: 2))
        XCTAssertFalse(index.undo(100, stone: 2))
        XCTAssertTrue(index.undo(100, stone: 1))
        XCTAssertEqual(index.cells, empty)
    }

    func testFrozenCodexDefaultIsOffUntilGovernorEnables() {
        XCTAssertFalse(VeilGomokuUnifiedSearch.Limits().r13IncrementalThreatIndexEnabled)
    }
}
