import XCTest
@testable import VeilLink

@MainActor
final class AdaptiveBoardLearningTests: XCTestCase {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("veillink-learning-\(UUID().uuidString)")
            .appendingPathComponent("learning.json")
    }

    func testLearningPersistsHumanRepertoireWithoutGrowingUnbounded() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = AdaptiveBoardLearningStore(fileURL: url)

        for game in 0..<80 {
            let plies = (0..<30).map { move in
                AdaptiveBoardPly(
                    position: "g:\(game)-\(move)",
                    action: String((game * 31 + move) % 225),
                    actor: move.isMultiple(of: 2) ? .host : .guest
                )
            }
            store.record(game: .gomoku, plies: plies, result: game.isMultiple(of: 3) ? .aiWon : .humanWon)
        }

        XCTAssertEqual(store.summary.completedGames, 80)
        XCTAssertLessThanOrEqual(store.summary.rememberedPositions, 1_600)
        XCTAssertLessThanOrEqual(store.summary.storedBytes, 512 * 1_024)

        let restored = AdaptiveBoardLearningStore(fileURL: url)
        XCTAssertEqual(restored.summary.completedGames, 80)
        XCTAssertEqual(restored.summary.rememberedPositions, store.summary.rememberedPositions)
    }

    func testRepeatedPlayerMoveBecomesSearchPreferenceAndCanBeCleared() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = AdaptiveBoardLearningStore(fileURL: url)
        let ply = AdaptiveBoardPly(position: "g:personal-opening", action: "112", actor: .host)

        store.record(game: .gomoku, plies: [ply], result: .humanWon)
        store.record(game: .gomoku, plies: [ply], result: .humanWon)

        XCTAssertGreaterThan(
            store.snapshot().bonus(position: "g:personal-opening", action: "112"),
            0
        )
        store.clear()
        XCTAssertEqual(store.summary.completedGames, 0)
        XCTAssertEqual(store.summary.rememberedPositions, 0)
    }

    func testRestartRetainsAnInterruptedGameAsTrainingEvidence() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = AdaptiveBoardLearningStore(fileURL: url)
        let controller = LocalAIGameController(game: .gomoku, learningStore: store)

        controller.humanGomokuMove(112)
        controller.restart()

        XCTAssertEqual(controller.learningSummary.completedGames, 0)
        XCTAssertEqual(controller.learningSummary.rememberedPositions, 1)
    }

    func testExportCanRoundTripIntoAValidatedEnhancedPackage() throws {
        let sourceURL = temporaryURL()
        let destinationURL = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: destinationURL.deletingLastPathComponent())
        }
        let source = AdaptiveBoardLearningStore(fileURL: sourceURL)
        source.record(
            game: .gomoku,
            plies: [AdaptiveBoardPly(position: "g:abc123", action: "112", actor: .host)],
            result: .humanWon
        )

        let packageURL = try source.exportPackage()
        let destination = AdaptiveBoardLearningStore(fileURL: destinationURL)
        let report = try destination.importPackage(from: packageURL)

        XCTAssertEqual(report.completedGames, 1)
        XCTAssertEqual(report.rememberedPositions, 1)
        XCTAssertGreaterThan(destination.snapshot().bonus(position: "g:abc123", action: "112"), 0)
    }

    func testImportRejectsPackageWhosePayloadWasEditedWithoutNewChecksum() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = AdaptiveBoardLearningStore(fileURL: url)
        store.record(
            game: .gomoku,
            plies: [AdaptiveBoardPly(position: "g:abc123", action: "112", actor: .host)],
            result: .humanWon
        )
        let packageURL = try store.exportPackage()
        let original = try String(contentsOf: packageURL, encoding: .utf8)
        let tampered = original.replacingOccurrences(of: "\"112\"", with: "\"113\"")
        try XCTUnwrap(tampered.data(using: .utf8)).write(to: packageURL, options: .atomic)

        XCTAssertThrowsError(try store.importPackage(from: packageURL)) { error in
            XCTAssertEqual(error as? AdaptiveBoardLearningPackageError, .checksumMismatch)
        }
    }
}
