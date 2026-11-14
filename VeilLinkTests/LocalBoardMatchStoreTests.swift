import Foundation
import XCTest
@testable import VeilLink

@MainActor
final class LocalBoardMatchStoreTests: XCTestCase {
    private func store(_ game: MiniGameKind) throws -> (LocalBoardMatchStore, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "board-test-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (LocalBoardMatchStore(game: game, directory: directory), directory)
    }

    func testGomokuSurvivesControllerRecreationWhileComputerTurnPending() throws {
        let (disk, folder) = try store(.gomoku)
        defer { try? FileManager.default.removeItem(at: folder) }
        let game = LocalAIGameController(game: .gomoku, matchStore: disk)
        let originalID = game.sessionID
        game.humanGomokuMove(112)
        game.cancelAI()
        let recovered = LocalAIGameController(game: .gomoku, matchStore: disk)
        XCTAssertEqual(recovered.sessionID, originalID)
        XCTAssertTrue(recovered.didRestoreBoardMatch)
        XCTAssertEqual(recovered.gomoku.value(at: 112), 1)
        XCTAssertEqual(recovered.gomoku.currentPlayer, .guest)
        XCTAssertEqual(recovered.gomoku.moveCount, 1)
        XCTAssertFalse(recovered.isAIThinking)
    }

    func testXiangqiRestoresPawnAndTurn() throws {
        let (disk, folder) = try store(.xiangqi)
        defer { try? FileManager.default.removeItem(at: folder) }
        let game = LocalAIGameController(game: .xiangqi, matchStore: disk)
        game.humanXiangqiMove(from: 54, to: 45)
        game.cancelAI()
        let recovered = LocalAIGameController(game: .xiangqi, matchStore: disk)
        XCTAssertEqual(recovered.xiangqi.moveCount, 1)
        XCTAssertEqual(recovered.xiangqi.currentPlayer, .guest)
        XCTAssertEqual(recovered.xiangqi.piece(at: 45)?.side, .red)
    }

    func testCorruptFileIsNotOverwrittenUntilExplicitRestart() throws {
        let (disk, folder) = try store(.gomoku)
        defer { try? FileManager.default.removeItem(at: folder) }
        let invalid = Data("{broken".utf8)
        try invalid.write(to: disk.fileURL)
        let game = LocalAIGameController(game: .gomoku, matchStore: disk)
        XCTAssertNotNil(game.boardMatchSaveWarning)
        game.humanGomokuMove(112)
        game.cancelAI()
        XCTAssertEqual(try Data(contentsOf: disk.fileURL), invalid)
        game.restart()
        XCTAssertNil(game.boardMatchSaveWarning)
        XCTAssertNil(try disk.load())
        let retained = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.contains("-recovery-") }
        XCTAssertEqual(retained.count, 1)
    }

    func testRejectsDuplicateOrOutOfTurnMoves() throws {
        let (disk, folder) = try store(.gomoku)
        defer { try? FileManager.default.removeItem(at: folder) }
        let bad = LocalBoardMatchRecord(
            version: 1, game: .gomoku, sessionID: UUID().uuidString,
            difficulty: "balanced",
            moves: [
                .init(actor: .host, move: .gomoku(index: 112)),
                .init(actor: .guest, move: .gomoku(index: 112))
            ]
        )
        XCTAssertNil(LocalBoardMatchReplay.validate(bad))
        XCTAssertThrowsError(try disk.save(bad))
    }

    func testRestartDoesNotClearOtherGame() throws {
        let (_, sharedFolder) = try store(.gomoku)
        defer { try? FileManager.default.removeItem(at: sharedFolder) }
        let gomokuDisk = LocalBoardMatchStore(game: .gomoku, directory: sharedFolder)
        let xiangqiDisk = LocalBoardMatchStore(game: .xiangqi, directory: sharedFolder)
        let gomoku = LocalAIGameController(game: .gomoku, matchStore: gomokuDisk)
        let xiangqi = LocalAIGameController(game: .xiangqi, matchStore: xiangqiDisk)
        gomoku.humanGomokuMove(112); gomoku.cancelAI()
        xiangqi.humanXiangqiMove(from: 54, to: 45); xiangqi.cancelAI()
        let id = gomoku.sessionID
        gomoku.restart()
        XCTAssertNotEqual(gomoku.sessionID, id)
        XCTAssertNil(try gomokuDisk.load())
        XCTAssertEqual(try xiangqiDisk.load()?.moves.count, 1)
    }

    func testSecondSeatAndSemanticLearningRolesSurviveRestore() throws {
        let (disk, folder) = try store(.gomoku)
        defer { try? FileManager.default.removeItem(at: folder) }
        let legacySessionID = "white-human-\(UUID().uuidString)" // historical non-UUID IDs must restore safely
        let record = LocalBoardMatchRecord(version: 1, game: .gomoku, sessionID: legacySessionID,
            difficulty: "balanced", moves: [
                .init(actor: .host, move: .gomoku(index: 112)),
                .init(actor: .guest, move: .gomoku(index: 113))
            ], humanPlayer: .guest)
        try disk.save(record)
        let game = LocalAIGameController(game: .gomoku, matchStore: disk)
        XCTAssertEqual(game.humanPlayer, .guest)
        XCTAssertEqual(game.aiPlayer, .host)
        let replay = try XCTUnwrap(LocalBoardMatchReplay.validate(record))
        XCTAssertEqual(replay.plies.map(\.actor), [.guest, .host])
        game.restart()
        XCTAssertTrue(game.isAIThinking)
        game.cancelAI()
    }

    func testTeachingWithoutAnExistingDiskMatchRestoresOriginalEmptyGame() throws {
        let (disk, folder) = try store(.gomoku)
        defer { try? FileManager.default.removeItem(at: folder) }
        let game = LocalAIGameController(game: .gomoku, matchStore: disk)
        let id = game.sessionID
        game.beginDeveloperFormationRecording()
        game.developerGomokuMove(112)
        game.developerGomokuMove(113)
        game.setDeveloperTeachingMode(false)
        XCTAssertEqual(game.sessionID, id)
        XCTAssertEqual(game.gomoku.moveCount, 0)
        XCTAssertNil(try disk.load())
        XCTAssertTrue(game.canHumanAct)
    }
}
