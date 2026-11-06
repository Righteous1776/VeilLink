import XCTest
@testable import VeilopolyEngine

final class BidTests: XCTestCase {
 func testBid() {
   var g = Fixture.game(.tileResolve)
   g.turn.pendingPurchase = 1
   Fixture.step(&g, .startAuction, tile: 1)
   Fixture.step(&g, .bid, amount: 15)
   Fixture.step(&g, .bid, player: 1, amount: 0)
   Fixture.step(&g, .bid, player: 2, amount: 0)
   Fixture.step(&g, .bid, player: 3, amount: 0)
   XCTAssertEqual(g.board[1].owner, 0)
   XCTAssertEqual(g.players[0].cash, 1485)
   XCTAssertNil(g.auction)
 }
}
