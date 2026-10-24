import XCTest
@testable import VeilLink

final class VeilStoryEngineTests: XCTestCase {
    func testAllDemoBooksValidate() throws {
        XCTAssertEqual(VeilStoryLibrary.books.count, 3)
        for book in VeilStoryLibrary.books { try book.validate() }
    }

    func testNightTrainHiddenEnding() throws {
        let book = VeilStoryLibrary.nightTrain
        var run = try VeilStoryRun(book: book)
        try run.choose("ticket", in: book)
        try run.choose("envelope", in: book)
        try run.choose("follow", in: book)
        XCTAssertEqual(run.sceneID, "observatory")
        XCTAssertEqual(run.score, 25)
        XCTAssertEqual(run.items, ["ticket"])
        XCTAssertEqual(book.scene(id: run.sceneID)?.ending, "隐藏结局：夜空的坐标")
    }

    func testNightTrainOrdinaryEnding() throws {
        let book = VeilStoryLibrary.nightTrain
        var run = try VeilStoryRun(book: book)
        try run.choose("wait", in: book)
        XCTAssertEqual(run.sceneID, "morning")
        XCTAssertThrowsError(try run.choose("wait", in: book)) { error in
            XCTAssertEqual(error as? VeilStoryError, .storyFinished)
        }
    }

    func testInvalidChoiceIsAtomic() throws {
        let book = VeilStoryLibrary.nightTrain
        var run = try VeilStoryRun(book: book)
        let before = run
        XCTAssertThrowsError(try run.choose("does-not-exist", in: book))
        XCTAssertEqual(run, before)
    }

    func testReplayDeterministic() throws {
        let book = VeilStoryLibrary.lighthouse
        var run = try VeilStoryRun(book: book)
        try run.choose("workshop", in: book)
        try run.choose("climb", in: book)
        XCTAssertEqual(try VeilStoryRun.replay(book: book, decisions: run.history), run)
    }

    func testReplayRejectsTampering() throws {
        let book = VeilStoryLibrary.lighthouse
        let forged = VeilStoryDecision(fromScene: "dock", choiceID: "workshop", toScene: "quiet")
        XCTAssertThrowsError(try VeilStoryRun.replay(book: book, decisions: [forged]))
    }

    func testJSONRoundTrip() throws {
        let book = VeilStoryLibrary.observatory
        let data = try JSONEncoder().encode(book)
        let decoded = try JSONDecoder().decode(VeilStoryBook.self, from: data)
        try decoded.validate()
        XCTAssertEqual(book, decoded)
    }

    func testBrokenLinkRejected() throws {
        var book = VeilStoryLibrary.lighthouse
        book = VeilStoryBook(id: book.id, title: book.title, description: book.description,
                             startingScene: "unknown", scenes: book.scenes)
        XCTAssertThrowsError(try book.validate())
    }

    func testScoreCappedAndRequiredItems() throws {
        let book = VeilStoryLibrary.lighthouse
        var run = try VeilStoryRun(book: book)
        XCTAssertEqual(run.availableChoices(in: book).count, 2)
        try run.choose("workshop", in: book)
        XCTAssertTrue(run.items.contains("lamp"))
        try run.choose("climb", in: book)
        XCTAssertEqual(run.sceneID, "tower")
    }

    func testFiniteTurnGuard() throws {
        let book = VeilStoryLibrary.observatory
        var run = try VeilStoryRun(book: book)
        try run.choose("repair", in: book)
        for _ in 0..<63 {
            try run.choose("explore", in: book)
            try run.choose("backup", in: book)
        }
        try run.choose("explore", in: book)
        XCTAssertEqual(run.history.count, VeilStoryRun.maximumTurns)
        XCTAssertThrowsError(try run.choose("backup", in: book)) { error in
            XCTAssertEqual(error as? VeilStoryError, .turnLimitReached)
        }
    }
}
