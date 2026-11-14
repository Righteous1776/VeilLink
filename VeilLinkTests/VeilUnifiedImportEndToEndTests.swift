import Foundation
import XCTest
@testable import VeilLink

/// Exercises a *real* supported destination, not only filename classification:
/// Files staging -> durable inbox -> route -> database write -> reopen.
@MainActor
final class VeilUnifiedImportEndToEndTests: XCTestCase {
    private let fm = FileManager.default

    func testBoardLearningSurvivesReopeningGameStoreAfterUnifiedFilesImport() throws {
        let root = fm.temporaryDirectory.appendingPathComponent(
            "VeilUnifiedE2E-" + UUID().uuidString, isDirectory: true
        )
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let originalDatabase = root.appendingPathComponent("source-gomoku.json")
        let sourceStore = AdaptiveBoardLearningStore(game: .gomoku, fileURL: originalDatabase)
        sourceStore.record(
            game: .gomoku,
            plies: [
                AdaptiveBoardPly(position: "g:one", action: "112", actor: .host),
                AdaptiveBoardPly(position: "g:two", action: "113", actor: .guest)
            ],
            result: .humanWon
        )
        XCTAssertEqual(sourceStore.summary.completedGames, 1)
        let archive = try sourceStore.exportPackage()
        defer { try? fm.removeItem(at: archive) }

        // Files provider copy is always isolated from business data.
        let staged = try VeilImportedFileAccess.materialize(archive)
        defer { VeilImportedFileAccess.removeStagedCopy(staged) }
        let inbox = root.appendingPathComponent("FileInbox", isDirectory: true)
        let record = try VeilFileInbox.importStaged(staged, root: inbox)
        XCTAssertTrue(try VeilFileInbox.verify(record, root: inbox))

        let resolvedURL = try VeilFileInbox.fileURL(for: record, root: inbox)
        XCTAssertEqual(VeilUnifiedImportRouter.resolve(record, at: resolvedURL), .boardLearning(.gomoku))

        let destinationDatabase = root.appendingPathComponent("destination-gomoku.json")
        let destinationStore = AdaptiveBoardLearningStore(game: .gomoku, fileURL: destinationDatabase)
        XCTAssertEqual(destinationStore.summary.completedGames, 0)
        let report = try destinationStore.importPackage(from: resolvedURL)
        XCTAssertEqual(report.completedGames, 1)
        XCTAssertEqual(report.rememberedPositions, 2)

        // A new store instance uses the saved data, not cached in-memory import.
        let reopened = AdaptiveBoardLearningStore(game: .gomoku, fileURL: destinationDatabase)
        XCTAssertEqual(reopened.summary.completedGames, 1)
        XCTAssertEqual(reopened.summary.rememberedPositions, 2)

        // No cross-game data, and Files provider source remains unchanged.
        let xiangqiDB = root.appendingPathComponent("xiangqi.json")
        let xiangqi = AdaptiveBoardLearningStore(game: .xiangqi, fileURL: xiangqiDB)
        XCTAssertEqual(xiangqi.summary.completedGames, 0)
        XCTAssertTrue(fm.fileExists(atPath: archive.path))
        XCTAssertTrue(try VeilFileInbox.verify(record, root: inbox))
    }

    func testMalformedTrainingPackageNeverMutatesDestinationDatabase() throws {
        let root = fm.temporaryDirectory.appendingPathComponent(
            "VeilUnifiedBad-" + UUID().uuidString, isDirectory: true
        )
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let original = root.appendingPathComponent("fake.vltrain.json")
        try Data("{\"format\":\"veillink.board-learning.export.v1\",\"payload\":{}}".utf8)
            .write(to: original)
        let staged = try VeilImportedFileAccess.materialize(original)
        defer { VeilImportedFileAccess.removeStagedCopy(staged) }
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        let record = try VeilFileInbox.importStaged(staged, root: inbox)
        let url = try VeilFileInbox.fileURL(for: record, root: inbox)
        guard case .retained = VeilUnifiedImportRouter.resolve(record, at: url) else {
            return XCTFail("Malformed training input should not be routed for mutation.")
        }

        let store = AdaptiveBoardLearningStore(
            game: .gomoku,
            fileURL: root.appendingPathComponent("existing.json")
        )
        XCTAssertEqual(store.summary.completedGames, 0)
        XCTAssertThrowsError(try store.importPackage(from: url))
        XCTAssertEqual(store.summary.completedGames, 0)
    }
}
