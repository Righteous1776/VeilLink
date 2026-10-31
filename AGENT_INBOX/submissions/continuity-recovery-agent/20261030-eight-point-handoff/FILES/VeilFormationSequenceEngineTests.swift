import XCTest
@testable import VeilLink

final class VeilFormationSequenceEngineTests: XCTestCase {
    typealias E = VeilFormationSequenceEngine
    func testGameIsolationAndIndependentClear() {
        var store = E()
        let seq = [E.Ply(actor: .human, action: "112"), E.Ply(actor: .ai, action: "113")]
        store.learn(.init(game: .gomoku, plies: seq, outcome: .aiWon))
        store.learn(.init(game: .xiangqi, plies: seq, outcome: .humanWon))
        XCTAssertEqual(store.count(game: .gomoku), 1)
        XCTAssertEqual(store.count(game: .xiangqi), 1)
        store.clear(game: .gomoku)
        XCTAssertEqual(store.count(game: .gomoku), 0)
        XCTAssertEqual(store.count(game: .xiangqi), 1)
    }
    func testPredictsConcreteNextMove() {
        var s = E()
        let prefix = [E.Ply(actor: .human, action: "112")]
        s.learn(.init(game: .gomoku, plies: prefix+[.init(actor: .ai, action: "113")], outcome: .aiWon))
        let suggestion = s.forecast(game: .gomoku, history: prefix) { $0 == "113" }
        XCTAssertEqual(suggestion?.action, "113")
        XCTAssertEqual(suggestion?.label, "阵法预判")
    }
    func testLosingSequenceChangesResponseWhenAlternativeExists() {
        var s = E()
        let prefix = [E.Ply(actor: .human, action: "112")]
        s.learn(.init(game: .gomoku, plies: prefix+[.init(actor: .ai, action: "113")], outcome: .aiWon))
        XCTAssertEqual(s.forecast(game: .gomoku, history: prefix) { _ in true }?.action, "113")
        s.learn(.init(game: .gomoku, plies: prefix+[.init(actor: .ai, action: "113")], outcome: .humanWon))
        s.learn(.init(game: .gomoku, plies: prefix+[.init(actor: .ai, action: "114")], outcome: .aiWon))
        XCTAssertEqual(s.forecast(game: .gomoku, history: prefix) { _ in true }?.action, "114")
    }
    func testInterruptedGamesLowerConfidence() {
        var s = E()
        let prefix = [E.Ply(actor: .human, action: "p")]
        s.learn(.init(game: .xiangqi, plies: prefix + [.init(actor: .ai, action: "1:20")], outcome: .aiWon))
        s.learn(.init(game: .xiangqi, plies: prefix + [.init(actor: .ai, action: "1:20")], outcome: .unfinished))
        XCTAssertEqual(s.forecast(game: .xiangqi, history: prefix) { _ in true }?.score, 4)
    }
    func testNeverChoosesIllegalMove() {
        var s = E()
        s.learn(.init(game: .xiangqi, plies: [.init(actor: .human, action: "a"),.init(actor: .ai, action: "99:99")], outcome: .aiWon))
        XCTAssertNil(s.forecast(game: .xiangqi, history: [.init(actor: .human, action: "a")]) { _ in false })
    }
}
