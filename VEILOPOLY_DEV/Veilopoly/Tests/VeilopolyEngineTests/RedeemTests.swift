import XCTest
@testable import VeilopolyEngine

final class RedeemTests: XCTestCase {
 func testRedeem() {
   var g = Fixture.ownedSet()
   g.board[1].mortgaged = true
   Fixture.step(&g, .redeem, tile: 1)
   XCTAssertFalse(g.board[1].mortgaged)
   XCTAssertEqual(g.players[0].cash, 1467)
 }
}
