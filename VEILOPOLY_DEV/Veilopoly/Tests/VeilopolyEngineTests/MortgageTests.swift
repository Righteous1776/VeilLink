import XCTest
@testable import VeilopolyEngine

final class MortgageTests: XCTestCase {
 func testMortgage() {
   var g = Fixture.ownedSet()
   Fixture.step(&g, .mortgage, tile: 1)
   XCTAssertTrue(g.board[1].mortgaged)
   XCTAssertEqual(g.players[0].cash, 1530)
   Fixture.fails(g, Move(.mortgage, player: 0, seq: g.nextSeq, tile: 1), .alreadyMortgaged)
 }
}
