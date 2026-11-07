import XCTest
@testable import VeilopolyEngine

final class BuyPropertyTests: XCTestCase {
 func testBuyProperty() {
   var g = Fixture.game(.tileResolve)
   g.players[0].position = 1
   Fixture.step(&g, .resolveTile)
   Fixture.step(&g, .buyProperty, tile: 1)
   XCTAssertEqual(g.board[1].owner, 0)
   XCTAssertEqual(g.players[0].cash, 1440)
 }
}
