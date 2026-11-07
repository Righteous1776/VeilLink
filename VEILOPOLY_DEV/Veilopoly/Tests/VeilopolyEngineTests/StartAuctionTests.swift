import XCTest
@testable import VeilopolyEngine

final class StartAuctionTests: XCTestCase {
 func testStartAuction() {
   var g = Fixture.game(.tileResolve)
   g.turn.pendingPurchase = 1
   Fixture.step(&g, .startAuction, tile: 1)
   XCTAssertEqual(g.turn.phase, .auction)
   XCTAssertEqual(g.auction?.active.count, 4)
 }
}
