import Foundation
import XCTest
@testable import VeilLink

final class VeilPerGameLearningJournalTests: XCTestCase {
    typealias E = VeilFormationSequenceEngine

    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("VL-Learning-\(UUID().uuidString)", isDirectory: true)
    }
    private func record(_ game: E.Game, _ outcome: E.Outcome) -> E.Episode {
        .init(game: game, plies: [
            .init(actor: .human, action: game == .gomoku ? "112" : "64:67"),
            .init(actor: .ai, action: game == .gomoku ? "113" : "1:20")
        ], outcome: outcome)
    }

    func testIndependentFilesCountsAndClear() throws {
        let dir = root()
        defer { try? FileManager.default.removeItem(at: dir) }
        let db = VeilPerGameLearningJournal(directory: dir)
        try db.append(record(.gomoku, .humanWon))
        try db.append(record(.gomoku, .unfinished))
        try db.append(record(.xiangqi, .aiWon))
        XCTAssertNotEqual(db.url(for: .gomoku), db.url(for: .xiangqi))
        XCTAssertEqual(try db.summary(for: .gomoku).episodes, 2)
        XCTAssertEqual(try db.summary(for: .gomoku).losses, 1)
        XCTAssertEqual(try db.summary(for: .gomoku).interruptions, 1)
        XCTAssertEqual(try db.summary(for: .xiangqi).episodes, 1)
        try db.clear(.gomoku)
        XCTAssertEqual(try db.summary(for: .gomoku).episodes, 0)
        XCTAssertEqual(try db.summary(for: .xiangqi).episodes, 1)
    }

    func testNo1600Or40GlobalPrune() throws {
        let dir = root()
        defer { try? FileManager.default.removeItem(at: dir) }
        let db = VeilPerGameLearningJournal(directory: dir)
        for _ in 0..<1650 { try db.append(record(.gomoku, .aiWon)) }
        XCTAssertEqual(try db.summary(for: .gomoku).episodes, 1650)
        XCTAssertEqual(try db.summary(for: .xiangqi).episodes, 0)
    }

    func testPerGameExportImportAndRollback() throws {
        let a = root(), b = root()
        defer {
            try? FileManager.default.removeItem(at: a)
            try? FileManager.default.removeItem(at: b)
        }
        let original = VeilPerGameLearningJournal(directory: a)
        let target = VeilPerGameLearningJournal(directory: b)
        try original.append(record(.xiangqi, .draw))
        try target.append(record(.gomoku, .humanWon))
        let exported = try original.export(for: .xiangqi)
        defer { try? FileManager.default.removeItem(at: exported) }
        let result = try target.importJournal(from: exported, for: .xiangqi)
        XCTAssertEqual(result.draws, 1)
        XCTAssertEqual(try target.summary(for: .xiangqi).episodes, 1)
        XCTAssertEqual(try target.summary(for: .gomoku).episodes, 1)

        let malicious = FileManager.default.temporaryDirectory.appendingPathComponent("corrupt-\(UUID().uuidString)")
        try Data("not json\n".utf8).write(to: malicious)
        defer { try? FileManager.default.removeItem(at: malicious) }
        XCTAssertThrowsError(try target.importJournal(from: malicious, for: .xiangqi))
        XCTAssertEqual(try target.summary(for: .xiangqi).episodes, 1)
    }
}
