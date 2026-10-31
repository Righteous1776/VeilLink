import XCTest
@testable import VeilLink

final class VeilBaguaFormationTests: XCTestCase {
    func testKnightGeometryIsTranslationInvariantAndBounded() {
        XCTAssertTrue(VeilBaguaFormation.isKnightMove(from: 112, to: 81))
        XCTAssertTrue(VeilBaguaFormation.isKnightMove(from: 0, to: 17))
        XCTAssertFalse(VeilBaguaFormation.isKnightMove(from: 112, to: 96))
        XCTAssertFalse(VeilBaguaFormation.isKnightMove(from: 0, to: -1))
        XCTAssertFalse(VeilBaguaFormation.isKnightMove(from: 224, to: 225))
    }

    func testRecognizesRecordedKnightTransitionsWithoutTreatingThemAsWins() {
        let history = [["h112", "a80", "h81", "a83", "h64", "a85", "h93"]]
        let sample = VeilBaguaFormation.analyze(games: history)
        XCTAssertEqual(sample.moves, 4)
        XCTAssertEqual(sample.transitions, 3)
        XCTAssertEqual(sample.knightTransitions, 3)
        XCTAssertEqual(sample.ratio, 1)
        XCTAssertFalse(sample.isCandidate) // too little evidence to certify a style
    }
}

@MainActor
final class ReviewedBoardSeedMergeTests: XCTestCase {
    func testAdditiveSeedImportPreservesHistoryAndIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = AdaptiveBoardLearningStore(game: .gomoku, fileURL: root.appendingPathComponent("source.json"))
        let target = AdaptiveBoardLearningStore(game: .gomoku, fileURL: root.appendingPathComponent("target.json"))
        source.record(game: .gomoku, plies: [
            .init(position: "g:source", action: "112", actor: .host)
        ], result: .humanWon)
        target.record(game: .gomoku, plies: [
            .init(position: "g:existing", action: "81", actor: .host)
        ], result: .aiWon)
        let exported = try source.exportPackage()
        defer { try? FileManager.default.removeItem(at: exported) }

        let first = try target.mergeReviewedPackage(from: exported)
        XCTAssertEqual(first.completedGames, 2)
        XCTAssertEqual(first.rememberedPositions, 2)
        let second = try target.mergeReviewedPackage(from: exported)
        XCTAssertEqual(first, second)

        let restored = AdaptiveBoardLearningStore(game: .gomoku, fileURL: root.appendingPathComponent("target.json"))
        XCTAssertEqual(restored.summary.completedGames, 2)
        XCTAssertEqual(restored.summary.rememberedPositions, 2)
    }
}
