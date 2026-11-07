import XCTest
@testable import VeilLink

final class BoardLearnedMoveOrderR2Tests: XCTestCase {
    func testGomokuTrainedPolicyIsDeterministicAndBounded() {
        var board = GomokuState()
        XCTAssertTrue(board.apply(index: 112, actor: .host))
        XCTAssertTrue(board.apply(index: 111, actor: .guest))
        XCTAssertTrue(board.apply(index: 97, actor: .host))
        let legal = [96, 98, 113, 127, 81]
        let scores = legal.map { BoardLearnedMoveOrderR2.gomokuBonus(in: board, player: .guest, index: $0) }
        XCTAssertEqual(scores, legal.map { BoardLearnedMoveOrderR2.gomokuBonus(in: board, player: .guest, index: $0) })
        XCTAssertTrue(scores.allSatisfy { (-480...480).contains($0) })
        XCTAssertGreaterThan(Set(scores).count, 1)
        XCTAssertEqual(BoardLearnedMoveOrderR2.gomokuBonus(in: board, player: .guest, index: 111), 0)
    }

    func testXiangqiTrainedOrderingIsBounded() {
        let board = XiangqiState()
        let rook = BoardLearnedMoveOrderR2.xiangqiBonus(in: board, from: 81, to: 72)
        let pawn = BoardLearnedMoveOrderR2.xiangqiBonus(in: board, from: 54, to: 45)
        XCTAssertNotEqual(rook, pawn)
        XCTAssertTrue((-60...60).contains(rook))
        XCTAssertTrue((-60...60).contains(pawn))
        XCTAssertEqual(BoardLearnedMoveOrderR2.xiangqiBonus(in: board, from: 88, to: -1), 0)
    }

    @MainActor
    func testGomokuNegativeLearningSurvivesRestart() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("r2-feedback-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let archive = AdaptiveBoardLearningStore(game: .gomoku, fileURL: url)
        var state = GomokuState()
        XCTAssertTrue(state.apply(index: 112, actor: .host))
        let key = AdaptiveBoardPosition.gomoku(state)
        archive.record(game: .gomoku, plies: [AdaptiveBoardPly(position: key, action: "114", actor: .guest)], result: .humanWon)
        XCTAssertLessThan(archive.snapshot().bonus(position: key, action: "114"), 0)
        let reloaded = AdaptiveBoardLearningStore(game: .gomoku, fileURL: url)
        XCTAssertEqual(reloaded.snapshot().bonus(position: key, action: "114"), archive.snapshot().bonus(position: key, action: "114"))
    }

    @MainActor
    func testXiangqiNegativeLearningIsNotClampedToZero() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("r2-xfeedback-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let archive = AdaptiveBoardLearningStore(game: .xiangqi, fileURL: url)
        var state = XiangqiState()
        XCTAssertTrue(state.apply(from: 64, to: 55, actor: .host))
        let key = AdaptiveBoardPosition.xiangqi(state)
        archive.record(game: .xiangqi, plies: [AdaptiveBoardPly(position: key, action: "1:20", actor: .guest)], result: .humanWon)
        XCTAssertLessThan(archive.snapshot().bonus(position: key, action: "1:20"), 0)
    }
}
