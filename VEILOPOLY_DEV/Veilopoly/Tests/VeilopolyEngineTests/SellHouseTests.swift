import XCTest
@testable import VeilopolyEngine

final class SellHouseTests: XCTestCase {
 func testSellHouse() {
   var g = Fixture.ownedSet()
   g.board[1].houses = 1; g.bank.houses = 31
   Fixture.step(&g, .sellHouse, tile: 1)
   XCTAssertEqual(g.board[1].houses, 0)
   XCTAssertEqual(g.bank.houses, 32)
   XCTAssertEqual(g.players[0].cash, 1525)
 }
}
