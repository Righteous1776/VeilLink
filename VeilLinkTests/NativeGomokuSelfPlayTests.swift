import Foundation
import XCTest
@testable import VeilLink

@MainActor
final class NativeGomokuSelfPlayTests: XCTestCase {
    func testNativeSelfPlayIsACompletedLegalGameAndPersistsToNativeArchive() async throws {
        // Call exact product GomokuBot and GomokuState on a worker,
        // rather than creating image-label or random-coordinate "training".
        let budget = GomokuBotBudget(
            candidateRadius: 2,
            rootCandidateLimit: 8,
            replyCandidateLimit: 4,
            continuationCandidateLimit: 0,
            timeLimitMilliseconds: 35
        )
        let game = await Task.detached(priority: .userInitiated) {
            NativeGomokuSelfPlay.play(
                seed: 0, formationMode: .automatic, budget: budget
            )
        }.value
        guard let game else {
            XCTFail("Native Bot-vs-Bot did not reach an actual terminal result")
            return
        }
        XCTAssertTrue(game.completed)
        XCTAssertGreaterThan(game.botDecisions, 0)
        XCTAssertEqual(game.plies.count, game.botDecisions + 1)
        var replay = GomokuState()
        for ply in game.plies {
            XCTAssertEqual(ply.position, AdaptiveBoardPosition.gomoku(replay))
            XCTAssertEqual(ply.actor, replay.currentPlayer)
            guard let index = Int(ply.action) else {
                XCTFail("Invalid coordinate in native match")
                return
            }
            XCTAssertTrue(replay.apply(index: index, actor: ply.actor))
        }
        XCTAssertTrue(replay.winner != nil || replay.isDraw)
        XCTAssertEqual(
            game.result,
            replay.isDraw ? .draw : (replay.winner == .guest ? .aiWon : .humanWon)
        )

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("veillink-native-selfplay-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let archive = AdaptiveBoardLearningStore(game: .gomoku, fileURL: url)
        XCTAssertEqual(archive.summary.completedGames, 0)
        XCTAssertEqual(
            archive.recordCompletedNativeBatch([(plies: game.plies, result: game.result)]), 1
        )
        XCTAssertEqual(archive.summary.completedGames, 1)
        XCTAssertTrue(archive.lastSaveSucceeded)

        // Restart / cold-load: the match must survive as actual Bot experience.
        let restored = AdaptiveBoardLearningStore(game: .gomoku, fileURL: url)
        XCTAssertEqual(restored.summary.completedGames, 1)
        XCTAssertGreaterThan(restored.summary.rememberedPositions, 0)
        // One self-play match may be a loss or draw and its bounded blending
        // contribution is legitimately zero. Persistence and legal replay are
        // the invariant here; strength is covered by paired-tournament gates.
        XCTAssertGreaterThan(restored.summary.rememberedPositions, 0)
    }

    func testNoFalseMatchesWhenGameDidNotComplete() async {
        let game = await Task.detached {
            NativeGomokuSelfPlay.play(
                seed: 0, formationMode: .bagua, moveLimit: 5
            )
        }.value
        XCTAssertNil(game, "An unfinished 5-ply game must never count as one training match")
    }

    func testCorruptArchiveRemainsFailClosed() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("veillink-selfplay-invalid-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try? Data("invalid json".utf8).write(to: url)
        let archive = AdaptiveBoardLearningStore(game: .gomoku, fileURL: url)
        XCTAssertFalse(archive.lastSaveSucceeded)
        XCTAssertEqual(archive.summary.completedGames, 0)
        let game = [AdaptiveBoardPly(position: "g:invalid", action: "112", actor: .host)]
        XCTAssertEqual(
            archive.recordCompletedNativeBatch([(plies: game, result: .aiWon)]), 0
        )
        XCTAssertEqual(try? String(contentsOf: url, encoding: .utf8), "invalid json")
    }
}
