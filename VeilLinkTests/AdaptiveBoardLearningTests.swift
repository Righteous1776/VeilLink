import XCTest
@testable import VeilLink

@MainActor
final class AdaptiveBoardLearningTests: XCTestCase {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("veillink-learning-\(UUID().uuidString)")
            .appendingPathComponent("learning.json")
    }

    func testLearningPersistsEveryRecordedPositionWithoutArtificialCap() throws {
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
        XCTAssertEqual(store.summary.rememberedPositions, 2_400)
        XCTAssertGreaterThan(store.summary.storedBytes, 0)

        let restored = AdaptiveBoardLearningStore(fileURL: url)
        XCTAssertEqual(restored.summary.completedGames, 80)
        XCTAssertEqual(restored.summary.rememberedPositions, store.summary.rememberedPositions)
    }

    func testStoredBytesMatchesFileMetadataAfterUnboundedHistoryWrites() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = AdaptiveBoardLearningStore(fileURL: url)
        for index in 0..<65 {
            store.record(
                game: .gomoku,
                plies: [AdaptiveBoardPly(position: "g:stat-\(index)", action: "112", actor: .host)],
                result: .humanWon
            )
        }
        let expectedBytes = try XCTUnwrap(
            (try FileManager.default.attributesOfItem(atPath: url.path))[.size] as? NSNumber
        ).intValue
        XCTAssertGreaterThan(expectedBytes, 0)
        XCTAssertEqual(store.summary.storedBytes, expectedBytes)
        XCTAssertEqual(store.summary.completedGames, 65)
    }

    func testGameScopedStoresDoNotLeakSummariesOrPositions() {
        let gomokuURL = temporaryURL()
        let xiangqiURL = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: gomokuURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: xiangqiURL.deletingLastPathComponent())
        }
        let gomoku = AdaptiveBoardLearningStore(game: .gomoku, fileURL: gomokuURL)
        let xiangqi = AdaptiveBoardLearningStore(game: .xiangqi, fileURL: xiangqiURL)
        gomoku.record(
            game: .gomoku,
            plies: [AdaptiveBoardPly(position: "g:opening", action: "112", actor: .host)],
            result: .humanWon
        )

        XCTAssertEqual(gomoku.summary.completedGames, 1)
        XCTAssertEqual(gomoku.summary.rememberedPositions, 1)
        XCTAssertEqual(xiangqi.summary.completedGames, 0)
        XCTAssertEqual(xiangqi.summary.rememberedPositions, 0)
        XCTAssertEqual(xiangqi.snapshot().bonus(position: "g:opening", action: "112"), 0)
    }

    func testLegacyMigrationSplitsGamesWithoutMutatingSharedSource() throws {
        let legacyURL = temporaryURL()
        let gomokuURL = temporaryURL()
        let xiangqiURL = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: legacyURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: gomokuURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: xiangqiURL.deletingLastPathComponent())
        }
        let legacy = AdaptiveBoardLearningStore(fileURL: legacyURL)
        legacy.record(
            game: .gomoku,
            plies: [AdaptiveBoardPly(position: "g:legacy", action: "112", actor: .host)],
            result: .humanWon
        )
        legacy.record(
            game: .xiangqi,
            plies: [AdaptiveBoardPly(position: "x:legacy", action: "64:67", actor: .host)],
            result: .aiWon
        )
        let originalLegacy = try Data(contentsOf: legacyURL)

        let gomoku = AdaptiveBoardLearningStore(
            game: .gomoku,
            fileURL: gomokuURL,
            legacyURL: legacyURL
        )
        let xiangqi = AdaptiveBoardLearningStore(
            game: .xiangqi,
            fileURL: xiangqiURL,
            legacyURL: legacyURL
        )

        XCTAssertEqual(gomoku.summary.completedGames, 1)
        XCTAssertEqual(gomoku.summary.rememberedPositions, 1)
        XCTAssertEqual(xiangqi.summary.completedGames, 1)
        XCTAssertEqual(xiangqi.summary.rememberedPositions, 1)
        XCTAssertEqual(try Data(contentsOf: legacyURL), originalLegacy)
    }

    func testScopedClearAfterLegacyMigrationPersistsAcrossRestart() throws {
        let legacyURL = temporaryURL()
        let scopedURL = temporaryURL()
        defer {
            try? FileManager.default.removeItem(at: legacyURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: scopedURL.deletingLastPathComponent())
        }

        let legacy = AdaptiveBoardLearningStore(fileURL: legacyURL)
        legacy.record(
            game: .gomoku,
            plies: [AdaptiveBoardPly(position: "g:migration-clear-regression", action: "112", actor: .host)],
            result: .humanWon
        )
        let originalLegacy = try Data(contentsOf: legacyURL)
        let scoped = AdaptiveBoardLearningStore(game: .gomoku, fileURL: scopedURL, legacyURL: legacyURL)
        XCTAssertEqual(scoped.summary.completedGames, 1)
        XCTAssertEqual(scoped.summary.rememberedPositions, 1)

        scoped.clear()
        XCTAssertTrue(scoped.lastSaveSucceeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: scopedURL.path),
                      "Empty scoped database must block legacy re-migration")
        XCTAssertEqual(scoped.summary.rememberedPositions, 0)

        let restarted = AdaptiveBoardLearningStore(game: .gomoku, fileURL: scopedURL, legacyURL: legacyURL)
        XCTAssertEqual(restarted.summary.completedGames, 0)
        XCTAssertEqual(restarted.summary.rememberedPositions, 0)
        XCTAssertEqual(try Data(contentsOf: legacyURL), originalLegacy)
    }

    func testRepeatedInterruptedLinePenalisesOldAIReplyAndPredictsHumanFormation() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = AdaptiveBoardLearningStore(game: .xiangqi, fileURL: url)
        let line = [
            AdaptiveBoardPly(position: "x:start", action: "64:67", actor: .host),
            AdaptiveBoardPly(position: "x:after-human", action: "19:22", actor: .guest),
            AdaptiveBoardPly(position: "x:formation", action: "82:65", actor: .host)
        ]
        store.record(game: .xiangqi, plies: line, result: .unfinished)
        store.record(game: .xiangqi, plies: line, result: .unfinished)

        let snapshot = store.snapshot(currentPlies: [line[0]])
        XCTAssertLessThan(snapshot.rootAdjustment(action: "19:22"), 0)
        XCTAssertEqual(
            snapshot.predictedHumanReply(afterAIAction: "19:22")?.action,
            "82:65"
        )
        let profile = store.coachProfile(for: .xiangqi)
        XCTAssertEqual(profile.completedGames, 0)
        XCTAssertEqual(profile.preferredOpening, "偏好中炮")
        XCTAssertGreaterThanOrEqual(profile.repeatedLineCount, 1)
        XCTAssertTrue(profile.reviewFocus.contains("中断局"))
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
